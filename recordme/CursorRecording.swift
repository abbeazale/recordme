import Foundation
import CoreImage

struct CursorEvent: Codable, Equatable, Sendable {
    let time: Double
    let x: Double
    let y: Double
}

struct CursorRecording: Codable, Equatable, Sendable {
    var version = 1
    var events: [CursorEvent] = []

    static func sidecarURL(for video: URL) -> URL { video.appendingPathExtension("cursor.json") }

    static func load(for video: URL) throws -> CursorRecording {
        let url = sidecarURL(for: video)
        guard FileManager.default.fileExists(atPath: url.path) else { return CursorRecording() }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size < 5_000_000 else { throw VideoExportError.failed("Cursor data is too large.") }
        let result = try JSONDecoder().decode(CursorRecording.self, from: Data(contentsOf: url))
        try result.validate()
        return result
    }

    func validate() throws {
        guard version == 1, events.count <= 50_000,
              events.allSatisfy({ $0.time.isFinite && $0.time >= 0 && $0.x.isFinite && $0.y.isFinite &&
                                  (0...1).contains($0.x) && (0...1).contains($0.y) }),
              zip(events, events.dropFirst()).allSatisfy({ $0.time <= $1.time }) else {
            throw VideoExportError.failed("The recording contains invalid cursor data.")
        }
    }
}

struct CursorEffectsSettings: Codable, Equatable, Sendable {
    var highlightClicks = false
    var autoZoom = false
    var zoomAmount = 1.6
    var isEnabled: Bool { highlightClicks || autoZoom }
}

enum CursorEffectsRenderer {
    static func render(_ source: CIImage, at time: Double, events: [CursorEvent], settings: CursorEffectsSettings) -> CIImage {
        guard settings.isEnabled, !events.isEmpty else { return source }
        // Binary search keeps frame work bounded even for long recordings.
        var low = 0
        var high = events.count
        while low < high {
            let middle = (low + high) / 2
            if events[middle].time <= time { low = middle + 1 } else { high = middle }
        }
        guard low > 0 else { return source }
        let event = events[low - 1]
        let elapsed = time - event.time
        let bounds = source.extent
        let point = CGPoint(x: bounds.minX + event.x * bounds.width, y: bounds.maxY - event.y * bounds.height)
        var image = source
        if settings.highlightClicks && elapsed < 0.6 {
            let radius = min(bounds.width, bounds.height) * (0.016 + elapsed * 0.04)
            let outerRect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            let outer = CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
                "inputExtent": CIVector(cgRect: outerRect), "inputRadius": radius,
                "inputColor": CIColor(red: 1, green: 0.8, blue: 0.15, alpha: 1 - elapsed / 0.6)
            ])!.outputImage!
            let thickness = min(bounds.width, bounds.height) * 0.005
            let inner = CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
                "inputExtent": CIVector(cgRect: outerRect.insetBy(dx: thickness, dy: thickness)),
                "inputRadius": max(0, radius - thickness), "inputColor": CIColor.white
            ])!.outputImage!
            let ring = outer.applyingFilter("CISourceOutCompositing", parameters: [kCIInputBackgroundImageKey: inner])
            image = ring.composited(over: source).cropped(to: bounds)
        }
        if settings.autoZoom && elapsed < 1.6 {
            func ease(_ value: Double) -> Double {
                let clamped = min(1, max(0, value))
                return clamped * clamped * (3 - 2 * clamped)
            }
            let previous = low > 1 ? events[low - 2] : nil
            let previousAge = previous.map { event.time - $0.time } ?? 2
            let startingZoom = previousAge < 1.6
                ? 1 + (settings.zoomAmount - 1) * ease(min(previousAge / 0.25, (1.6 - previousAge) / 0.4)) : 1
            let rampIn = ease(elapsed / 0.25)
            let zoom = elapsed < 0.25
                ? startingZoom + (settings.zoomAmount - startingZoom) * rampIn
                : 1 + (settings.zoomAmount - 1) * ease((1.6 - elapsed) / 0.4)
            var focus = point
            if let previous, previousAge < 1.6 {
                let previousPoint = CGPoint(x: bounds.minX + previous.x * bounds.width, y: bounds.maxY - previous.y * bounds.height)
                focus = CGPoint(x: previousPoint.x + (point.x - previousPoint.x) * rampIn,
                                y: previousPoint.y + (point.y - previousPoint.y) * rampIn)
            }
            let cropSize = CGSize(width: bounds.width / zoom, height: bounds.height / zoom)
            let centerX = min(bounds.maxX - cropSize.width / 2, max(bounds.minX + cropSize.width / 2, focus.x))
            let centerY = min(bounds.maxY - cropSize.height / 2, max(bounds.minY + cropSize.height / 2, focus.y))
            let crop = CGRect(x: centerX - cropSize.width / 2, y: centerY - cropSize.height / 2,
                              width: cropSize.width, height: cropSize.height)
            image = image.cropped(to: crop)
                .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
                .transformed(by: CGAffineTransform(scaleX: zoom, y: zoom))
                .transformed(by: CGAffineTransform(translationX: bounds.minX, y: bounds.minY))
        }
        return image.cropped(to: bounds)
    }
}
