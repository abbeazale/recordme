import Testing
@testable import recordme

struct RecordingControlStateTests {
    @Test func cameraStateWhenNoCameraExists() {
        let state = CameraControlState.make(hasCamera: false, isAuthorized: false, showCamera: false, isCapturing: false)

        #expect(state.icon == "video.slash")
        #expect(state.title == "No camera")
        #expect(state.help == "No camera available")
        #expect(state.isActive == false)
        #expect(state.isEnabled == false)
    }

    @Test func cameraStateWhenCameraIsCapturing() {
        let state = CameraControlState.make(hasCamera: true, isAuthorized: true, showCamera: true, isCapturing: true)

        #expect(state.icon == "video.fill")
        #expect(state.title == "Camera")
        #expect(state.help == "Hide camera overlay")
        #expect(state.isActive == true)
        #expect(state.isEnabled == true)
    }

    @Test func cameraStateWhenAuthorizationIsNeeded() {
        let state = CameraControlState.make(hasCamera: true, isAuthorized: false, showCamera: true, isCapturing: false)

        #expect(state.icon == "video.badge.exclamationmark")
        #expect(state.title == "Camera access")
        #expect(state.help == "Camera access required")
        #expect(state.isActive == false)
        #expect(state.isEnabled == true)
    }

    @Test func audioStateUsesProminentSystemAudioColor() {
        let state = AudioControlState.make(isActive: true, isProminent: true)

        #expect(state.usesWhiteForeground)
        #expect(state.usesProminentBackground)
    }

    @Test func recordingButtonStateRequiresSourceWhenIdle() {
        let idleWithoutSource = RecordingButtonState.make(isRecording: false, hasSelectedSource: false)
        let idleWithSource = RecordingButtonState.make(isRecording: false, hasSelectedSource: true)
        let recordingWithoutSource = RecordingButtonState.make(isRecording: true, hasSelectedSource: false)

        #expect(idleWithoutSource.isEnabled == false)
        #expect(idleWithoutSource.title == "Start Recording")
        #expect(idleWithSource.isEnabled == true)
        #expect(recordingWithoutSource.isEnabled == true)
        #expect(recordingWithoutSource.title == "Stop Recording")
    }
}
