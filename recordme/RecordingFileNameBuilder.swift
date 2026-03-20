import Foundation

enum RecordingFileNameBuilder {
    private static let formatter = ISO8601DateFormatter()

    static func makeFilename(date: Date = Date()) -> String {
        let raw = "ScreenRecording-\(formatter.string(from: date)).mp4"
        return raw
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }
}
