//
//  recordmeTests.swift
//  recordmeTests
//
//  Created by abbe on 2025-04-10.
//

import Foundation
import Testing
@testable import recordme

struct recordmeTests {

    @Test func recordingFilenameIsSanitizedAndStable() {
        let date = Date(timeIntervalSince1970: 1_735_778_765)
        let filename = RecordingFileNameBuilder.makeFilename(date: date)

        #expect(filename.hasPrefix("ScreenRecording-"))
        #expect(filename.hasSuffix(".mp4"))
        #expect(!filename.contains(":"))
        #expect(!filename.contains("/"))
    }

    @MainActor
    @Test func stopWithoutRecordingThrowsNotRecording() async {
        let manager = RecordingManager()

        do {
            try await manager.stop()
            Issue.record("Expected stop() to throw when recording has not started.")
        } catch let error as RecordingManager.RecordingError {
            switch error {
            case .notRecording:
                return
            default:
                Issue.record("Unexpected RecordingError: \(String(describing: error.errorDescription))")
            }
        } catch {
            Issue.record("Unexpected non-RecordingError: \(error.localizedDescription)")
        }
    }

    @Test func recordingErrorDescriptionIncludesMessage() {
        let error = RecordingManager.RecordingError.writerFailed("disk full")
        #expect(error.errorDescription == "Writer failed: disk full")
    }

    @Test func sourceFilterKeepsNormalUserWindow() {
        let window = RecordingSourceFilter.WindowInfo(
            applicationName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            title: "Project Notes",
            width: 1_200,
            height: 800
        )

        #expect(RecordingSourceFilter.isUserRecordableWindow(window))
    }

    @Test func sourceFilterRejectsSystemAndTinyWindows() {
        let controlCenter = RecordingSourceFilter.WindowInfo(
            applicationName: "Control Center",
            bundleIdentifier: "com.apple.controlcenter",
            title: "Control Center",
            width: 320,
            height: 480
        )
        let menuItem = RecordingSourceFilter.WindowInfo(
            applicationName: "Example",
            bundleIdentifier: "com.example.app",
            title: "Menu Bar",
            width: 400,
            height: 40
        )
        let tinyWindow = RecordingSourceFilter.WindowInfo(
            applicationName: "Example",
            bundleIdentifier: "com.example.app",
            title: "Palette",
            width: 20,
            height: 20
        )

        #expect(!RecordingSourceFilter.isUserRecordableWindow(controlCenter))
        #expect(!RecordingSourceFilter.isUserRecordableWindow(menuItem))
        #expect(!RecordingSourceFilter.isUserRecordableWindow(tinyWindow))
    }

}
