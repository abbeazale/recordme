import CoreMedia
import ScreenCaptureKit
import Testing
@testable import recordme

struct RecordingStreamConfigurationTests {
    @Test func previewConfigurationUsesLowerFrameRateAndNoAudio() {
        let config = RecordingStreamConfiguration.preview()

        #expect(config.width == 1_920)
        #expect(config.height == 1_080)
        #expect(config.minimumFrameInterval == CMTime(value: 1, timescale: 30))
        #expect(config.capturesAudio == false)
    }

    @Test func recordingConfigurationUsesSixtyFpsAndAudioFlags() {
        let config = RecordingStreamConfiguration.recording(captureSystemAudio: true, captureMicrophone: true)

        #expect(config.width == 1_920)
        #expect(config.height == 1_080)
        #expect(config.minimumFrameInterval == CMTime(value: 1, timescale: 60))
        #expect(config.capturesAudio == true)
        #expect(config.captureMicrophone == true)
    }

    @Test func recordingConfigurationDisablesAudioWhenBothSourcesAreOff() {
        let config = RecordingStreamConfiguration.recording(captureSystemAudio: false, captureMicrophone: false)

        #expect(config.capturesAudio == false)
        #expect(config.captureMicrophone == false)
    }
}
