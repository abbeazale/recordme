import SwiftUI

struct CursorEffectsControls: View {
    @Binding var settings: CursorEffectsSettings
    let eventCount: Int

    var body: some View {
        Form {
            Section("Cursor effects") {
                if eventCount == 0 {
                    Text("No clicks were recorded. Enable Capture Clicks before starting a recording to use these effects.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text(eventCount == 1 ? "1 recorded click" : "\(eventCount) recorded clicks").foregroundStyle(.secondary)
                    Toggle("Highlight clicks", isOn: $settings.highlightClicks)
                    Toggle("Automatic zoom", isOn: $settings.autoZoom)
                    if settings.autoZoom {
                        LabeledContent("Zoom", value: settings.zoomAmount, format: .number.precision(.fractionLength(1)))
                        Slider(value: $settings.zoomAmount, in: 1.2...2.5).accessibilityLabel("Zoom amount")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 290, height: 260)
    }
}
