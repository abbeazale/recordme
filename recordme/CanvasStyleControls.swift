import SwiftUI

struct CanvasStyleControls: View {
    @Binding var style: CanvasStyle

    var body: some View {
        Form {
            Section("Canvas") {
                Picker("Background", selection: $style.background) {
                    ForEach(CanvasStyle.Background.allCases) { Text($0.title).tag($0) }
                }
                Picker("Aspect ratio", selection: $style.aspect) {
                    ForEach(CanvasStyle.Aspect.allCases) { Text($0.title).tag($0) }
                }
                if style.isEnabled {
                    LabeledContent("Padding", value: style.padding, format: .percent.precision(.fractionLength(0)))
                    Slider(value: $style.padding, in: 0...0.2).accessibilityLabel("Canvas padding")
                    LabeledContent("Corners", value: style.cornerRadius, format: .percent.precision(.fractionLength(0)))
                    Slider(value: $style.cornerRadius, in: 0...0.15).accessibilityLabel("Corner radius")
                    Toggle("Shadow", isOn: $style.shadow)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 230)
    }
}
