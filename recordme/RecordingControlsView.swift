import SwiftUI

/// Bottom control bar: capture toggles on the left, recording status and the
/// prominent record/stop button on the right.
struct RecordingControlsView: View {
    let hasSelectedSource: Bool
    let isRecording: Bool
    let recordingStartDate: Date?
    let captureMicrophone: Bool
    let captureSystemAudio: Bool
    let cameraState: CameraControlState
    let toggleMicrophone: () -> Void
    let toggleSystemAudio: () -> Void
    let toggleCamera: () -> Void
    let toggleRecording: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            CaptureToggle(
                title: "Mic",
                systemImage: captureMicrophone ? "mic.fill" : "mic.slash",
                isOn: captureMicrophone,
                help: captureMicrophone ? "Microphone on" : "Microphone off",
                action: toggleMicrophone
            )

            CaptureToggle(
                title: "Audio",
                systemImage: captureSystemAudio ? "speaker.wave.2.fill" : "speaker.slash",
                isOn: captureSystemAudio,
                help: captureSystemAudio ? "System audio on" : "System audio off",
                action: toggleSystemAudio
            )

            CaptureToggle(
                title: cameraState.title,
                systemImage: cameraState.icon,
                isOn: cameraState.isActive,
                isEnabled: cameraState.isEnabled,
                help: cameraState.help,
                action: toggleCamera
            )

            Spacer(minLength: 16)

            if isRecording, let startDate = recordingStartDate {
                RecordingStatusView(startDate: startDate)
                    .transition(.opacity)
            }

            recordingButton
        }
        .animation(.easeInOut(duration: 0.2), value: isRecording)
        .padding(.horizontal, AppMetrics.barHPadding)
        .padding(.vertical, AppMetrics.barVPadding)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var recordingButton: some View {
        let state = RecordingButtonState.make(isRecording: isRecording, hasSelectedSource: hasSelectedSource)

        return Button(action: toggleRecording) {
            HStack(spacing: 7) {
                if state.isRecording {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(.white)
                        .frame(width: 10, height: 10)
                    Text("Stop")
                } else {
                    Image(systemName: "record.circle.fill")
                    Text("Record")
                }
            }
            .font(.callout.weight(.semibold))
            .frame(minWidth: 84)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .controlSize(.large)
        .disabled(!state.isEnabled)
        .keyboardShortcut("r", modifiers: .command)
        .help(state.isRecording ? "Stop recording (⌘R)" : "Start recording (⌘R)")
    }
}
