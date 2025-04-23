//
//  SourcePicker.swift
//  recordme
// 
//  Created by abbe on 2025-04-22.
//

import SwiftUI
import ScreenCaptureKit

struct SourcePickerView: View {
    /// Closure executed once the user chooses a display or window.
    var onSelect: (SCContentFilter) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displays: [SCDisplay] = []
    @State private var windows: [SCWindow]  = []

    var body: some View {
        NavigationView {
            List {
                if !displays.isEmpty {
                    Section("Displays") {
                        ForEach(displays, id: \.displayID) { display in
                            Button("Display \(display.displayID)") {
                                let filter = SCContentFilter(display: display,
                                                             excludingWindows: [])
                                onSelect(filter)
                                dismiss()
                            }
                        }
                    }
                }

                if !windows.isEmpty {
                    Section("Windows") {
                        ForEach(windows, id: \.windowID) { window in
                            Button(window.owningApplication?.applicationName ?? "Window \(window.windowID)") {
                                let filter = SCContentFilter(desktopIndependentWindow: window)
                                onSelect(filter)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Source")
            .task { await loadContent() }
        }
        .frame(minWidth: 400, minHeight: 350)
    }

    /// Fetches shareable content on a background thread, then publishes on the MainActor.
    @Sendable
    private func loadContent() async {
        await withCheckedContinuation { cont in
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
                if let content = content {
                    DispatchQueue.main.async {
                        self.displays = content.displays
                        self.windows  = content.windows
                    }
                } else if let error = error {
                    print("Failed to load shareable content: \(error)")
                }
                cont.resume()
            }
        }
    }
}

/*#Preview {
    SourcePickerView(displays[)
}*/
