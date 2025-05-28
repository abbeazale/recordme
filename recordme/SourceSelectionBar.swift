import SwiftUI
import ScreenCaptureKit

struct SourceSelectionBar: View {
    @Binding var selectedSourceType: RecordingSourceType
    @Binding var selectedFilter: SCContentFilter?
    @Binding var captureMicrophone: Bool
    @Binding var captureSystemAudio: Bool
    
    @State private var showSourcePicker = false
    
    var body: some View {
        HStack(spacing: 15) {
            // Close button (X)
            Button(action: {}) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color(.darkGray)))
            }
            
            Divider().frame(height: 30).background(Color.gray)
            
            // Display button
            sourceButton(
                type: .display,
                systemName: "display",
                title: "Display"
            )
            
            // Window button
            sourceButton(
                type: .window,
                systemName: "macwindow",
                title: "Window"
            )
            
            // Area button
            sourceButton(
                type: .area,
                systemName: "rectangle.dashed",
                title: "Area"
            )
            
            // Device button
            sourceButton(
                type: .device,
                systemName: "iphone",
                title: "Device"
            )
            
            Divider().frame(height: 30).background(Color.gray)
            
            // Audio options
            Button(action: { captureMicrophone.toggle() }) {
                HStack {
                    Image(systemName: captureMicrophone ? "mic" : "mic.slash")
                    Text(captureMicrophone ? "Microphone" : "No microphone")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(captureMicrophone ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                .cornerRadius(5)
            }
            
            Button(action: { captureSystemAudio.toggle() }) {
                HStack {
                    Image(systemName: captureSystemAudio ? "speaker.wave.2" : "speaker.slash")
                    Text(captureSystemAudio ? "System audio" : "No system audio")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(captureSystemAudio ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                .cornerRadius(5)
            }
            
            Spacer()
            
            // Settings button
            Button(action: {}) {
                Image(systemName: "gearshape")
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(Color(.darkGray).opacity(0.8))
        .cornerRadius(10)
        .sheet(isPresented: $showSourcePicker) {
            sourcePickerView()
        }
    }
    
    private func sourceButton(type: RecordingSourceType, systemName: String, title: String) -> some View {
        Button(action: {
            selectedSourceType = type
            showSourcePicker = true
        }) {
            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 12))
            }
            .frame(width: 60, height: 50)
            .background(selectedSourceType == type ? Color.blue.opacity(0.3) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func sourcePickerView() -> some View {
        switch selectedSourceType {
        case .display, .window:
            SourcePickerView { filter in
                selectedFilter = filter
                showSourcePicker = false
            }
        case .area:
            Text("Area selection coming soon")
                .padding()
        case .device:
            Text("Device selection coming soon")
                .padding()
        }
    }
} 
