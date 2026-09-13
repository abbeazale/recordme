import AVFoundation
import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let recordmeProject = UTType(exportedAs: "abbe.ca.recordme.project", conformingTo: .package)
}

struct ProjectTrim: Codable, Equatable, Sendable {
    let start: Double
    let end: Double
    var timeRange: CMTimeRange {
        CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 60_000),
                    end: CMTime(seconds: end, preferredTimescale: 60_000))
    }
}

struct RecordingEdits: Codable, Equatable, Sendable {
    var trim: ProjectTrim?
    var canvas = CanvasStyle()
    var export = ExportSettings()
    var cursorEffects = CursorEffectsSettings()
}

struct RecordingProject: Codable, Equatable, Sendable {
    var version = 1
    let mediaFilename: String
    let edits: RecordingEdits
    let cursor: CursorRecording

    func validate() throws {
        guard version == 1 else { throw ProjectError.unsupportedVersion }
        guard mediaFilename == (mediaFilename as NSString).lastPathComponent,
              mediaFilename.hasPrefix("recording."), !mediaFilename.contains("/"), !mediaFilename.contains("\\"),
              edits.canvas.padding.isFinite, (0...0.2).contains(edits.canvas.padding),
              edits.canvas.cornerRadius.isFinite, (0...0.15).contains(edits.canvas.cornerRadius),
              edits.cursorEffects.zoomAmount.isFinite, (1.2...2.5).contains(edits.cursorEffects.zoomAmount) else {
            throw ProjectError.invalidData
        }
        if let trim = edits.trim {
            guard trim.start.isFinite, trim.end.isFinite, trim.start >= 0, trim.end > trim.start else {
                throw ProjectError.invalidData
            }
        }
        try cursor.validate()
    }
}

/// Retains access while the editor reads an imported movie or project package.
final class ScopedMediaAccess {
    let url: URL
    private let started: Bool
    init(url: URL) {
        self.url = url
        started = url.startAccessingSecurityScopedResource()
    }
    deinit { if started { url.stopAccessingSecurityScopedResource() } }
}

struct EditorSource {
    let id = UUID()
    let mediaURL: URL
    let projectURL: URL?
    let project: RecordingProject?
    let access: ScopedMediaAccess

    static func open(_ url: URL) throws -> EditorSource {
        let access = ScopedMediaAccess(url: url)
        if url.pathExtension.lowercased() == "recordme" {
            let project = try RecordingProjectStore.load(from: url)
            return EditorSource(mediaURL: url.appendingPathComponent(project.mediaFilename),
                                projectURL: url, project: project, access: access)
        }
        return EditorSource(mediaURL: url, projectURL: nil, project: nil, access: access)
    }
}

enum RecordingProjectStore {
    static func load(from url: URL) throws -> RecordingProject {
        let root = url.resolvingSymlinksInPath().standardizedFileURL
        let manifest = root.appendingPathComponent("project.json")
        guard manifest.resolvingSymlinksInPath().deletingLastPathComponent().path == root.path else { throw ProjectError.invalidData }
        let size = try manifest.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size < 5_000_000 else { throw ProjectError.invalidData }
        let project = try JSONDecoder().decode(RecordingProject.self, from: Data(contentsOf: manifest))
        try project.validate()
        let media = root.appendingPathComponent(project.mediaFilename).resolvingSymlinksInPath()
        guard media.deletingLastPathComponent().path == root.path,
              try media.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw ProjectError.missingMedia
        }
        return project
    }

    static func save(sourceURL: URL, destination: URL, edits: RecordingEdits, cursor: CursorRecording) throws {
        let fileManager = FileManager.default
        let replacementDirectory = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                        appropriateFor: destination, create: true)
        defer { try? fileManager.removeItem(at: replacementDirectory) }
        let staging = replacementDirectory.appendingPathComponent("Project.recordme", isDirectory: true)
        let suffix = sourceURL.pathExtension.lowercased()
        guard !suffix.isEmpty, suffix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
            throw ProjectError.invalidData
        }
        let project = RecordingProject(mediaFilename: "recording.\(suffix)", edits: edits, cursor: cursor)
        try project.validate()
        // Stage the media copy before replacing a previously saved project.
        let sourcePath = sourceURL.resolvingSymlinksInPath().path
        let destinationPath = destination.resolvingSymlinksInPath().path
        if sourcePath == destinationPath { throw ProjectError.invalidData }
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: staging) }
        try fileManager.copyItem(at: sourceURL, to: staging.appendingPathComponent(project.mediaFilename))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(project).write(to: staging.appendingPathComponent("project.json"), options: .atomic)
        if fileManager.fileExists(atPath: destination.path) {
            // Only replace a valid RecordMe project, never an unrelated folder.
            _ = try load(from: destination)
            _ = try fileManager.replaceItemAt(destination, withItemAt: staging)
        } else {
            try fileManager.moveItem(at: staging, to: destination)
        }
    }
}

enum ProjectError: LocalizedError {
    case unsupportedVersion, invalidData, missingMedia
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "This project was saved by an unsupported version of RecordMe."
        case .invalidData: return "This file is not a valid RecordMe project."
        case .missingMedia: return "The project's source video is missing."
        }
    }
}
