import CoreMedia
import ScreenCaptureKit

enum RecordingStreamConfiguration {
    static func preview() -> SCStreamConfiguration {
        let config = base()
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.capturesAudio = false
        return config
    }

    static func recording(captureSystemAudio: Bool, captureMicrophone: Bool) -> SCStreamConfiguration {
        let config = base()
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.capturesAudio = captureSystemAudio
        config.captureMicrophone = captureMicrophone
        return config
    }

    static func fitSource(_ config: SCStreamConfiguration, filter: SCContentFilter) {
        let size = filter.contentRect.size
        guard size.width > 0, size.height > 0 else { return }
        let scale = min(1920 / max(size.width, size.height), CGFloat(filter.pointPixelScale))
        config.width = max(2, Int(size.width * scale / 2) * 2)
        config.height = max(2, Int(size.height * scale / 2) * 2)
        config.scalesToFit = true
        config.preservesAspectRatio = true
        config.ignoreShadowsSingleWindow = true
    }

    private static func base() -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = 1_920
        config.height = 1_080
        config.pixelFormat = kCVPixelFormatType_32BGRA
        return config
    }
}
