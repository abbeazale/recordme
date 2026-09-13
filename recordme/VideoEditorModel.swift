import AVFoundation
import AVKit
import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
final class VideoEditorModel: ObservableObject {
    let sourceURL: URL
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

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        let item = AVPlayerItem(url: sourceURL)
        player = AVPlayer(playerItem: item)
        observeStatus(of: item)
        do { cursorRecording = try CursorRecording.load(for: sourceURL) }
        catch { errorMessage = error.localizedDescription }
    }

    var canExport: Bool { isPlayerReady && !isUpdatingPreview }

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
        return "\(Self.formatTime(trimRange.start)) – \(Self.formatTime(end))"
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
        playerView.beginTrimming { [weak self] result in
            Task { @MainActor [weak self] in
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
            return try await exportService.exportTrimmedCopy(
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
        } catch is CancellationError {
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
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
        let seconds = max(0, Int(CMTimeGetSeconds(time).rounded(.down)))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
