import AVFoundation
import AVKit
import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
final class VideoEditorModel: ObservableObject {
    private let source: EditorSource
    let sourceURL: URL
    @Published private(set) var projectURL: URL?
    @Published private(set) var isSavingProject = false
    @Published private(set) var projectStatus: String?
    @Published private(set) var latestExportURL: URL?
    @Published private(set) var isTrimming = false
    private var savedEdits = RecordingEdits()
    private var pendingTrim: ProjectTrim?
    let player: AVPlayer
    private(set) var cursorRecording = CursorRecording()

    @Published private(set) var canTrim = false
    @Published private(set) var trimRange: CMTimeRange?
    @Published private(set) var isExporting = false
    @Published private(set) var exportProgress = 0.0
    @Published var errorMessage: String?
    @Published var canvasStyle = CanvasStyle()
    @Published var exportSettings = ExportSettings()
    @Published var cursorEffects = CursorEffectsSettings()
    @Published private(set) var isUpdatingPreview = false
    private var previewTask: Task<Void, Never>?

    private weak var playerView: AVPlayerView?
    private var itemStatusObservation: NSKeyValueObservation?
    private var isPlayerReady = false
    private let exportService = VideoExportService()

    init(source: EditorSource) {
        self.source = source
        self.sourceURL = source.mediaURL
        self.projectURL = source.projectURL
        let sourceURL = source.mediaURL
        if let project = source.project {
            savedEdits = project.edits
            pendingTrim = project.edits.trim
            canvasStyle = project.edits.canvas
            exportSettings = project.edits.export
            cursorEffects = project.edits.cursorEffects
            cursorRecording = project.cursor
        }
        let item = AVPlayerItem(url: sourceURL)
        player = AVPlayer(playerItem: item)
        observeStatus(of: item)
        if source.project == nil {
            do { cursorRecording = try CursorRecording.load(for: sourceURL) }
            catch { errorMessage = error.localizedDescription }
        }
        updateComposition()
    }

    var canExport: Bool { isPlayerReady && !isUpdatingPreview && !isTrimming }

    func updateComposition() {
        previewTask?.cancel()
        isUpdatingPreview = true
        let style = canvasStyle
        let effects = cursorEffects
        let cursor = cursorRecording
        previewTask = Task { @MainActor in
            do {
                let composition = try await VideoCompositionBuilder.make(asset: AVURLAsset(url: sourceURL), style: style, cursor: cursor, effects: effects)
                guard !Task.isCancelled else { return }
                player.currentItem?.videoComposition = composition
                isUpdatingPreview = false
            } catch {
                guard !Task.isCancelled else { return }
                isUpdatingPreview = false
                errorMessage = error.localizedDescription
            }
        }
    }

    var hasTrim: Bool {
        trimRange != nil
    }

    var trimDescription: String? {
        guard let trimRange else { return nil }
        let end = CMTimeRangeGetEnd(trimRange)
        return "\(Self.formatTime(trimRange.start)) to \(Self.formatTime(end))"
    }

    func attachPlayerView(_ view: AVPlayerView) {
        playerView = view
        updateCanTrim()
    }

    func detachPlayerView(_ view: AVPlayerView) {
        if playerView === view {
            playerView = nil
            canTrim = false
        }
    }

    func beginTrimming() {
        guard !isExporting,
              let playerView,
              playerView.canBeginTrimming else {
            errorMessage = "This recording is not ready to trim yet."
            return
        }

        player.pause()
        isTrimming = true
        playerView.beginTrimming { [weak self] result in
            Task { @MainActor [weak self] in
                self?.isTrimming = false
                guard result == .okButton else { return }
                self?.captureTrimRange()
            }
        }
    }

