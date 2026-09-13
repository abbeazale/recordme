import SwiftUI

struct ExportSettingsControls: View {
    @Binding var settings: ExportSettings
    var body: some View {
        Form {
            Section("Export") {
                Picker("Resolution", selection: $settings.resolution) {
                    ForEach(ExportSettings.Resolution.allCases) { Text($0.title).tag($0) }
                }
                Picker("Frame rate", selection: $settings.frameRate) {
                    ForEach(ExportSettings.FrameRate.allCases) { Text("\($0.rawValue) fps").tag($0) }
                }
                Picker("Quality", selection: $settings.quality) {
                    ForEach(ExportSettings.Quality.allCases) { Text($0.title).tag($0) }
                }
                Text("MP4 · H.264\nSmaller videos keep their original size.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 280, height: 250)
    }
}
