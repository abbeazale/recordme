import AVFoundation
import AVKit
import Foundation

@MainActor
final class VideoEditorModel: ObservableObject {
    let sourceURL: URL
    let player: AVPlayer

    @Published private(set) var canTrim = false
    @Published private(set) var trimRange: CMTimeRange?
    @Published private(set) var isExporting = false
    @Published private(set) var exportProgress = 0.0
    @Published var errorMessage: String?

    private weak var playerView: AVPlayerView?
    private var itemStatusObservation: NSKeyValueObservation?
    private var isPlayerReady = false
    private let exportService = VideoExportService()

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        let item = AVPlayerItem(url: sourceURL)
        player = AVPlayer(playerItem: item)
        observeStatus(of: item)
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
        guard let trimRange else {
            errorMessage = "Choose Trim and set the beginning or end of the recording first."
            return nil
        }

        isExporting = true
        exportProgress = 0
        player.pause()

        defer {
            isExporting = false
        }

        do {
            return try await exportService.exportTrimmedCopy(
                sourceURL: sourceURL,
                timeRange: trimRange
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
