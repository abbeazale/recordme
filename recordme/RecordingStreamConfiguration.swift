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
        config.capturesAudio = captureSystemAudio || captureMicrophone
        config.captureMicrophone = captureMicrophone
        return config
    }

    private static func base() -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = 1_920
        config.height = 1_080
        config.pixelFormat = kCVPixelFormatType_32BGRA
        return config
    }
}
