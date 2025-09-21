//  RecordingManager.swift
//  recordme
//
//  Created by abbe on 2025-04-22.
//
import ScreenCaptureKit
import AVFoundation
import CoreImage
import SwiftUI
import OSLog

@MainActor
final class RecordingManager: NSObject, ObservableObject {
    @Published var previewImage: CGImage?        // Live preview frame
    @Published var isRecording = false           // Recording state toggle
    @Published var captureMicrophone = false     // Whether to include mic audio
    @Published var captureSystemAudio = true     // Whether to include system audio
    @Published var isPreviewActive = false       // Tracks if preview stream is active
    
    private weak var cameraManager: CameraManager? // Reference to camera manager

    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioSystemInput: AVAssetWriterInput?
    private var audioMicInput: AVAssetWriterInput?
    private var pendingSaveURL: URL?             // Destination URL for recording
    private var sessionStarted = false           // Indicates writer session has begun
    private var frameCounter = 0                 // Tracks number of frames written
    private var contentFilter: SCContentFilter?  // Store the content filter for reuse

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Recording")
    
    /// Sets the camera manager reference for overlay functionality
    func setCameraManager(_ manager: CameraManager) {
        self.cameraManager = manager
    }

    /// Starts a preview stream without recording
    /// - Parameter filter: Content filter specifying which windows/displays to capture.
    func startPreview(filter: SCContentFilter) async throws {
        // Don't start preview if already recording or preview active
        guard !isRecording && !isPreviewActive else { return }
        
        // Save the filter for later use when recording starts
        contentFilter = filter
        
        // Set up stream configuration for preview only
        let config = SCStreamConfiguration()
        config.width = 1920
        config.height = 1080
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30) // Lower framerate for preview
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = false // No audio needed for preview
        
        // Create and store the stream
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream
        
