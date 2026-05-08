//
//  ContentView.swift
//  recordme
//
//  Created by abbe on 2025-04-10.
//

import SwiftUI
import ScreenCaptureKit
import AppKit
import OSLog

// Defines the available sources for screen recording.
enum RecordingSourceType {
    case display
    case window
}


struct ContentView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "recordme", category: "ContentView")

    @StateObject private var recorder = RecordingManager()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var permissionManager = ScreenRecordingPermissionManager()
    @State private var selectedFilter: SCContentFilter?
    @State private var errorMessage: String?
    @State private var selectedSourceType: RecordingSourceType = .display
    @State private var captureSystemAudio: Bool = true
    @State private var showCamera: Bool = false
    @State private var showSourcePicker = false
    @State private var recordedVideoURL: URL?
    @State private var thumbnailCache: [CGWindowID: NSImage] = [:]
    @State private var windowsWithPreview: [SCWindow] = []
    @State private var displayPreviewImages: [CGDirectDisplayID: CGImage] = [:]
    @State private var sourceLoadTask: Task<Void, Never>?
    @State private var previewUpdateTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Dark background
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
            
            if permissionManager.isAuthorized {
                VStack(spacing: 0) {
                    // Top bar with settings
                    topBar
                    
                    // Main preview area
                    previewArea
                    
                    // Bottom control bar
                    bottomControlBar
                }
            } else {
                // Permission request view
                permissionView
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
        .onChange(of: recorder.runtimeErrorMessage) {
            if let message = recorder.runtimeErrorMessage {
                errorMessage = message
            }
        }
        .onAppear {
            recorder.setCameraManager(cameraManager)
        }
        .onDisappear {
            sourceLoadTask?.cancel()
            previewUpdateTask?.cancel()
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
                                Group {
                                    if let thumbnail = thumbnailCache[window.windowID] {
                                        Image(nsImage: thumbnail)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    } else {
                                        Rectangle()
                                            .fill(Color.black.opacity(0.2))
                                            .overlay(ProgressView())
                                    }
                                }
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
            
            Spacer()
            
            //for when i add settings if i do lol
            /*Button(action: {
              
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Settings") */
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
                    
                    VStack(spacing: 16) {
                        Image(systemName: "display")
                            .font(.system(size: 64, weight: .thin))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("Select a source to see preview")
                                .font(.system(.title2, design: .rounded, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Choose from a display or window")
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
            
            let cameraState = CameraControlState.make(
                hasCamera: cameraManager.hasCamera,
                isAuthorized: cameraManager.isAuthorized,
                showCamera: showCamera,
                isCapturing: cameraManager.isCapturing
            )

            cameraToggleButton(
                state: cameraState,
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
        let state = RecordingButtonState.make(isRecording: recorder.isRecording, hasSelectedSource: selectedFilter != nil)

        return Button(action: state.isRecording ? stopRecording : startRecording) {
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
    
    // State for available displays and windows
    @State private var availableDisplays: [SCDisplay] = []
    @State private var availableWindows: [SCWindow] = []
    
    // Load available displays and capture previews
    private func loadDisplays() {
        guard permissionManager.isAuthorized else { return }

        sourceLoadTask?.cancel()
        sourceLoadTask = Task {
            do {
                let displays = try await RecordingSourceLoader.loadDisplays()
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.availableDisplays = displays
                    self.displayPreviewImages = [:]
                }

                for display in displays {
                    guard !Task.isCancelled else { return }

                    if let previewImage = try? await RecordingSourceThumbnailProvider.captureDisplayPreview(for: display) {
                        await MainActor.run {
                            self.displayPreviewImages[display.displayID] = previewImage
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    if !Task.isCancelled {
                        self.errorMessage = "Failed to load displays: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    // Load available windows (filtered)
    private func loadWindows() {
        guard permissionManager.isAuthorized else { return }

        sourceLoadTask?.cancel()
        sourceLoadTask = Task {
            do {
                let windows = try await RecordingSourceLoader.loadUserWindows()
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.availableWindows = windows
                    self.windowsWithPreview = []
                    self.thumbnailCache = [:]
                }

                for window in windows {
                    guard !Task.isCancelled else { return }

                    if let image = try? await RecordingSourceThumbnailProvider.captureThumbnail(for: window) {
                        await MainActor.run {
                            self.thumbnailCache[window.windowID] = image
                            self.windowsWithPreview.append(window)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    if !Task.isCancelled {
                        self.errorMessage = "Failed to load windows: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    // Start recording
    private func startRecording() {
        guard let filter = selectedFilter else { return }
        
        Task {
            do {
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                let filename = RecordingFileNameBuilder.makeFilename()
                let url = downloads.appendingPathComponent(filename)
                
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
                // Video saved successfully
                logger.info("Recording saved to: \(recordedVideoURL?.path ?? "unknown location", privacy: .public)")
            } catch {
                errorMessage = "Failed to save recording: \(error.localizedDescription)"
            }
        }
    }
    
    // Watch for changes to the selected filter and start preview
    private func updatePreview() {
        if let filter = selectedFilter {
            previewUpdateTask?.cancel()
            previewUpdateTask = Task {
                await recorder.stopPreview()  // Stop existing preview first (non-throwing)
                do {
                    guard !Task.isCancelled else { return }
                    try await recorder.startPreview(filter: filter)
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            errorMessage = "Failed to start preview: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Permission View
    
    @ViewBuilder
    private var permissionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "display.trianglebadge.exclamationmark")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundColor(.orange)
                
                VStack(spacing: 8) {
                    Text("Screen Recording Permission Required")
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        Text("RecordMe needs permission to record your screen to capture displays and windows.")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)
                        
                        if permissionManager.authorizationStatus == .denied {
                            Text("Permission was previously denied. Click 'Grant Permission' to try again, or use 'Open System Preferences' to enable manually.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 400)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            
            VStack(spacing: 12) {
                if permissionManager.authorizationStatus == .checking {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking permissions...")
                            .font(.system(.callout, design: .rounded))
                    }
                    .padding(.vertical, 8)
                } else {
                    Button {
                        Task {
                            await permissionManager.requestPermission()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 14, weight: .medium))
                            Text("Grant Permission")
                                .font(.system(.callout, design: .rounded, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.blue)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Add refresh button for when permissions might already be granted
                    Button {
                        permissionManager.checkAuthorizationStatus()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                            Text("Refresh Status")
                                .font(.system(.callout, design: .rounded, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color(.separatorColor), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Check if permissions are already granted")
                    
                    if permissionManager.authorizationStatus == .denied {
                        Button {
                            permissionManager.openSystemPreferences()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "gear")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Open System Preferences")
                                    .font(.system(.callout, design: .rounded, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Open Privacy & Security settings to manually enable screen recording")
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}
