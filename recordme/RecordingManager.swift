//  RecordingManager.swift
//  recordme
//
//  Created by abbe on 2025-04-22.
//
import ScreenCaptureKit
import AVFoundation
@preconcurrency import CoreMedia
import CoreImage
import SwiftUI
import OSLog

final class RecordingManager: NSObject, ObservableObject, @unchecked Sendable {
    @Published var previewImage: CGImage?        // Live preview frame
    @Published var isRecording = false           // Recording state toggle
    @Published var captureMicrophone = false     // include mic audio
    @Published var captureSystemAudio = true     // include system audio
    @Published var isPreviewActive = false       // Tracks if preview stream is active
    @Published var runtimeErrorMessage: String?
    
    private weak var cameraManager: CameraManager?

    private var stream: SCStream?
    private var pendingSaveURL: URL?             // Destination URL for recording
    private var contentFilter: SCContentFilter?
    private let processingQueue = DispatchQueue(label: "recording.processing.queue")
    private let pipeline = RecordingPipeline()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "recordme", category: "Recording")
    
    /// Sets the camera manager reference for overlay functionality
    func setCameraManager(_ manager: CameraManager) {
        self.cameraManager = manager
    }

    /// Starts a preview stream without recording
    /// - Parameter filter: Content filter specifying which windows/displays to capture.
    func startPreview(filter: SCContentFilter) async throws {
        // Don't start preview if already recording or preview active
        guard !isRecording && !isPreviewActive else { return }
        runtimeErrorMessage = nil
        processingQueue.sync {
            pipeline.resetPreviewCounter()
            pipeline.setPreviewEnabled(true)
        }
        
        // Save the filter for later use when recording starts
        contentFilter = filter
        
        // Set up stream configuration for preview only
        let config = SCStreamConfiguration()
        config.width = 1920
        config.height = 1080
        // Lower framerate for preview
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = false // No audio needed for preview
        
        // Create and store the stream
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream
        
        do {
            // Register screen output only
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: processingQueue)

            try await stream.startCapture()
            isPreviewActive = true
        } catch {
            processingQueue.sync {
                pipeline.setPreviewEnabled(false)
                pipeline.resetPreviewCounter()
            }
            self.stream = nil
            throw error
        }
    }

    /// Begins capture: configures and starts a ScreenCaptureKit stream.
    /// - Parameters:
    ///   - filter: Content filter specifying which windows/displays to capture.
    ///   - saveURL: File URL where the .mp4 will be written.
    func start(filter: SCContentFilter, saveURL: URL) async throws {
        // If preview is active, stop it first
        if isPreviewActive {
            await stopPreview()
        }
        
        // Prevent double-start
        guard stream == nil else { return }
        pendingSaveURL = saveURL
        isRecording = true
        runtimeErrorMessage = nil
        processingQueue.sync {
            pipeline.startRecording(
                saveURL: saveURL,
                captureSystemAudio: captureSystemAudio,
                captureMicrophone: captureMicrophone
            )
        }
        
        // Save the filter
        contentFilter = filter

        // Set up stream configuration
        let config = SCStreamConfiguration()
        config.width = 1920
        config.height = 1080
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = captureSystemAudio || captureMicrophone
        // System audio is automatically captured when capturesAudio is true
        config.captureMicrophone = captureMicrophone

        // Create and store the stream
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream

        // Register outputs for screen, system audio, and microphone
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: processingQueue)
        
        if captureSystemAudio {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: processingQueue)
        }
        
        if #available(macOS 15, *), captureMicrophone {
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: processingQueue)
        }

        // Start capturing
        try await stream.startCapture()
    }

    /// Stops preview stream without writing any files
    func stopPreview() async {
        guard isPreviewActive, let stream = self.stream, !isRecording else { return }
        
        // Stop the SCStream
        do {
            try await stream.stopCapture()
            isPreviewActive = false
            self.stream = nil
            previewImage = nil
            processingQueue.sync {
                pipeline.setPreviewEnabled(false)
                pipeline.resetPreviewCounter()
            }
        } catch {
            logger.error("Failed to stop preview: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Stops capture: ends the stream, finalizes the writer, and handles errors.
    func stop() async throws {
        guard let stream else { throw RecordingError.notRecording }
        isRecording = false

        // Stop the SCStream
        do {
            try await stream.stopCapture()
            isPreviewActive = false
        } catch {
            logger.error("Failed to stop capture: \(error.localizedDescription, privacy: .public)")
        }

        let writer = processingQueue.sync {
            pipeline.stopRecording()
        }

        // Finalize writer if it exists
        if let writer {
            switch writer.status {
            case .writing:
                // Wait up to 5s for finishWriting()
                let finished = try await finish(writer: writer, timeout: 5)
                if finished {
                    logger.info("Saved recording -> \(self.pendingSaveURL?.lastPathComponent ?? "")")
                } else {
                    throw RecordingError.timeout
                }
            case .failed:
                if let error = writer.error {
                    logger.error("Writer failed: \(error.localizedDescription, privacy: .public)")
                }
            default:
                break
            }
        }

        // Clean up internal state
        cleanup()
        
        // Restart preview if we have a content filter
        if let filter = contentFilter {
            try? await startPreview(filter: filter)
        }
    }

    /// Resets all internal references and state.
    private func cleanup() {
        stream = nil
        pendingSaveURL = nil
        processingQueue.sync {
            pipeline.reset()
        }
    }

    /// Finalizes the AVAssetWriter, waiting up to `timeout` seconds.
    /// - Parameters:
    ///   - writer: The AVAssetWriter instance to finish.
    ///   - timeout: Maximum time to wait in seconds.
    /// - Returns: True if completed successfully; false if timed out.
    private func finish(writer: AVAssetWriter, timeout: TimeInterval) async throws -> Bool {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Task A: finishWriting
            group.addTask { @MainActor in
                await writer.finishWriting()
            }
            // Task B: timeout
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw RecordingError.timeout
            }
            // Return when either completes
            try await group.next()
            group.cancelAll()
        }
        if writer.status == .failed {
            throw RecordingError.writerFailed(writer.error?.localizedDescription ?? "unknown")
        }
        return writer.status == .completed
    }

    enum RecordingError: LocalizedError {
        case notRecording
        case writerFailed(String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .notRecording: return "Recorder is not active."
            case .writerFailed(let msg): return "Writer failed: \(msg)"
            case .timeout: return "Timed out finishing the file."
            }
        }
    }
}

