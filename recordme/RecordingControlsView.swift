import SwiftUI

struct RecordingControlsView: View {
    let selectedSourceType: RecordingSourceType
    let hasSelectedSource: Bool
    let isRecording: Bool
    let captureMicrophone: Bool
    let captureSystemAudio: Bool
    let cameraState: CameraControlState
    let selectDisplay: () -> Void
    let selectWindow: () -> Void
    let toggleMicrophone: () -> Void
    let toggleSystemAudio: () -> Void
    let toggleCamera: () -> Void
    let toggleRecording: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            sourceToggleButton(
                isSelected: selectedSourceType == .display,
                icon: "display",
                title: "Display",
                action: selectDisplay
            )

            sourceToggleButton(
                isSelected: selectedSourceType == .window,
                icon: "macwindow",
                title: "Window",
                action: selectWindow
            )

            Spacer()

            audioToggleButton(
                isActive: captureMicrophone,
                icon: captureMicrophone ? "mic" : "mic.slash",
                title: captureMicrophone ? "Mic" : "No Mic",
                action: toggleMicrophone
            )

            audioToggleButton(
                isActive: captureSystemAudio,
                icon: captureSystemAudio ? "speaker.wave.2" : "speaker.slash",
                title: captureSystemAudio ? "System Audio" : "No Audio",
                isProminent: captureSystemAudio,
                action: toggleSystemAudio
            )

            cameraToggleButton(state: cameraState, action: toggleCamera)

            Spacer()

            recordingButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial)
    }

    private func sourceToggleButton(isSelected: Bool, icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(.callout, design: .rounded, weight: .medium))
            }
            .foregroundColor(isSelected ? .black : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.white : Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .help("Select \(title.lowercased())")
    }

    private func audioToggleButton(isActive: Bool, icon: String, title: String, isProminent: Bool = false, action: @escaping () -> Void) -> some View {
        let state = AudioControlState.make(isActive: isActive, isProminent: isProminent)

        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(.callout, design: .rounded, weight: .medium))
            }
            .foregroundColor(state.usesWhiteForeground ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(state.usesProminentBackground ? Color.blue : Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .help(title)
    }

    private func cameraToggleButton(state: CameraControlState, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: state.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(state.title)
                    .font(.system(.callout, design: .rounded, weight: .medium))
            }
            .foregroundColor(state.isActive ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(state.isActive ? Color.purple : Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!state.isEnabled)
        .help(state.help)
    }

    private var recordingButton: some View {
        let state = RecordingButtonState.make(isRecording: isRecording, hasSelectedSource: hasSelectedSource)

        return Button(action: toggleRecording) {
            HStack(spacing: 8) {
                if state.isRecording {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                    Text(state.title)
                } else {
                    if let icon = state.icon {
                        Image(systemName: icon)
                    }
                    Text(state.title)
                }
            }
            .font(.system(.callout, design: .rounded, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(state.isRecording ? Color.red : (state.isEnabled ? Color.red : Color.gray))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!state.isEnabled)
        .help(state.isRecording ? "Stop recording" : "Start recording")
    }
}
