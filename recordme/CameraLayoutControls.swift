import SwiftUI

struct CameraLayoutControls: View {
    @Binding var settings: CameraOverlaySettings

    var body: some View {
        Form {
            Section("Camera layout") {
                Picker("Position", selection: $settings.position) {
                    ForEach(CameraOverlaySettings.Position.allCases) { Text($0.title).tag($0) }
                }
                Picker("Shape", selection: $settings.shape) {
                    ForEach(CameraOverlaySettings.Shape.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Size", value: settings.size, format: .percent.precision(.fractionLength(0)))
                Slider(value: $settings.size, in: 0.12...0.4)
                    .accessibilityLabel("Camera size")
                Text("Choose the layout before recording. It is saved into the video.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 280, height: 300)
    }
}