extension RecordingManager: SCStreamDelegate, SCStreamOutput {
    nonisolated func stream(_ stream: SCStream,
                            didOutputSampleBuffer sbuf: CMSampleBuffer,
                            of type: SCStreamOutputType) {
        // Ignore buffers that aren't ready
        guard CMSampleBufferDataIsReady(sbuf) else { return }
        let result = pipeline.processSampleBuffer(
            sbuf,
            type: type
        ) { cameraManager?.currentCameraImage() }

        if let previewImage = result.previewImage {
            DispatchQueue.main.async {
                self.previewImage = previewImage
            }
        }

        if let runtimeErrorMessage = result.runtimeErrorMessage {
            DispatchQueue.main.async {
                self.runtimeErrorMessage = runtimeErrorMessage
                self.isRecording = false
                Task {
                    do {
                        try await self.stop()
                    } catch {
                        self.cleanup()
                    }
                }
            }
        }
    }
}

private extension CMSampleBuffer {
    /// Creates a preview CGImage from a pixel buffer sample.
    func makePreviewImage(using context: CIContext) -> CGImage? {
            guard let buffer = CMSampleBufferGetImageBuffer(self) else { return nil }
            let width = CVPixelBufferGetWidth(buffer)
            let height = CVPixelBufferGetHeight(buffer)
            let ciImage = CIImage(cvPixelBuffer: buffer)
            return context.createCGImage(
                ciImage,
                from: CGRect(x: 0, y: 0, width: width, height: height)
            )
        }
}

