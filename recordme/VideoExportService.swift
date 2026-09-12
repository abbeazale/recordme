import AVFoundation
import Foundation

/// Exports edits without modifying the original recording.
@MainActor
final class VideoExportService {
    private var activeSession: AVAssetExportSession?

    func exportTrimmedCopy(
        sourceURL: URL,
        timeRange: CMTimeRange?,
        style: CanvasStyle = CanvasStyle(),
        destination: URL? = nil,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let range = timeRange ?? CMTimeRange(start: .zero, duration: duration)
        guard range.isValid, !range.isEmpty,
              CMTimeCompare(range.start, .zero) >= 0,
              CMTimeCompare(CMTimeRangeGetEnd(range), duration) <= 0 else {
            throw VideoExportError.invalidTimeRange
        }
        try Task.checkCancellation()
        let composition = try await VideoCompositionBuilder.make(asset: asset, style: style)
        let session = try makeSession(for: asset, rendersVideo: composition != nil)
        let outputURL = destination ?? makeAvailableOutputURL(for: sourceURL)
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw VideoExportError.failed("Choose a new filename to preserve the existing file.")
        }
        session.timeRange = range
        session.videoComposition = composition
        session.shouldOptimizeForNetworkUse = true
        activeSession = session
        progress(0)

        let progressTask = Task { @MainActor in
            for await state in session.states(updateInterval: 0.1) {
                guard !Task.isCancelled else { return }
                if case .exporting(let exportProgress) = state {
                    progress(exportProgress.fractionCompleted)
                }
            }
        }

        defer {
            progressTask.cancel()
            activeSession = nil
        }

        do {
            #if compiler(>=6.2)
            try await session.export(to: outputURL, as: .mp4)
            #else
            try await exportLegacy(session, to: outputURL)
            #endif

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
        // Modern SDKs cancel through the Task that is awaiting export. Older
        // toolchains need the explicit AVAssetExportSession cancellation API.
        #if compiler(<6.2)
        activeSession?.cancelExport()
        #endif
    }

    private func makeSession(for asset: AVAsset, rendersVideo: Bool) throws -> AVAssetExportSession {
        let presets = rendersVideo ? [AVAssetExportPresetHighestQuality] : [AVAssetExportPresetPassthrough, AVAssetExportPresetHighestQuality]

        for preset in presets {
            if let session = AVAssetExportSession(asset: asset, presetName: preset),
               session.supportedFileTypes.contains(.mp4) {
                return session
            }
        }

        throw VideoExportError.unsupportedMP4Export
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

    #if compiler(<6.2)
    private func exportLegacy(_ session: AVAssetExportSession, to outputURL: URL) async throws {
        try Task.checkCancellation()
        session.outputURL = outputURL
        session.outputFileType = .mp4

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                case .failed:
                    continuation.resume(
                        throwing: VideoExportError.failed(
                            session.error?.localizedDescription ?? "Unknown export failure."
                        )
                    )
                default:
                    continuation.resume(throwing: VideoExportError.incomplete)
                }
            }
        }
    }
    #endif
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
