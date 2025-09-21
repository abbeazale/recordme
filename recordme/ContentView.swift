//
//  ContentView.swift
//  recordme
//
//  Created by abbe on 2025-04-10.
//

import SwiftUI
import ScreenCaptureKit
import AVFoundation
import AVKit
import CoreMedia
import AppKit // For NSWorkspace and NSImage

// Defines the available sources for screen recording.
enum RecordingSourceType {
    case display
    case window
    case area // Placeholder for future area selection functionality
    case device // Placeholder for future device recording functionality
}

// SwiftUI View extension to provide a cleaner onChange modifier for older OS versions.
extension View {
    func onChange<T: Equatable>(of value: T, perform action: @escaping () -> Void) -> some View {
        self.onChange(of: value) { _, _ in // New value is not used in this simplified version
            action()
        }
    }
}

struct ContentView: View {
    @StateObject private var recorder = RecordingManager()
    @State private var selectedFilter: SCContentFilter? // The content filter for screen capture.
    @State private var errorMessage: String? // Holds error messages for display in an alert.
    @State private var selectedSourceType: RecordingSourceType = .display // Tracks the currently selected source type (display, window, etc.).
    @State private var captureSystemAudio: Bool = true // Whether to capture system audio along with video.
    @State private var showSourcePicker = false // Controls the presentation of the source picker sheet.
    @State private var showEditingView = false // Controls the presentation of the video editing view after recording.
    @State private var recordedVideoURL: URL? // URL of the last recorded video.
    @State private var thumbnailCache: [CGWindowID: NSImage] = [:] // Caches window thumbnails for the picker.
    @State private var windowsWithPreview: [SCWindow] = [] // Windows that have successfully generated a thumbnail.
    @State private var availableHeight: CGFloat = 500 // Dynamically calculated height for the preview area.

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Minimal interface, just preview and selection bar
                if showEditingView, let videoURL = recordedVideoURL {
                    VStack {
                        Text("Video Editor")
                            .font(.largeTitle)
                            .padding()
                        
                        // Simple video playback view
                        Rectangle()
                            .fill(Color.black)
                            .aspectRatio(16/9, contentMode: .fit)
                            .frame(maxWidth: geo.size.width * 0.9, maxHeight: geo.size.height * 0.6)
                            .overlay(
                                Text("Video saved to: \(videoURL.lastPathComponent)")
                                    .foregroundColor(.white)
                            )
                            .cornerRadius(12)
                            .padding()
                        
                        // Basic controls
                        HStack(spacing: 30) {
                            Button("Open in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([videoURL])
                            }
                            
                            Button("New Recording") {
                                showEditingView = false
                            }
                        }
                        .padding()
                    }
                    .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        // Calculate available space for preview
                        GeometryReader { previewGeo in
                            Color.clear.onAppear {
                                availableHeight = previewGeo.size.height
                            }
                            .onChange(of: previewGeo.size.height) {
                                availableHeight = previewGeo.size.height
                            }
                        }
                        
                        Spacer()
                        
                        // Preview is adaptive to window size
                        if let img = recorder.previewImage {
                            Image(img, scale: 1.0, label: Text("Preview"))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: geo.size.width * 0.9,
                                       maxHeight: availableHeight - 100) // Leave space for the toolbar
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))
                        }
                        
                        Spacer()
                        
                        // Source selection bar (always at bottom)
                        sourceSelectionBar
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .sheet(isPresented: $showSourcePicker) {
                directSourcePicker
            }
            // Simple error alert
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: selectedFilter) {
                updatePreview()
            }
            .onDisappear {
                // Stop preview when view disappears
                Task {
                    await recorder.stopPreview()
                }
            }
        }
    }

    // Direct window/display picker
    @ViewBuilder
    private var directSourcePicker: some View {
        switch selectedSourceType {
        case .display:
            displayPicker
        case .window:
            windowPicker
        case .area:
            Text("Area selection coming soon")
                .padding()
        case .device:
            Text("Device selection coming soon")
                .padding()
        }
    }
    
    // Display picker (shows all available displays)
    private var displayPicker: some View {
        VStack {
            Text("Click on a display to select it")
                .font(.headline)
                .padding()
            
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(0..<availableDisplays.count, id: \.self) { index in
                        let display = availableDisplays[index]
                        Button {
                            let filter = SCContentFilter(display: display, excludingWindows: [])
                            selectedFilter = filter
                            showSourcePicker = false
                        } label: {
                            VStack {
                                Text("Display \(display.displayID)")
                                    .font(.title2)
                                Text("\(display.width) × \(display.height)")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
        .onAppear {
            loadDisplays()
        }
    }
    
    // Window picker (shows all available windows with thumbnails)
    private var windowPicker: some View {
        VStack {
            Text("Click on a window to select it")
                .font(.headline)
                .padding()
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 20) {
                    ForEach(windowsWithPreview, id: \.windowID) { window in
                        Button {
                            let filter = SCContentFilter(desktopIndependentWindow: window)
                            selectedFilter = filter
                            showSourcePicker = false
                        } label: {
                            VStack {
                                Image(nsImage: thumbnailCache[window.windowID]!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 120)
                                
                                // window title + app name
                                Text(window.title ?? "Untitled")
                                    .lineLimit(1)
                                if let appName = window.owningApplication?.applicationName {
                                    Text(appName).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
        .onAppear {
            loadWindows()
        }
    }
    
    // Custom source selection bar UI similar to the image
    private var sourceSelectionBar: some View {
        HStack(spacing: 15) {
            Spacer()
            
            // Close button (X)
            Button(action: {}) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color(.darkGray)))
            }
            
            Divider().frame(height: 30).background(Color.gray)
            
            // Source buttons
            sourceButton(type: .display, systemName: "display", title: "Display")
            sourceButton(type: .window, systemName: "macwindow", title: "Window")
            sourceButton(type: .area, systemName: "rectangle.dashed", title: "Area")
            sourceButton(type: .device, systemName: "iphone", title: "Device")
            
            Divider().frame(height: 30).background(Color.gray)
            
            // Audio options
            Button(action: { recorder.captureMicrophone.toggle() }) {
                HStack {
                    Image(systemName: recorder.captureMicrophone ? "mic" : "mic.slash")
                    Text(recorder.captureMicrophone ? "Microphone" : "No microphone")
                }
                .padding(.vertical, 5)
                .background(recorder.captureMicrophone ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                .cornerRadius(5)
            }
            
            Button(action: { captureSystemAudio.toggle() }) {
                HStack {
                    Image(systemName: captureSystemAudio ? "speaker.wave.2" : "speaker.slash")
                    Text(captureSystemAudio ? "System audio" : "No system audio")
                }
                .padding(.vertical, 5)
                .background(captureSystemAudio ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                .cornerRadius(5)
            }
            
            Spacer()
            
            // Recording button
            if recorder.isRecording {
                Button(action: stopRecording) {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text("Stop Recording")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
                }
            } else if selectedFilter != nil {
                Button(action: startRecording) {
                    Text("Start Recording")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(Color(.darkGray).opacity(0.8))
        .cornerRadius(10)
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
    
    // State for available displays and windows
    @State private var availableDisplays: [SCDisplay] = []
    @State private var availableWindows: [SCWindow] = []
    
    // Load available displays
    private func loadDisplays() {
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
            if let content = content {
                DispatchQueue.main.async {
                    self.availableDisplays = content.displays
                }
            }
        }
    }
    
    // Load available windows (filtered)
    private func loadWindows() {
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
            if let content = content {
                DispatchQueue.main.async {
                    self.availableWindows = content.windows.filter { window in
                        guard let app = window.owningApplication else { return false }
                        // Filter out system windows
                        let systemApps = ["Control Center", "Dock", "Notification Center", "SystemUIServer"]
                        if systemApps.contains(app.applicationName) { return false }
                        return window.title != nil && !window.title!.isEmpty
                    }
                    // 1️⃣ Store the raw list (already done above)
                    // 2️⃣ Reset the “ready” list
                    self.windowsWithPreview = []
                    // 3️⃣ For each window, try to grab a thumbnail
                    for window in self.availableWindows {
                        Task {
                            if let img = await captureThumbnail(for: window) {
                                // 4️⃣ On success, cache and mark this window as “ready”
                                DispatchQueue.main.async {
                                    thumbnailCache[window.windowID] = img
                                    windowsWithPreview.append(window)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Returns the backing scale factor of the screen containing the window.
    private func scaleFactor(for window: SCWindow) -> CGFloat {
        // Find the NSScreen whose frame contains the window's origin
        let windowOrigin = CGPoint(x: window.frame.minX, y: window.frame.minY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(windowOrigin) }) {
            return screen.backingScaleFactor
        }
        // Fallback to main screen scale
        return NSScreen.main?.backingScaleFactor ?? 1.0
    }

    /// Grab one frame of the given window as an NSImage.
    private func captureThumbnail(for window: SCWindow) async -> NSImage? {
      // Build the filter
        let filter = SCContentFilter(desktopIndependentWindow: window)

      // Configure a one-shot stream at window resolution
      var config = SCStreamConfiguration()
      let scale = scaleFactor(for: window)
      config.width  = Int(window.frame.width  * scale)
      config.height = Int(window.frame.height * scale)
      config.minimumFrameInterval = CMTime(value: 1, timescale: 1)   // one frame
      config.pixelFormat = kCVPixelFormatType_32BGRA

      do {
        // This does the capture for us
        let cgImage = try await SCScreenshotManager.captureImage(
          contentFilter: filter,
          configuration: config
        )
        return NSImage(cgImage: cgImage, size: window.frame.size)
      } catch {
        print("🖼️ Thumbnail capture failed:", error)
        return nil
      }
    }
    
    // Start recording
    private func startRecording() {
        guard let filter = selectedFilter else { return }
        
        Task {
            do {
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                let filename = "ScreenRecording-\(ISO8601DateFormatter().string(from: Date())).mov"
                let sanitizedFilename = filename.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
                let url = downloads.appendingPathComponent(sanitizedFilename)
                
                recorder.captureSystemAudio = captureSystemAudio
                try await recorder.start(filter: filter, saveURL: url)
                recordedVideoURL = url
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
            }
        }
    }
    
    // Stop recording and open editing view
    private func stopRecording() {
        Task {
            do {
                try await recorder.stop()
                // Show editing view
                if let _ = recordedVideoURL {
                    DispatchQueue.main.async {
                        showEditingView = true
                    }
                }
            } catch {
                errorMessage = "Failed to save recording: \(error.localizedDescription)"
            }
        }
    }
    
    // Watch for changes to the selected filter and start preview
    private func updatePreview() {
        if let filter = selectedFilter {
            Task {
                do {
                    try await recorder.stopPreview()  // Stop existing preview first
                    try await recorder.startPreview(filter: filter)
                } catch {
                    errorMessage = "Failed to start preview: \(error.localizedDescription)"
                }
            }
        }
    }
}