    func resetTrim() {
        guard let item = player.currentItem, !isExporting else { return }
        item.reversePlaybackEndTime = .invalid
        item.forwardPlaybackEndTime = .invalid
        trimRange = nil
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func exportEditedCopy() async -> URL? {
        guard !isExporting else { return nil }
        guard canExport else { return nil }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + "-edited.mp4"
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let destination = panel.url else { return nil }

        isExporting = true
        exportProgress = 0
        player.pause()

        defer {
            isExporting = false
        }

        do {
            let output = try await exportService.exportTrimmedCopy(
                sourceURL: sourceURL,
                timeRange: trimRange,
                style: canvasStyle,
                destination: destination,
                settings: exportSettings,
                cursor: cursorRecording,
                effects: cursorEffects
            ) { [weak self] progress in
                self?.exportProgress = progress
            }
            latestExportURL = output
            return output
        } catch is CancellationError {
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private var currentEdits: RecordingEdits {
        RecordingEdits(trim: trimRange.map { ProjectTrim(start: $0.start.seconds, end: CMTimeRangeGetEnd($0).seconds) },
                       canvas: canvasStyle, export: exportSettings, cursorEffects: cursorEffects)
    }

    func confirmDiscardEdits() -> Bool {
        guard currentEdits != savedEdits else { return true }
        let alert = NSAlert()
        alert.messageText = "Leave without saving these edits?"
        alert.informativeText = "The original video and any saved project are preserved. Use Save Project to keep these changes."
        alert.addButton(withTitle: "Keep Editing")
        alert.addButton(withTitle: "Discard Edits")
        return alert.runModal() == .alertSecondButtonReturn
    }

    func saveProject() async {
        guard canExport, !isSavingProject, !isExporting else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.recordmeProject]
        panel.nameFieldStringValue = projectURL?.lastPathComponent ?? sourceURL.deletingPathExtension().lastPathComponent + ".recordme"
        panel.directoryURL = projectURL?.deletingLastPathComponent() ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        isSavingProject = true
        projectStatus = nil
        let edits = currentEdits
        let cursor = cursorRecording
        let mediaURL = sourceURL
        let access = ScopedMediaAccess(url: destination)
        defer { isSavingProject = false; withExtendedLifetime(access) {} }
        do {
            try await Task.detached(priority: .userInitiated) {
                try RecordingProjectStore.save(sourceURL: mediaURL, destination: destination, edits: edits, cursor: cursor)
            }.value
            projectURL = destination
            savedEdits = edits
            projectStatus = "Project saved: \(destination.lastPathComponent)"
        } catch { errorMessage = error.localizedDescription }
    }

    func cancelExport() {
        exportService.cancel()
    }

    func pause() {
        player.pause()
        previewTask?.cancel()
    }

    private func observeStatus(of item: AVPlayerItem) {
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            let errorDescription = item.error?.localizedDescription

            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.isPlayerReady = true
                    self.updateCanTrim()
                    if let trim = self.pendingTrim {
                        self.pendingTrim = nil
                        if trim.end <= item.duration.seconds + 0.001 {
                            self.trimRange = trim.timeRange
                            item.reversePlaybackEndTime = trim.timeRange.start
                            item.forwardPlaybackEndTime = CMTimeRangeGetEnd(trim.timeRange)
                            self.player.seek(to: trim.timeRange.start)
                        } else {
                            self.errorMessage = "The saved trim extends beyond this video's duration."
                        }
                    }
                case .failed:
                    self.isPlayerReady = false
                    self.canTrim = false
                    self.errorMessage = errorDescription ?? "The recording could not be opened."
                default:
                    self.isPlayerReady = false
                    self.canTrim = false
                }
            }
        }
    }

    private func updateCanTrim() {
        canTrim = isPlayerReady && (playerView?.canBeginTrimming ?? false)
    }

    private func captureTrimRange() {
        guard let item = player.currentItem else { return }

        let duration = item.duration
        let start = Self.usable(item.reversePlaybackEndTime) ? item.reversePlaybackEndTime : .zero
        let end = Self.usable(item.forwardPlaybackEndTime) ? item.forwardPlaybackEndTime : duration

        guard Self.usable(duration),
              Self.usable(start),
              Self.usable(end),
              CMTimeCompare(start, .zero) >= 0,
              CMTimeCompare(end, start) > 0,
              CMTimeCompare(end, duration) <= 0 else {
            errorMessage = "The selected trim range is not valid."
            return
        }

        let changedStart = CMTimeCompare(start, .zero) > 0
        let changedEnd = abs(CMTimeGetSeconds(duration) - CMTimeGetSeconds(end)) > 0.001
        trimRange = changedStart || changedEnd ? CMTimeRange(start: start, end: end) : nil
        player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private static func usable(_ time: CMTime) -> Bool {
        time.isValid && !time.isIndefinite && CMTimeGetSeconds(time).isFinite
    }

    private static func formatTime(_ time: CMTime) -> String {
        let total = max(0, (CMTimeGetSeconds(time) * 10).rounded())
        let hours = Int(total) / 36_000
        let minutes = (Int(total) % 36_000) / 600
        let seconds = Double(Int(total) % 600) / 10
        if hours > 0 {
            return String(format: "%d:%02d:%04.1f", hours, minutes, seconds)
        }
        return String(format: "%02d:%04.1f", minutes, seconds)
    }
}
