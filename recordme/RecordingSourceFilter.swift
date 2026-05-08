import CoreGraphics
import ScreenCaptureKit

enum RecordingSourceFilter {
    struct WindowInfo {
        let applicationName: String
        let bundleIdentifier: String
        let title: String?
        let width: CGFloat
        let height: CGFloat
    }

    private static let systemApplicationNames: Set<String> = [
        "Control Center",
        "Dock",
        "Notification Center",
        "SystemUIServer",
        "Window Server",
        "Spotlight",
        "Finder",
        "MenuBar",
        "MenuItem",
        "StatusItem",
        "ControlCenter",
        "NotificationCenter",
        "Siri",
        "MenuBarExtra",
        "StatusBarApp",
        "StatusIndicator",
        ""
    ]

    private static let systemTitleFragments = [
        "Menu Bar",
        "StatusBar",
        "MenuBar",
        "Status indicator",
        "Item-0",
        "Item-",
        "Desktop",
        "Wallpaper",
        "Display 1 Backstop",
        "underbelly"
    ]

    private static let systemBundlePatterns = [
        "com.apple.controlcenter",
        "com.apple.systemuiserver",
        "com.apple.dock",
        "com.apple.notificationcenter",
        "com.apple.spotlight",
        "com.apple.menubar"
    ]

    static func isUserRecordableWindow(_ window: WindowInfo) -> Bool {
        guard !systemApplicationNames.contains(window.applicationName) else {
            return false
        }

        guard let title = window.title, !title.isEmpty else {
            return false
        }

        if systemTitleFragments.contains(where: { title.contains($0) || title.starts(with: $0) }) {
            return false
        }

        guard window.width >= 50, window.height >= 50 else {
            return false
        }

        return !systemBundlePatterns.contains { window.bundleIdentifier.contains($0) }
    }

    static func userRecordableWindows(from windows: [SCWindow]) -> [SCWindow] {
        windows.filter { window in
            guard let app = window.owningApplication else {
                return false
            }

            return isUserRecordableWindow(
                WindowInfo(
                    applicationName: app.applicationName,
                    bundleIdentifier: app.bundleIdentifier,
                    title: window.title,
                    width: window.frame.width,
                    height: window.frame.height
                )
            )
        }
    }
}
