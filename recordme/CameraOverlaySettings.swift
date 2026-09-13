import CoreImage
import Foundation

struct CameraOverlaySettings: Codable, Equatable, Sendable {
    enum Position: String, Codable, CaseIterable, Identifiable {
        case topLeft, topRight, bottomLeft, bottomRight
        var id: Self { self }
        var title: String {
            switch self {
            case .topLeft: return "Top left"
            case .topRight: return "Top right"
            case .bottomLeft: return "Bottom left"
            case .bottomRight: return "Bottom right"
            }
        }
    }
    enum Shape: String, Codable, CaseIterable, Identifiable {
        case rounded, circle, rectangle
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }
    var position: Position = .bottomRight
    var shape: Shape = .rounded
    var size = 0.2

    func frame(in canvas: CGRect) -> CGRect {
        let width = min(canvas.width * size, canvas.height * 0.7)
        let height = shape == .circle ? width : width * 0.75
        let margin = min(canvas.width, canvas.height) * 0.025
        let x: CGFloat
        let y: CGFloat
        switch position {
        case .topLeft, .bottomLeft: x = canvas.minX + margin
        case .topRight, .bottomRight: x = canvas.maxX - margin - width
        }
        switch position {
        case .bottomLeft, .bottomRight: y = canvas.minY + margin
        case .topLeft, .topRight: y = canvas.maxY - margin - height
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

enum CameraOverlayRenderer {
    static func render(screen: CIImage, camera: CIImage, settings: CameraOverlaySettings) -> CIImage {
        let frame = settings.frame(in: screen.extent)
        let scale = max(frame.width / camera.extent.width, frame.height / camera.extent.height)
        let scaled = camera.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let positioned = scaled.transformed(by: CGAffineTransform(
            translationX: frame.midX - scaled.extent.midX, y: frame.midY - scaled.extent.midY))
        let radius: CGFloat
        switch settings.shape {
        case .circle: radius = frame.width / 2
        case .rounded: radius = frame.width * 0.08
        case .rectangle: radius = 0
        }
        let mask = CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
            "inputExtent": CIVector(cgRect: frame), "inputRadius": radius, "inputColor": CIColor.white
        ])!.outputImage!
        return positioned.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: screen, kCIInputMaskImageKey: mask
        ]).cropped(to: screen.extent)
    }
}
