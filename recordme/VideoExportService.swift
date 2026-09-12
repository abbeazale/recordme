import AVFoundation
import Foundation

/// Exports edits without modifying the original recording.
@MainActor
final class VideoExportService {
    private var activeTask: Task<Void, Error>?

    func exportTrimmedCopy(
        sourceURL: URL,
        timeRange: CMTimeRange?,
        style: CanvasStyle = CanvasStyle(),
        destination: URL? = nil,
        settings: ExportSettings = ExportSettings(),
        cursor: CursorRecording = CursorRecording(),
        effects: CursorEffectsSettings = CursorEffectsSettings(),
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> URL {
        guard activeTask == nil else { throw VideoExportError.failed("An export is already running.") }
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let range = timeRange ?? CMTimeRange(start: .zero, duration: duration)
        guard range.isValid, !range.isEmpty, range.start.seconds.isFinite, range.duration.seconds.isFinite,
              range.duration.seconds > 0,
              CMTimeCompare(range.start, .zero) >= 0,
              CMTimeCompare(CMTimeRangeGetEnd(range), duration) <= 0 else {
            throw VideoExportError.invalidTimeRange
        }
        try Task.checkCancellation()
        guard let composition = try await VideoCompositionBuilder.make(asset: asset, style: style, exportSettings: settings, cursor: cursor, effects: effects) else {
            throw VideoExportError.incomplete
        }
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let outputURL = destination ?? makeAvailableOutputURL(for: sourceURL)
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw VideoExportError.failed("Choose a new filename to preserve the existing file.")
        }
        progress(0)
        defer { activeTask = nil }
        do {
            let job = try VideoEncodingJob(asset: asset, videoTracks: videoTracks, audioTracks: audioTracks,
                                           composition: composition, timeRange: range, destination: outputURL, settings: settings)
            let task = Task.detached(priority: .userInitiated) { try await job.run(progress: progress) }
            activeTask = task
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            guard Self.hasNonEmptyFile(at: outputURL) else {
                throw VideoExportError.missingOutput
            }
            progress(1)
            return outputURL
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    func cancel() {
        activeTask?.cancel()
    }

    private func makeAvailableOutputURL(for sourceURL: URL) -> URL {
        let directory = sourceURL.deletingLastPathComponent()
        let basename = sourceURL.deletingPathExtension().lastPathComponent
        let fileManager = FileManager.default

        for suffix in 1...10_000 {
            let label = suffix == 1 ? "edited" : "edited-\(suffix)"
            let candidate = directory.appendingPathComponent("\(basename)-\(label).mp4")
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return directory.appendingPathComponent("\(basename)-edited-\(UUID().uuidString).mp4")
    }

    private static func hasNonEmptyFile(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              let values = try? url.resourceValues(forKeys: [.fileSizeKey]) else {
            return false
        }
        return (values.fileSize ?? 0) > 0
    }


}

enum VideoExportError: LocalizedError {
    case invalidTimeRange
    case unsupportedMP4Export
    case failed(String)
    case incomplete
    case missingOutput

    var errorDescription: String? {
        switch self {
        case .invalidTimeRange:
            return "The selected trim range is not valid."
        case .unsupportedMP4Export:
            return "This recording cannot be exported as an MP4 file."
        case .failed(let message):
            return "Export failed: \(message)"
        case .incomplete:
            return "The export ended before the edited copy was finished."
        case .missingOutput:
            return "The export completed, but its output file could not be found."
        }
    }
}
