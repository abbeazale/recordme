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

@MainActor
final class RecordingManager: NSObject, ObservableObject {
    @Published var previewImage: CGImage?        // Live preview frame
    @Published var isRecording = false           // Recording state toggle
    @Published var recordingStartDate: Date?     // When the active recording began (drives the elapsed timer)
    @Published var captureMicrophone = false     // include mic audio
    @Published var captureSystemAudio = true     // include system audio
    @Published var isPreviewActive = false       // Tracks if preview stream is active
    @Published private(set) var isFinalizing = false
    @Published var runtimeErrorMessage: String?
    
    // ScreenCaptureKit invokes output callbacks off the main actor. These two
    // references are only read from that callback; pipeline mutation itself is
    // serialized on `processingQueue`, and the camera frame accessor is locked.
    nonisolated(unsafe) private weak var cameraManager: CameraManager?

    private var stream: SCStream?
    private var pendingPreviewStream: SCStream?
    private var previewGeneration = 0
    private var isStartingRecording = false
    private var pendingSaveURL: URL?             // Destination URL for recording
    private var contentFilter: SCContentFilter?
    private let processingQueue = DispatchQueue(label: "recording.processing.queue")
    nonisolated(unsafe) private let pipeline = RecordingPipeline()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "recordme", category: "Recording")
    
    /// Sets the camera manager reference for overlay functionality
    func setCameraManager(_ manager: CameraManager) {
        self.cameraManager = manager
    }

    func setCameraOverlaySettings(_ settings: CameraOverlaySettings) {
        processingQueue.sync { pipeline.cameraSettings = settings }
    }

    /// Starts a preview stream without recording
    /// - Parameter filter: Content filter specifying which windows/displays to capture.
    func startPreview(filter: SCContentFilter) async throws {
        guard !isRecording, !isStartingRecording, !isFinalizing else { return }

        previewGeneration += 1
        let generation = previewGeneration

        if let pendingPreviewStream {
            do {
                try await pendingPreviewStream.stopCapture()
                if self.pendingPreviewStream === pendingPreviewStream {
                    self.pendingPreviewStream = nil
                }
            } catch {
                logger.error("Failed to cancel pending preview: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }

        guard generation == previewGeneration else { return }

        guard generation == previewGeneration,
              !isRecording,
              !isStartingRecording,
              !isFinalizing,
              !isPreviewActive,
              stream == nil else { return }

        runtimeErrorMessage = nil

        // Save the filter for later use when recording starts
        contentFilter = filter

        let config = RecordingStreamConfiguration.preview()

        let previewStream = SCStream(filter: filter, configuration: config, delegate: self)
        pendingPreviewStream = previewStream

        do {
            // Register screen output only
            try previewStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: processingQueue)

            try await previewStream.startCapture()

            guard generation == previewGeneration,
                  !Task.isCancelled,
                  !isRecording,
                  !isStartingRecording,
                  !isFinalizing,
                  stream == nil,
                  pendingPreviewStream === previewStream else {
                try? await previewStream.stopCapture()
                if pendingPreviewStream === previewStream {
                    pendingPreviewStream = nil
                }
                return
            }

            pendingPreviewStream = nil
            stream = previewStream
            processingQueue.sync {
                pipeline.resetPreviewCounter()
                pipeline.setPreviewEnabled(true)
            }
            isPreviewActive = true
        } catch {
            try? await previewStream.stopCapture()
            if pendingPreviewStream === previewStream {
                pendingPreviewStream = nil
            }
            if generation == previewGeneration, stream == nil, !isRecording {
                processingQueue.sync {
                    pipeline.setPreviewEnabled(false)
                    pipeline.resetPreviewCounter()
                }
            }
            throw error
        }
    }

    /// Begins capture: configures and starts a ScreenCaptureKit stream.
    /// - Parameters:
    ///   - filter: Content filter specifying which windows/displays to capture.
    ///   - saveURL: File URL where the .mp4 will be written.
    func start(filter: SCContentFilter, saveURL: URL) async throws {
        guard !isRecording, !isStartingRecording, !isFinalizing else {
            throw RecordingError.streamBusy
        }

        isStartingRecording = true
        previewGeneration += 1
        await stopPreview()

        do {
            try Task.checkCancellation()
        } catch {
            isStartingRecording = false
            throw error
        }

        guard stream == nil, pendingPreviewStream == nil else {
            isStartingRecording = false
            throw RecordingError.streamBusy
        }

        pendingSaveURL = saveURL
        isRecording = true
        recordingStartDate = Date()
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

        let config = RecordingStreamConfiguration.recording(
            captureSystemAudio: captureSystemAudio,
            captureMicrophone: captureMicrophone
        )

        // Create and store the stream
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream

        do {
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
            isStartingRecording = false
        } catch {
            try? await stream.stopCapture()
            cleanup()
            try? await startPreview(filter: filter)
            throw error
        }
    }

    /// Stops preview stream without writing any files
    func stopPreview() async {
        previewGeneration += 1

        if let pendingPreviewStream {
            do {
                try await pendingPreviewStream.stopCapture()
                if self.pendingPreviewStream === pendingPreviewStream {
                    self.pendingPreviewStream = nil
                }
            } catch {
                logger.error("Failed to stop pending preview: \(error.localizedDescription, privacy: .public)")
                return
            }
        }

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

    /// Stops capture, finalizes the writer, and returns the playable output URL.
    /// - Parameter resumePreview: Whether to resume live capture preview after finalization.
    /// - Returns: The URL of a successfully finalized recording.
    @discardableResult
    func stop(resumePreview: Bool = true) async throws -> URL {
        guard !isFinalizing, let stream, let outputURL = pendingSaveURL else {
            throw RecordingError.notRecording
        }
        isFinalizing = true
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

        let finalizationError: Error?
        if let writer {
            do {
                switch writer.status {
                case .writing:
                    // Wait up to 5s for finishWriting().
                    guard try await finish(writer: writer, timeout: 5) else {
                        throw RecordingError.timeout
                    }
                case .completed:
                    break
                case .failed:
                    throw RecordingError.writerFailed(writer.error?.localizedDescription ?? "unknown")
                case .cancelled:
                    throw RecordingError.writerFailed("The recording was cancelled before it could be saved.")
                default:
                    throw RecordingError.writerFailed("The recording did not reach a writable state.")
                }

                guard Self.hasNonEmptyFile(at: outputURL) else {
                    throw RecordingError.missingOutput
                }
                logger.info("Saved recording -> \(outputURL.lastPathComponent)")
                finalizationError = nil
            } catch {
                finalizationError = error
            }
        } else {
            finalizationError = RecordingError.noVideoFrames
        }

        // Clean up before optionally creating a replacement preview stream.
        cleanup()
        isFinalizing = false

        if resumePreview, let filter = contentFilter {
            try? await startPreview(filter: filter)
        }

        if let finalizationError {
            try? FileManager.default.removeItem(at: outputURL)
            throw finalizationError
        }
        return outputURL
    }

    /// Resets all internal references and state.
    private func cleanup() {
        stream = nil
        pendingPreviewStream = nil
        pendingSaveURL = nil
        recordingStartDate = nil
        isRecording = false
        isPreviewActive = false
        isStartingRecording = false
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

    private static func hasNonEmptyFile(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              let values = try? url.resourceValues(forKeys: [.fileSizeKey]) else {
            return false
        }
        return (values.fileSize ?? 0) > 0
    }

    enum RecordingError: LocalizedError {
        case notRecording
        case writerFailed(String)
        case timeout
        case noVideoFrames
        case missingOutput
        case streamBusy

        var errorDescription: String? {
            switch self {
            case .notRecording: return "Recorder is not active."
            case .writerFailed(let msg): return "Writer failed: \(msg)"
            case .timeout: return "Timed out finishing the file."
            case .noVideoFrames: return "No video frames were captured. Try recording for a little longer."
            case .missingOutput: return "The recording finished, but its output file could not be found."
            case .streamBusy: return "The recorder is still finishing another capture operation."
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
                Task {
                    do {
                        _ = try await self.stop()
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
    var cameraSettings = CameraOverlaySettings()
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

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("Failed to create recording directory: \(error.localizedDescription, privacy: .public)")
            isRecording = false
            return "Could not create the recording output folder."
        }

        guard !FileManager.default.fileExists(atPath: url.path) else {
            isRecording = false
            return "A file already exists at the recording destination."
        }

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
        let screen = CIImage(cgImage: screenImage)
        let result = CameraOverlayRenderer.render(screen: screen, camera: CIImage(cgImage: cameraImage), settings: cameraSettings)
        return ciContext.createCGImage(result, from: screen.extent)
    }

    private func createCompositePixelBuffer(screenBuffer: CVPixelBuffer, cameraImage: CGImage) -> CVPixelBuffer? {
        var output: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                        CVPixelBufferGetWidth(screenBuffer), CVPixelBufferGetHeight(screenBuffer),
                                        kCVPixelFormatType_32BGRA, nil, &output)
        guard status == kCVReturnSuccess, let output else { return nil }
        let result = CameraOverlayRenderer.render(screen: CIImage(cvPixelBuffer: screenBuffer),
                                                  camera: CIImage(cgImage: cameraImage), settings: cameraSettings)
        ciContext.render(result, to: output)
        return output
    }
}
