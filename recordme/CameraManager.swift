import AVFoundation
import SwiftUI
import CoreImage
import OSLog

final class CameraManager: NSObject, ObservableObject, @unchecked Sendable {
    @Published var cameraImage: CGImage?
    @Published var isAuthorized = false
    @Published var hasCamera = false
    @Published var isCapturing = false
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let ciContext = CIContext()
    private let frameLock = NSLock()
    private var latestCameraImage: CGImage?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "recordme", category: "Camera")
    
    override init() {
        super.init()
        checkCameraAuthorization()
        checkCameraAvailability()
    }
    
    private func checkCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                }
            }
        default:
            isAuthorized = false
        }
    }
    
    private func checkCameraAvailability() {
        hasCamera = !availableVideoDevices().isEmpty
    }
    
    func startCapture() {
        guard isAuthorized && hasCamera && !isCapturing else { return }
        
        sessionQueue.async { [weak self] in
            self?.setupCaptureSession()
        }
    }
    
    func stopCapture() {
        guard isCapturing else { return }
        
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            self?.captureSession = nil
            self?.videoOutput = nil
            self?.setLatestCameraImage(nil)
            DispatchQueue.main.async {
                self?.isCapturing = false
                self?.cameraImage = nil
            }
        }
    }

    func currentCameraImage() -> CGImage? {
        frameLock.lock()
        defer { frameLock.unlock() }
        return latestCameraImage
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium // 480p for overlay
        
        // Find camera device
        guard let videoDevice = preferredVideoDevice() else {
            logger.error("No camera device found")
            return
        }
        
        do {
            // Video input
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            guard session.canAddInput(videoInput) else {
                logger.error("Cannot add video input")
                return
            }
            session.addInput(videoInput)
            
            // Video output
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            
            guard session.canAddOutput(videoOutput) else {
                logger.error("Cannot add video output")
                return
            }
            session.addOutput(videoOutput)
            
            // Configure video connection
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
                if #available(macOS 14.0, *) {
                    if connection.isVideoRotationAngleSupported(0) {
                        connection.videoRotationAngle = 0
                    }
                } else if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            self.captureSession = session
            self.videoOutput = videoOutput
            
            // Start session
            session.startRunning()
            
            DispatchQueue.main.async {
                self.isCapturing = true
            }
            
        } catch {
            logger.error("Error setting up camera: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func availableVideoDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices
    }

    private func preferredVideoDevice() -> AVCaptureDevice? {
        let devices = availableVideoDevices()

        return devices.first {
            $0.deviceType == .builtInWideAngleCamera && $0.position == .front
        } ?? devices.first {
            $0.deviceType == .builtInWideAngleCamera && $0.position == .back
        } ?? devices.first
    }

    private func setLatestCameraImage(_ image: CGImage?) {
        frameLock.lock()
        latestCameraImage = image
        frameLock.unlock()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        setLatestCameraImage(cgImage)
        
        DispatchQueue.main.async {
            self.cameraImage = cgImage
        }
    }
}
