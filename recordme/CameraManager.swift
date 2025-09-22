import AVFoundation
import SwiftUI
import CoreImage

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var cameraImage: CGImage?
    @Published var isAuthorized = false
    @Published var hasCamera = false
    @Published var isCapturing = false
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
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
        hasCamera = !AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        ).devices.isEmpty
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
            DispatchQueue.main.async {
                self?.isCapturing = false
                self?.cameraImage = nil
            }
        }
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium // 480p for overlay
        
        // Find camera device
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
                AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No camera device found")
            return
        }
        
        do {
            // Video input
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            guard session.canAddInput(videoInput) else {
                print("Cannot add video input")
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
                print("Cannot add video output")
                return
            }
            session.addOutput(videoOutput)
            
            // Configure video connection
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
                if connection.isVideoOrientationSupported {
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
            print("Error setting up camera: \(error)")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        DispatchQueue.main.async {
            self.cameraImage = cgImage
        }
    }
}