private final class RecordingPipeline {
    struct ProcessingResult {
        let previewImage: CGImage?
        let runtimeErrorMessage: String?
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "recordme", category: "Recording")
    private let ciContext = CIContext()

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioSystemInput: AVAssetWriterInput?
    private var audioMicInput: AVAssetWriterInput?
    private var pendingSaveURL: URL?
    private var isRecording = false
    private var isPreviewEnabled = false
    private var sessionStarted = false
    private var frameCounter = 0
    private var previewThrottler = PreviewFrameThrottler(interval: 4)
    private var captureSystemAudio = true
    private var captureMicrophone = false

    func startRecording(saveURL: URL, captureSystemAudio: Bool, captureMicrophone: Bool) {
        pendingSaveURL = saveURL
        isRecording = true
        sessionStarted = false
        frameCounter = 0
        self.captureSystemAudio = captureSystemAudio
        self.captureMicrophone = captureMicrophone
    }

    func stopRecording() -> AVAssetWriter? {
        isRecording = false
        videoInput?.markAsFinished()
        audioSystemInput?.markAsFinished()
        audioMicInput?.markAsFinished()
        return writer
    }

    func resetPreviewCounter() {
        previewThrottler.reset()
    }

    func setPreviewEnabled(_ isPreviewEnabled: Bool) {
        self.isPreviewEnabled = isPreviewEnabled
    }

    func needsCameraImage(for type: SCStreamOutputType) -> Bool {
        type == .screen && (isRecording || isPreviewEnabled)
    }

    func reset() {
        writer = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        audioSystemInput = nil
        audioMicInput = nil
        pendingSaveURL = nil
        isRecording = false
        isPreviewEnabled = false
        sessionStarted = false
        frameCounter = 0
        previewThrottler.reset()
    }

