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
    @StateObject private var cameraManager = CameraManager()
    @State private var selectedFilter: SCContentFilter? // The content filter for screen capture.
    @State private var errorMessage: String? // Holds error messages for display in an alert.
    @State private var selectedSourceType: RecordingSourceType = .display // Tracks the currently selected source type (display, window, etc.).
    @State private var captureSystemAudio: Bool = true // Whether to capture system audio along with video.
    @State private var showCamera: Bool = false // Whether to show camera overlay
    @State private var showSourcePicker = false // Controls the presentation of the source picker sheet.
    @State private var showEditingView = false // Controls the presentation of the video editing view after recording.
    @State private var recordedVideoURL: URL? // URL of the last recorded video.
    @State private var thumbnailCache: [CGWindowID: NSImage] = [:] // Caches window thumbnails for the picker.
    @State private var windowsWithPreview: [SCWindow] = [] // Windows that have successfully generated a thumbnail.
    @State private var availableHeight: CGFloat = 500 // Dynamically calculated height for the preview area.
    @State private var displayPreviewImages: [CGDirectDisplayID: CGImage] = [:] // Caches display preview images.

    var body: some View {
        ZStack {
            // Dark background
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with settings
                topBar
                
                // Main preview area
                previewArea
                
                // Bottom control bar
                bottomControlBar
            }
        }
        .sheet(isPresented: $showSourcePicker) {
            directSourcePicker
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
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
        .onAppear {
            recorder.setCameraManager(cameraManager)
        }
        .onDisappear {
            Task {
                await recorder.stopPreview()
                cameraManager.stopCapture()
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
        }
    }
    
    // Display picker (shows all available displays with preview)
    private var displayPicker: some View {
        VStack {
            HStack {
                Text("Click on a display to select it")
                    .font(.headline)
                Spacer()
                Button {
                    showSourcePicker = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                }
                .buttonStyle(CircularButtonStyle(size: 28, color: Color(.controlBackgroundColor)))
                .help("Close")
            }
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
                            VStack(spacing: 12) {
                                // Display preview
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(height: 120)
                                    .overlay(
                                        Group {
                                            if let previewImage = displayPreviewImages[display.displayID] {
                                                Image(previewImage, scale: 1.0, label: Text("Display Preview"))
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                            } else {
                                                ProgressView()
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    )
                                    .cornerRadius(8)
                                
                                VStack(spacing: 4) {
                                    Text("Display \(display.displayID)")
                                        .font(.system(.headline, design: .rounded, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("\(display.width) × \(display.height)")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(1.0)
                        .onHover { isHovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                // Handled by button style
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(Color(.windowBackgroundColor))
        .onKeyPress(.escape) {
            showSourcePicker = false
            return .handled
        }
        .onAppear {
            loadDisplays()
        }
    }
    
    // Window picker (shows all available windows with thumbnails)
    private var windowPicker: some View {
        VStack {
            HStack {
                Text("Click on a window to select it")
                    .font(.headline)
                Spacer()
                Button {
                    showSourcePicker = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                }
                .buttonStyle(CircularButtonStyle(size: 28, color: Color(.controlBackgroundColor)))
                .help("Close")
            }
            .padding()
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 20) {
                    ForEach(windowsWithPreview, id: \.windowID) { window in
                        Button {
                            let filter = SCContentFilter(desktopIndependentWindow: window)
                            selectedFilter = filter
                            showSourcePicker = false
                        } label: {
                            VStack(spacing: 8) {
                                Image(nsImage: thumbnailCache[window.windowID]!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 120)
                                    .cornerRadius(6)
                                
                                VStack(spacing: 2) {
                                    Text(window.title ?? "Untitled")
                                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.primary)
                                    
                                    if let appName = window.owningApplication?.applicationName {
                                        Text(appName)
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(.windowBackgroundColor))
        .onKeyPress(.escape) {
            showSourcePicker = false
            return .handled
        }
        .onAppear {
            loadWindows()
        }
    }
    
    
    
    // MARK: - UI Components
    
    private var topBar: some View {
        HStack {
            // App title (optional)
            Spacer()
            
            // Settings button
            Button(action: {
                // Settings action
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Settings")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
    
    private var previewArea: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(.controlBackgroundColor)
                    .opacity(0.5)
                
                if let img = recorder.previewImage {
                    // Live preview
                    ZStack(alignment: .bottomTrailing) {
                        Image(img, scale: 1.0, label: Text("Preview"))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: geometry.size.width - 40)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        // Camera overlay
                        if showCamera && cameraManager.isCapturing, let cameraImg = cameraManager.cameraImage {
                            Image(cameraImg, scale: 1.0, label: Text("Camera"))
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 160, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                                .padding(16)
                        }
                    }
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "display")
                            .font(.system(size: 64, weight: .thin))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("Select a source to see preview")
                                .font(.system(.title2, design: .rounded, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Choose from display, window, or application")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var bottomControlBar: some View {
        HStack(spacing: 12) {
            // Source selection buttons
            sourceToggleButton(
                isSelected: selectedSourceType == .display,
                icon: "display",
                title: "Display",
                action: { 
                    selectedSourceType = .display
                    showSourcePicker = true 
                }
            )
            
            sourceToggleButton(
                isSelected: selectedSourceType == .window,
                icon: "macwindow",
                title: "Window", 
                action: {
                    selectedSourceType = .window
                    showSourcePicker = true
                }
            )
            
            Spacer()
            
            // Audio controls
            audioToggleButton(
                isActive: recorder.captureMicrophone,
                icon: recorder.captureMicrophone ? "mic" : "mic.slash",
                title: recorder.captureMicrophone ? "Mic" : "No Mic",
                action: { recorder.captureMicrophone.toggle() }
            )
            
            audioToggleButton(
                isActive: captureSystemAudio,
                icon: captureSystemAudio ? "speaker.wave.2" : "speaker.slash",
                title: captureSystemAudio ? "System Audio" : "No Audio",
                isProminent: captureSystemAudio,
                action: { captureSystemAudio.toggle() }
            )
            
            cameraToggleButton(
                isActive: showCamera && cameraManager.isCapturing,
                icon: getCameraIcon(),
                title: getCameraText(),
                action: {
                    showCamera.toggle()
                    if showCamera && cameraManager.isAuthorized {
                        cameraManager.startCapture()
                    } else {
                        cameraManager.stopCapture()
                    }
                }
            )
            
            Spacer()
            
            // Recording button
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
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(.callout, design: .rounded, weight: .medium))
            }
            .foregroundColor(getAudioButtonColor(isActive: isActive, isProminent: isProminent))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(getAudioButtonBackground(isActive: isActive, isProminent: isProminent))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .help(title)
    }
    
    private func cameraToggleButton(isActive: Bool, icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(.callout, design: .rounded, weight: .medium))
            }
            .foregroundColor(isActive ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? Color.purple : Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!cameraManager.hasCamera)
        .help(getCameraHelpText())
    }
    
    private var recordingButton: some View {
        Button(action: recorder.isRecording ? stopRecording : startRecording) {
            HStack(spacing: 8) {
                if recorder.isRecording {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                    Text("Stop Recording")
                } else {
                    Image(systemName: "record.circle")
                    Text("Start Recording")
                }
            }
            .font(.system(.callout, design: .rounded, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(recorder.isRecording ? Color.red : (selectedFilter != nil ? Color.red : Color.gray))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(selectedFilter == nil && !recorder.isRecording)
        .help(recorder.isRecording ? "Stop recording" : "Start recording")
    }
    
    // Helper functions for button styling
    private func getAudioButtonColor(isActive: Bool, isProminent: Bool) -> Color {
        if isProminent && isActive {
            return .white
        } else {
            return .primary
        }
    }
    
    private func getAudioButtonBackground(isActive: Bool, isProminent: Bool) -> Color {
        if isProminent && isActive {
            return .blue
        } else {
            return Color(.controlBackgroundColor)
        }
    }
    
    // Camera helper functions
    private func getCameraIcon() -> String {
        if !cameraManager.hasCamera {
            return "video.slash"
        } else if showCamera && cameraManager.isCapturing {
            return "video.fill"
        } else if showCamera && !cameraManager.isAuthorized {
            return "video.badge.exclamationmark"
        } else {
            return "video.slash"
        }
    }
    
    private func getCameraText() -> String {
        if !cameraManager.hasCamera {
            return "No camera"
        } else if showCamera && cameraManager.isCapturing {
            return "Camera"
        } else if showCamera && !cameraManager.isAuthorized {
            return "Camera access"
        } else {
            return "No camera"
        }
    }
    
    private func getCameraHelpText() -> String {
        if !cameraManager.hasCamera {
            return "No camera available"
        } else if !cameraManager.isAuthorized {
            return "Camera access required"
        } else if showCamera {
            return "Hide camera overlay"
        } else {
            return "Show camera overlay"
        }
    }
    
    // State for available displays and windows
    @State private var availableDisplays: [SCDisplay] = []
    @State private var availableWindows: [SCWindow] = []
    
    // Load available displays and capture previews
    private func loadDisplays() {
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
            if let content = content {
                DispatchQueue.main.async {
                    self.availableDisplays = content.displays
                    // Clear existing display previews
                    self.displayPreviewImages = [:]
                    
                    // Capture preview for each display
                    for display in content.displays {
                        Task {
                            if let previewImage = await captureDisplayPreview(for: display) {
                                DispatchQueue.main.async {
                                    self.displayPreviewImages[display.displayID] = previewImage
                                }
                            }
                        }
                    }
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
                        
                        // Enhanced system apps filtering
                        let systemApps = [
                            "Control Center", "Dock", "Notification Center", "SystemUIServer",
                            "Window Server", "Spotlight", "MenuItem", "StatusItem",
                            "ControlCenter", "NotificationCenter", "Siri", "MenuBarExtra",
                            "StatusBarApp", "StatusIndicator"
                        ]
                        if systemApps.contains(app.applicationName) { return false }
                        
                        // Filter out windows with system-like titles
                        guard let title = window.title, !title.isEmpty else { return false }
                        let systemTitles = [
                            "Menu Bar", "StatusBar", "MenuBar", "Status indicator",
                            "Item-0", "Item-", "Desktop", "Wallpaper", "Display 1 Backstop", "underbelly"
                        ]
                        if systemTitles.contains(where: { title.contains($0) || title.starts(with: $0) }) { return false }
                        
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
      let config = SCStreamConfiguration()
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
    
    /// Grab one frame of the given display as a CGImage.
    private func captureDisplayPreview(for display: SCDisplay) async -> CGImage? {
        // Build the filter
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // Configure a one-shot stream for preview
        let config = SCStreamConfiguration()
        // Use smaller resolution for preview
        let maxPreviewWidth: Int = 300
        let aspectRatio = Double(display.height) / Double(display.width)
        config.width = maxPreviewWidth
        config.height = Int(Double(maxPreviewWidth) * aspectRatio)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // one frame
        config.pixelFormat = kCVPixelFormatType_32BGRA
        
        do {
            // Capture the display
            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            return cgImage
        } catch {
            print("🖼️ Display preview capture failed:", error)
            return nil
        }
    }
    
    // Start recording
    private func startRecording() {
        guard let filter = selectedFilter else { return }
        
        Task {
            do {
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                let filename = "ScreenRecording-\(ISO8601DateFormatter().string(from: Date())).mp4"
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

