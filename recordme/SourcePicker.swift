//
//  SourcePicker.swift
//  recordme
//
//  Created by abbe on 2025-04-22.
//

import SwiftUI
import ScreenCaptureKit
import os.log

struct SourcePickerView: View {
    /// Closure executed once the user chooses a display or window.
    var onSelect: (SCContentFilter) -> Void

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SourcePicker")

    @Environment(\.dismiss) private var dismiss
    @State private var displays: [SCDisplay] = []
    @State private var windows: [SCWindow]  = []
    @State private var applications: [SCRunningApplication] = []

    // List of system apps to filter out
    private let systemApps = [
        "Control Center", "Dock", "Notification Center", "SystemUIServer",
        "Window Server", "Spotlight", "Finder", "MenuBar", "MenuItem", 
        "StatusItem", "ControlCenter", "NotificationCenter", "Siri", 
        "MenuBarExtra", "StatusBarApp", "StatusIndicator", ""
    ]

    // Filter windows to only show user applications
    private var userWindows: [SCWindow] {
        return windows.filter { window in
            guard let app = window.owningApplication else { return false }
            
            // Filter out system apps from list
            if systemApps.contains(app.applicationName) {
                return false
            }
            
            // Filter out windows with empty titles or system-specific titles
            guard let title = window.title, !title.isEmpty else { return false }
            let systemTitles = [
                "Menu Bar", "StatusBar", "MenuBar", "Status indicator",
                "Item-0", "Item-", "Desktop", "Wallpaper", "Display 1 Backstop", "underbelly"
            ]
            if systemTitles.contains(where: { title.contains($0) || title.starts(with: $0) }) {
                return false
            }
            
            // Filter out very small windows (likely system UI elements)
            if window.frame.width < 50 || window.frame.height < 50 { return false }
            
            // Filter out windows that are likely system UI based on bundle ID patterns
            let bundleID = app.bundleIdentifier
            let systemBundlePatterns = [
                "com.apple.controlcenter",
                "com.apple.systemuiserver", 
                "com.apple.dock",
                "com.apple.notificationcenter",
                "com.apple.spotlight",
                "com.apple.menubar"
            ]
            if systemBundlePatterns.contains(where: { bundleID.contains($0) }) { return false }
            
            return true
        }
    }

    // Group windows by application
    private var appGroups: [String: [SCWindow]] {
        Dictionary(grouping: userWindows) { window in
            window.owningApplication?.applicationName ?? "Unknown"
        }
    }

    @ViewBuilder
    private var displaysSection: some View {
        if !displays.isEmpty {
            Section("Displays") {
                ForEach(displays, id: \.displayID) { display in
                    Button("Display \(display.displayID)") {
                        let filter = SCContentFilter(display: display, excludingWindows: [])
                        onSelect(filter)
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var windowsSection: some View {
        ForEach(appGroups.keys.sorted(), id: \.self) { appName in
            if let appWindows = appGroups[appName], !appWindows.isEmpty {
                Section(appName) {
                    ForEach(appWindows, id: \.windowID) { window in
                        Button(window.title ?? "Untitled Window") {
                            let filter = SCContentFilter(desktopIndependentWindow: window)
                            onSelect(filter)
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                displaysSection
                windowsSection
    
            }
            .navigationTitle("Select Source")
            .task { await loadContent() }
        }
        .frame(minWidth: 400, minHeight: 350)
    }

    /// Fetches shareable content on a background thread, then publishes on the MainActor.
    @Sendable
    private func loadContent() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            await MainActor.run {
                self.displays = content.displays
                self.windows  = content.windows
                
                // Log available sources
                self.logger.info("--- Available Recording Sources ---")
                
                // Log displays
                self.logger.info("Displays (\(content.displays.count)):")
                for display in content.displays {
                    self.logger.info("Display ID: \(display.displayID), Width: \(display.width), Height: \(display.height)")
                }
                
                // Log windows
                self.logger.info("Windows (\(content.windows.count)):")
                for window in content.windows {
                    let appName = window.owningApplication?.applicationName ?? "Unknown"
                    self.logger.info("Window: \(window.windowID), App: \(appName), Title: \(window.title ?? "Untitled")")
                }
                
                // Log filtered windows
                let filteredCount = self.userWindows.count
                self.logger.info("Filtered user application windows: \(filteredCount)")
                for window in self.userWindows {
                    let appName = window.owningApplication?.applicationName ?? "Unknown"
                    self.logger.info("Showing: \(appName) - \(window.title ?? "Untitled")")
                }
            }
        } catch {
            self.logger.error("Failed to load shareable content: \(error.localizedDescription)")
        }
    }
}

