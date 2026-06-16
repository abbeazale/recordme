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
enum RecordingSourceType: Hashable {
    case display
    case window
}

struct ContentView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "recordme", category: "ContentView")

    @StateObject private var recorder = RecordingManager()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var permissionManager = ScreenRecordingPermissionManager()

    @State private var selectedFilter: SCContentFilter?
    @State private var selectedSourceType: RecordingSourceType = .display
    @State private var selectedSourceLabel: String?
    @State private var errorMessage: String?
    @State private var captureSystemAudio: Bool = true
    @State private var showCamera: Bool = false
    @State private var showSourcePicker = false

    @State private var recordedVideoURL: URL?
    @State private var showSavedBanner = false
    @State private var bannerHideTask: Task<Void, Never>?

    @State private var thumbnailCache: [CGWindowID: NSImage] = [:]
    @State private var windowsWithPreview: [SCWindow] = []
    @State private var availableDisplays: [SCDisplay] = []
    @State private var displayPreviewImages: [CGDirectDisplayID: CGImage] = [:]
    @State private var sourceLoadTask: Task<Void, Never>?
    @State private var previewUpdateTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color(.windowBackgroundColor).ignoresSafeArea()

            if permissionManager.isAuthorized {
                mainView
            } else {
                PermissionView(permissionManager: permissionManager)
            }
        }
        .sheet(isPresented: $showSourcePicker) {
            sourcePickerSheet
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
            bannerHideTask?.cancel()
            Task {
                await recorder.stopPreview()
                cameraManager.stopCapture()
            }
        }
    }

    // MARK: - Layout

    private var mainView: some View {
        VStack(spacing: 0) {
            header

            ZStack(alignment: .bottom) {
                PreviewPane(
                    previewImage: recorder.previewImage,
                    showCamera: showCamera,
                    isCameraCapturing: cameraManager.isCapturing,
                    cameraImage: cameraManager.cameraImage
                )

                if showSavedBanner {
                    savedBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            RecordingControlsView(
                hasSelectedSource: selectedFilter != nil,
                isRecording: recorder.isRecording,
                recordingStartDate: recorder.recordingStartDate,
                captureMicrophone: recorder.captureMicrophone,
                captureSystemAudio: captureSystemAudio,
                cameraState: CameraControlState.make(
                    hasCamera: cameraManager.hasCamera,
                    isAuthorized: cameraManager.isAuthorized,
                    showCamera: showCamera,
                    isCapturing: cameraManager.isCapturing
                ),
                toggleMicrophone: { recorder.captureMicrophone.toggle() },
                toggleSystemAudio: { captureSystemAudio.toggle() },
                toggleCamera: toggleCamera,
                toggleRecording: recorder.isRecording ? stopRecording : startRecording
            )
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Picker("Source", selection: $selectedSourceType) {
                Text("Display").tag(RecordingSourceType.display)
                Text("Window").tag(RecordingSourceType.window)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 168)
            .disabled(recorder.isRecording)
            .onChange(of: selectedSourceType) { _, _ in
                selectedSourceLabel = nil
                if !recorder.isRecording {
                    showSourcePicker = true
                }
            }

            Button {
                showSourcePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selectedSourceType == .display ? "display" : "macwindow")
                    Text(sourceButtonTitle)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 280, alignment: .leading)
                .fixedSize()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(recorder.isRecording)
            .help("Choose a source to record")

            Spacer()
        }
        .padding(.leading, AppMetrics.trafficLightInset)
        .padding(.trailing, AppMetrics.barHPadding)
        .padding(.vertical, AppMetrics.barVPadding)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var sourceButtonTitle: String {
        if let selectedSourceLabel { return selectedSourceLabel }
        return selectedSourceType == .display ? "Choose a display…" : "Choose a window…"
    }

    private var savedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 1) {
                Text("Recording saved")
                    .font(.callout.weight(.semibold))
                if let url = recordedVideoURL {
                    Text("\(url.deletingLastPathComponent().lastPathComponent) / \(url.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Button("Show in Finder", action: revealInFinder)
                .buttonStyle(.link)

            Button {
                bannerHideTask?.cancel()
                withAnimation { showSavedBanner = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 5)
        .padding(.bottom, 22)
    }

    // MARK: - Source picker sheet

    @ViewBuilder
    private var sourcePickerSheet: some View {
        switch selectedSourceType {
        case .display:
            DisplayPickerView(
                displays: availableDisplays,
                previews: displayPreviewImages,
                onSelect: chooseDisplay,
                onClose: { showSourcePicker = false }
            )
            .onAppear { loadDisplays() }
        case .window:
            WindowPickerView(
                windows: windowsWithPreview,
                thumbnails: thumbnailCache,
                onSelect: chooseWindow,
                onClose: { showSourcePicker = false }
            )
            .onAppear { loadWindows() }
        }
    }

    private func chooseDisplay(_ display: SCDisplay) {
        selectedFilter = SCContentFilter(display: display, excludingWindows: [])
        selectedSourceLabel = "Display \(display.displayID) · \(display.width)×\(display.height)"
        showSourcePicker = false
    }

    private func chooseWindow(_ window: SCWindow) {
        selectedFilter = SCContentFilter(desktopIndependentWindow: window)
        if let title = window.title, !title.isEmpty {
            selectedSourceLabel = title
        } else {
            selectedSourceLabel = window.owningApplication?.applicationName ?? "Untitled"
        }
        showSourcePicker = false
    }

    // MARK: - Actions

    private func toggleCamera() {
        showCamera.toggle()
        if showCamera && cameraManager.isAuthorized {
            cameraManager.startCapture()
        } else {
            cameraManager.stopCapture()
        }
    }

    private func revealInFinder() {
        guard let url = recordedVideoURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func presentSavedBanner() {
        guard recordedVideoURL != nil else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showSavedBanner = true
        }
        bannerHideTask?.cancel()
        bannerHideTask = Task {
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation { showSavedBanner = false }
            }
        }
    }

    // MARK: - Source loading

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

    // Stop recording and surface the saved-file banner
    private func stopRecording() {
        Task {
            do {
                try await recorder.stop()
                if let url = recordedVideoURL {
                    logger.info("Recording saved to: \(url.path, privacy: .public)")
                }
                presentSavedBanner()
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
}
