import AppKit
import CoreMedia
import ScreenCaptureKit
import SwiftUI

enum RecordingSourceLoader {
    static func loadDisplays() async throws -> [SCDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.displays
    }

    static func loadUserWindows() async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return RecordingSourceFilter.userRecordableWindows(from: content.windows)
    }
}

enum RecordingSourceThumbnailProvider {
    static func captureThumbnail(for window: SCWindow) async throws -> NSImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let scale = scaleFactor(for: window)
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        return NSImage(cgImage: cgImage, size: window.frame.size)
    }

    static func captureDisplayPreview(for display: SCDisplay, maxPreviewWidth: Int = 300) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        let aspectRatio = Double(display.height) / Double(display.width)
        config.width = maxPreviewWidth
        config.height = Int(Double(maxPreviewWidth) * aspectRatio)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.pixelFormat = kCVPixelFormatType_32BGRA

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }

    private static func scaleFactor(for window: SCWindow) -> CGFloat {
        let windowOrigin = CGPoint(x: window.frame.minX, y: window.frame.minY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(windowOrigin) }) {
            return screen.backingScaleFactor
        }
        return NSScreen.main?.backingScaleFactor ?? 1.0
    }
}