        // Register screen output only
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .init(label: "rec.preview"))
        
        // Start capturing
        try await stream.startCapture()
        isPreviewActive = true
    }

    /// Begins capture: configures and starts a ScreenCaptureKit stream.
    /// - Parameters:
    ///   - filter: Content filter specifying which windows/displays to capture.
    ///   - saveURL: File URL where the .mov will be written.
    func start(filter: SCContentFilter, saveURL: URL) async throws {
        // If preview is active, stop it first
        if isPreviewActive {
            await stopPreview()
        }
        
        // Prevent double-start
        guard stream == nil else { return }
        pendingSaveURL = saveURL
        sessionStarted = false
        isRecording = true
        
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
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .init(label: "rec.video"))
        
        if captureSystemAudio {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .init(label: "rec.audio"))
        }
        
        if #available(macOS 15, *), captureMicrophone {
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: .init(label: "rec.mic"))
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

        // Finalize writer if it exists
        if let writer {
            switch writer.status {
            case .writing:
                // Wait up to 5s for finishWriting()
                let finished = try await finish(writer: writer, timeout: 5)
                if finished {
                    logger.info("Saved recording → \(self.pendingSaveURL?.lastPathComponent ?? "")")
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
        writer = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        audioSystemInput = nil
        audioMicInput = nil
        pendingSaveURL = nil
        sessionStarted = false
        frameCounter = 0
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

        // Update live preview every 4th frame
        if type == .screen,
           sbuf.shouldPublishPreview(emitEveryNth: 4),
           let cg = sbuf.makePreviewImage() {
            Task { @MainActor in 
                // Create composite image with camera overlay if needed
                if let cameraImg = self.cameraManager?.cameraImage,
                   self.cameraManager?.isCapturing == true {
                    self.previewImage = self.createCompositeImage(screenImage: cg, cameraImage: cameraImg) ?? cg
                } else {
                    self.previewImage = cg
                }
            }
        }

        Task { @MainActor in
            // Only handle recording-related tasks if recording
            guard isRecording else { return }
            
            if type == .screen && writer == nil { makeWriterForFirstFrame(sbuf) }
            guard sessionStarted else { return }

            switch type {
            case .screen:
                appendVideoBuffer(sbuf)
            case .audio:
                appendSample(sbuf, to: audioSystemInput)
            case .microphone:
                appendSample(sbuf, to: audioMicInput)
            default:
                break
            }
        }
    }

    /// Sets up AVAssetWriter and its inputs using the first-frame dimensions.
    private func makeWriterForFirstFrame(_ sbuf: CMSampleBuffer) {
        guard let url = pendingSaveURL,
              let buf = CMSampleBufferGetImageBuffer(sbuf)
        else { return }

        let width = CVPixelBufferGetWidth(buf)
        let height = CVPixelBufferGetHeight(buf)

        // Prepare output file
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: url)

        // Create writer
        let writer = try! AVAssetWriter(outputURL: url, fileType: .mov)

        // Video input + pixel-buffer adaptor
        let vSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: vSettings)
        vInput.expectsMediaDataInRealTime = true
        writer.add(vInput)
        videoInput = vInput

        let pixelAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vInput,
                                                                  sourcePixelBufferAttributes: pixelAttrs)

        // Audio inputs: system and mic (AAC settings)
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 48_000,
            AVEncoderBitRateKey: 128_000
        ]
        let systemAudio = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        systemAudio.expectsMediaDataInRealTime = true
        writer.add(systemAudio)
        audioSystemInput = systemAudio

        let micAudio = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        micAudio.expectsMediaDataInRealTime = true
        writer.add(micAudio)
        audioMicInput = micAudio

        // Start writing session
        self.writer = writer
        writer.startWriting()
        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sbuf))
        sessionStarted = true
    }

    /// Extracts pixel buffer from a screen sample and appends via the adaptor.
    private func appendVideoBuffer(_ sbuf: CMSampleBuffer) {
        guard let adaptor = pixelBufferAdaptor,
              let input = videoInput,
              input.isReadyForMoreMediaData,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sbuf)
        else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sbuf)
        
        // Create composite pixel buffer with camera overlay if needed
        let finalPixelBuffer: CVPixelBuffer
        if let cameraImg = cameraManager?.cameraImage,
           cameraManager?.isCapturing == true {
            finalPixelBuffer = createCompositePixelBuffer(screenBuffer: pixelBuffer, cameraImage: cameraImg) ?? pixelBuffer
        } else {
            finalPixelBuffer = pixelBuffer
        }
        
        if adaptor.append(finalPixelBuffer, withPresentationTime: pts) {
            frameCounter += 1
        } else {
            logger.error("Video append failed: \(self.writer?.error?.localizedDescription ?? "unknown")")
        }
    }

    /// Appends an audio sample buffer to the given writer input.
    private func appendSample(_ sbuf: CMSampleBuffer, to input: AVAssetWriterInput?) {
        guard let input = input, input.isReadyForMoreMediaData else { return }
        if !input.append(sbuf) {
            logger.error("Audio append failed: \(self.writer?.error?.localizedDescription ?? "")")
        }
    }
    
    /// Creates a composite CGImage with camera overlay
    private func createCompositeImage(screenImage: CGImage, cameraImage: CGImage) -> CGImage? {
        let screenWidth = screenImage.width
        let screenHeight = screenImage.height
        
        // Camera overlay dimensions (bottom-right corner)
        let cameraWidth = min(screenWidth / 4, 320)  // Max 320px wide
        let cameraHeight = Int(Double(cameraWidth) * 3.0 / 4.0)  // 4:3 aspect ratio
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: screenWidth,
            height: screenHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // Draw screen image
        context.draw(screenImage, in: CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight))
        
        // Draw camera overlay in bottom-right corner with padding
        let padding = 16
        let cameraRect = CGRect(
            x: screenWidth - cameraWidth - padding,
            y: screenHeight - cameraHeight - padding,
            width: cameraWidth,
            height: cameraHeight
        )
        
        // Add white border
        context.setFillColor(CGColor.white)
        context.fill(cameraRect.insetBy(dx: -2, dy: -2))
        
        // Draw camera feed
        context.draw(cameraImage, in: cameraRect)
        
        return context.makeImage()
    }
    
    /// Creates a composite CVPixelBuffer with camera overlay for recording
    private func createCompositePixelBuffer(screenBuffer: CVPixelBuffer, cameraImage: CGImage) -> CVPixelBuffer? {
        let screenWidth = CVPixelBufferGetWidth(screenBuffer)
        let screenHeight = CVPixelBufferGetHeight(screenBuffer)
        
        // Create output pixel buffer
        var outputBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            screenWidth,
            screenHeight,
            kCVPixelFormatType_32BGRA,
            nil,
            &outputBuffer
        )
        
        guard status == kCVReturnSuccess, let output = outputBuffer else { return nil }
        
        // Lock buffers
        CVPixelBufferLockBaseAddress(screenBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(output, [])
        
        defer {
            CVPixelBufferUnlockBaseAddress(screenBuffer, .readOnly)
            CVPixelBufferUnlockBaseAddress(output, [])
        }
        
        // Create contexts
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let outputContext = CGContext(
            data: CVPixelBufferGetBaseAddress(output),
            width: screenWidth,
            height: screenHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(output),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // Create screen CIImage and draw it
        let screenCIImage = CIImage(cvPixelBuffer: screenBuffer)
        let context = CIContext()
        if let screenCGImage = context.createCGImage(screenCIImage, from: screenCIImage.extent) {
            outputContext.draw(screenCGImage, in: CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight))
        }
        
        // Draw camera overlay
        let cameraWidth = min(screenWidth / 4, 320)
        let cameraHeight = Int(Double(cameraWidth) * 3.0 / 4.0)
        let padding = 16
        
        let cameraRect = CGRect(
            x: screenWidth - cameraWidth - padding,
            y: screenHeight - cameraHeight - padding,
            width: cameraWidth,
            height: cameraHeight
        )
        
        // White border
        outputContext.setFillColor(CGColor.white)
        outputContext.fill(cameraRect.insetBy(dx: -2, dy: -2))
        
        // Camera feed
        outputContext.draw(cameraImage, in: cameraRect)
        
        return output
    }
}

private extension CMSampleBuffer {
    /// Creates a preview CGImage from a pixel buffer sample.
    func makePreviewImage() -> CGImage? {
            guard let buffer = CMSampleBufferGetImageBuffer(self) else { return nil }
            let width = CVPixelBufferGetWidth(buffer)
            let height = CVPixelBufferGetHeight(buffer)
            let ciImage = CIImage(cvPixelBuffer: buffer)
            return CIContext().createCGImage(
                ciImage,
                from: CGRect(x: 0, y: 0, width: width, height: height)
            )
        }

    /// Decides whether to publish a preview based on frame count.
    private static var counter: UInt = 0
    func shouldPublishPreview(emitEveryNth n: UInt) -> Bool {
        Self.counter &+= 1
        return Self.counter % n == 0
    }
}
