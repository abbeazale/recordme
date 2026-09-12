import Foundation

enum RecordingFileNameBuilder {
    private static let formatter = ISO8601DateFormatter()

    static func makeFilename(date: Date = Date()) -> String {
        let raw = "ScreenRecording-\(formatter.string(from: date)).mp4"
        return raw
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    static func makeAvailableURL(
        in directory: URL,
        date: Date = Date(),
        fileManager: FileManager = .default
    ) -> URL {
        let filename = makeFilename(date: date)
        let basename = (filename as NSString).deletingPathExtension

        for suffix in 1...10_000 {
            let candidateName = suffix == 1 ? filename : "\(basename)-\(suffix).mp4"
            let candidate = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return directory.appendingPathComponent("\(basename)-\(UUID().uuidString).mp4")
    }
}