    func processSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        type: SCStreamOutputType,
        cameraImageProvider: () -> CGImage?
    ) -> ProcessingResult {
        var previewImage: CGImage?
        let cameraImage = needsCameraImage(for: type) ? cameraImageProvider() : nil

        if type == .screen,
           previewThrottler.shouldEmitFrame(isPreviewEnabled: isRecording || isPreviewEnabled),
           let cgImage = sampleBuffer.makePreviewImage(using: ciContext) {
            if let cameraImage {
                previewImage = createCompositeImage(screenImage: cgImage, cameraImage: cameraImage) ?? cgImage
            } else {
                previewImage = cgImage
            }
        }

        guard isRecording else {
            return ProcessingResult(previewImage: previewImage, runtimeErrorMessage: nil)
        }

        if type == .screen && writer == nil {
            if let runtimeErrorMessage = makeWriterForFirstFrame(sampleBuffer) {
                return ProcessingResult(previewImage: previewImage, runtimeErrorMessage: runtimeErrorMessage)
            }
        }

        guard sessionStarted else {
            return ProcessingResult(previewImage: previewImage, runtimeErrorMessage: nil)
        }

        switch type {
        case .screen:
            appendVideoBuffer(sampleBuffer, cameraImage: cameraImage)
        case .audio:
            appendSample(sampleBuffer, to: audioSystemInput)
        case .microphone:
            appendSample(sampleBuffer, to: audioMicInput)
        default:
            break
        }

        return ProcessingResult(previewImage: previewImage, runtimeErrorMessage: nil)
    }

    private func makeWriterForFirstFrame(_ sampleBuffer: CMSampleBuffer) -> String? {
        guard let url = pendingSaveURL,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: url)

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            logger.error("Failed to create AVAssetWriter: \(error.localizedDescription, privacy: .public)")
            isRecording = false
            return "Could not start recording output file."
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        writer.add(videoInput)
        self.videoInput = videoInput

        let pixelAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelAttributes
        )

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 48_000,
            AVEncoderBitRateKey: 128_000
        ]

        if captureSystemAudio {
            let systemAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            systemAudioInput.expectsMediaDataInRealTime = true
            writer.add(systemAudioInput)
            audioSystemInput = systemAudioInput
        }

        if #available(macOS 15, *), captureMicrophone {
            let microphoneInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            microphoneInput.expectsMediaDataInRealTime = true
            writer.add(microphoneInput)
            audioMicInput = microphoneInput
        }

        self.writer = writer
        writer.startWriting()
        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        sessionStarted = true
        return nil
    }

    private func appendVideoBuffer(_ sampleBuffer: CMSampleBuffer, cameraImage: CGImage?) {
        guard let pixelBufferAdaptor,
              let videoInput,
              videoInput.isReadyForMoreMediaData,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        let finalPixelBuffer: CVPixelBuffer
        if let cameraImage {
            finalPixelBuffer = createCompositePixelBuffer(screenBuffer: pixelBuffer, cameraImage: cameraImage) ?? pixelBuffer
        } else {
            finalPixelBuffer = pixelBuffer
        }

        if pixelBufferAdaptor.append(finalPixelBuffer, withPresentationTime: presentationTime) {
            frameCounter += 1
        } else {
            logger.error("Video append failed: \(self.writer?.error?.localizedDescription ?? "unknown", privacy: .public)")
        }
    }

    private func appendSample(_ sampleBuffer: CMSampleBuffer, to input: AVAssetWriterInput?) {
        guard let input, input.isReadyForMoreMediaData else { return }

        if !input.append(sampleBuffer) {
            logger.error("Audio append failed: \(self.writer?.error?.localizedDescription ?? "", privacy: .public)")
        }
    }

    private func createCompositeImage(screenImage: CGImage, cameraImage: CGImage) -> CGImage? {
        let screenWidth = screenImage.width
        let screenHeight = screenImage.height
        let cameraWidth = min(screenWidth / 4, 320)
        let cameraHeight = Int(Double(cameraWidth) * 3.0 / 4.0)
        let padding = 16

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: screenWidth,
            height: screenHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(screenImage, in: CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight))

        let cameraRect = CGRect(
            x: screenWidth - cameraWidth - padding,
            y: screenHeight - cameraHeight - padding,
            width: cameraWidth,
            height: cameraHeight
        )

        context.setFillColor(CGColor.white)
        context.fill(cameraRect.insetBy(dx: -2, dy: -2))
        context.draw(cameraImage, in: cameraRect)

        return context.makeImage()
    }

    private func createCompositePixelBuffer(screenBuffer: CVPixelBuffer, cameraImage: CGImage) -> CVPixelBuffer? {
        let screenWidth = CVPixelBufferGetWidth(screenBuffer)
        let screenHeight = CVPixelBufferGetHeight(screenBuffer)

        var outputBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            screenWidth,
            screenHeight,
            kCVPixelFormatType_32BGRA,
            nil,
            &outputBuffer
        )

        guard status == kCVReturnSuccess, let output = outputBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(screenBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(output, [])

        defer {
            CVPixelBufferUnlockBaseAddress(screenBuffer, .readOnly)
            CVPixelBufferUnlockBaseAddress(output, [])
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let outputContext = CGContext(
            data: CVPixelBufferGetBaseAddress(output),
            width: screenWidth,
            height: screenHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(output),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let screenImage = CIImage(cvPixelBuffer: screenBuffer)
        if let screenCGImage = ciContext.createCGImage(screenImage, from: screenImage.extent) {
            outputContext.draw(screenCGImage, in: CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight))
        }

        let cameraWidth = min(screenWidth / 4, 320)
        let cameraHeight = Int(Double(cameraWidth) * 3.0 / 4.0)
        let padding = 16
        let cameraRect = CGRect(
            x: screenWidth - cameraWidth - padding,
            y: screenHeight - cameraHeight - padding,
            width: cameraWidth,
            height: cameraHeight
        )

        outputContext.setFillColor(CGColor.white)
        outputContext.fill(cameraRect.insetBy(dx: -2, dy: -2))
        outputContext.draw(cameraImage, in: cameraRect)

        return output
    }
}
