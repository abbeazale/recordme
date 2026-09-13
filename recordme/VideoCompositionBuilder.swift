import AVFoundation
import CoreImage

enum VideoCompositionBuilder {
    static func make(asset: AVAsset, style: CanvasStyle, exportSettings: ExportSettings? = nil, cursor: CursorRecording = CursorRecording(), effects: CursorEffectsSettings = CursorEffectsSettings()) async throws -> AVVideoComposition? {
        guard style.isEnabled || exportSettings != nil || effects.isEnabled else { return nil }
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoExportError.failed("The file has no video track.")
        }
        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let sourceRect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        guard sourceRect.width.isFinite, sourceRect.height.isFinite,
              sourceRect.width > 0, sourceRect.height > 0 else {
            throw VideoExportError.failed("The video has invalid dimensions.")
        }
        let canvas = style.canvasSize(for: sourceRect.size)
        let size = exportSettings?.renderSize(for: canvas) ?? canvas
        let duration = try await asset.load(.duration)
        let frameRate = try await track.load(.nominalFrameRate)
        let instruction = StyledVideoInstruction(
            trackID: track.trackID,
            timeRange: CMTimeRange(start: .zero, duration: duration),
            transform: transform,
            style: style, cursor: cursor, effects: effects
        )
        let composition = AVMutableVideoComposition()
        composition.customVideoCompositorClass = StyledVideoCompositor.self
        composition.renderSize = size
        composition.sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid
        let fps = exportSettings.map { Int32($0.frameRate.rawValue) } ?? Int32(frameRate.isFinite && frameRate > 0 ? min(60, frameRate.rounded()) : 30)
        composition.frameDuration = CMTime(value: 1, timescale: fps)
        composition.instructions = [instruction]
        return composition
    }
}

final class StyledVideoInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    let trackID: CMPersistentTrackID
    let timeRange: CMTimeRange
    let transform: CGAffineTransform
    let style: CanvasStyle
    let cursor: CursorRecording
    let effects: CursorEffectsSettings
    let enablePostProcessing = false
    let containsTweening = true
    var requiredSourceTrackIDs: [NSValue]? { [NSNumber(value: trackID)] }
    let passthroughTrackID = kCMPersistentTrackID_Invalid

    init(trackID: CMPersistentTrackID, timeRange: CMTimeRange, transform: CGAffineTransform, style: CanvasStyle, cursor: CursorRecording, effects: CursorEffectsSettings) {
        self.trackID = trackID
        self.timeRange = timeRange
        self.transform = transform
        self.style = style
        self.cursor = cursor
        self.effects = effects
    }
}

final class StyledVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private let queue = DispatchQueue(label: "recordme.compositor")
    private let context = CIContext()
    var sourcePixelBufferAttributes: [String: any Sendable]? {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        queue.async { [self] in
            autoreleasepool {
                guard let instruction = request.videoCompositionInstruction as? StyledVideoInstruction,
                      let source = request.sourceFrame(byTrackID: instruction.trackID),
                      let output = request.renderContext.newPixelBuffer() else {
                    request.finish(with: VideoExportError.failed("Could not render a video frame."))
                    return
                }
                let oriented = CIImage(cvPixelBuffer: source).transformed(by: instruction.transform)
                let edited = CursorEffectsRenderer.render(oriented, at: request.compositionTime.seconds,
                                                          events: instruction.cursor.events, settings: instruction.effects)
                let image = CanvasRenderer.render(edited, size: request.renderContext.size, style: instruction.style)
                context.render(image, to: output)
                request.finish(withComposedVideoFrame: output)
            }
        }
    }

    func cancelAllPendingVideoCompositionRequests() {
        // Drain submitted work before AVFoundation tears down the composition.
        queue.sync {}
    }
}

enum CanvasRenderer {
    static func render(_ source: CIImage, size: CGSize, style: CanvasStyle) -> CIImage {
        let bounds = CGRect(origin: .zero, size: size)
        let inset = style.isEnabled ? min(size.width, size.height) * style.padding : 0
        let available = bounds.insetBy(dx: inset, dy: inset)
        let scale = min(available.width / source.extent.width, available.height / source.extent.height)
        let videoSize = CGSize(width: source.extent.width * scale, height: source.extent.height * scale)
        let videoRect = CGRect(x: (size.width - videoSize.width) / 2, y: (size.height - videoSize.height) / 2,
                               width: videoSize.width, height: videoSize.height)
        var video = source.transformed(by: CGAffineTransform(translationX: -source.extent.minX, y: -source.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: videoRect.minX, y: videoRect.minY))
        let radius = style.isEnabled ? min(videoRect.width, videoRect.height) * style.cornerRadius : 0
        let mask = CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
            "inputExtent": CIVector(cgRect: videoRect), "inputRadius": radius,
            "inputColor": CIColor.white
        ])!.outputImage!.cropped(to: bounds)
        let transparent = CIImage(color: .clear).cropped(to: bounds)
        video = video.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: transparent, kCIInputMaskImageKey: mask
        ])
        var background = backgroundImage(style.background, bounds: bounds)
        if style.isEnabled && style.shadow {
            let shadow = mask.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.45)
            ]).applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: min(size.width, size.height) * 0.018])
                .transformed(by: CGAffineTransform(translationX: 0, y: -inset * 0.2))
            background = shadow.composited(over: background)
        }
        return video.composited(over: background).cropped(to: bounds)
    }

    private static func backgroundImage(_ background: CanvasStyle.Background, bounds: CGRect) -> CIImage {
        let colors: (CIColor, CIColor)
        switch background {
        case .none: colors = (.black, .black)
        case .midnight: colors = (CIColor(red: 0.08, green: 0.09, blue: 0.15), CIColor(red: 0.18, green: 0.20, blue: 0.32))
        case .ocean: colors = (CIColor(red: 0.06, green: 0.18, blue: 0.42), CIColor(red: 0.13, green: 0.66, blue: 0.72))
        case .sunset: colors = (CIColor(red: 0.45, green: 0.13, blue: 0.38), CIColor(red: 0.98, green: 0.59, blue: 0.32))
        case .paper: colors = (CIColor(red: 0.91, green: 0.90, blue: 0.87), CIColor(red: 0.98, green: 0.97, blue: 0.95))
        }
        return CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: bounds.width, y: bounds.height),
            "inputColor0": colors.0, "inputColor1": colors.1
        ])!.outputImage!.cropped(to: bounds)
    }
}
