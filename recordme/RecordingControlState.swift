import Foundation

struct CameraControlState: Equatable {
    let icon: String
    let title: String
    let help: String
    let isActive: Bool
    let isEnabled: Bool

    static func make(hasCamera: Bool, isAuthorized: Bool, showCamera: Bool, isCapturing: Bool) -> CameraControlState {
        guard hasCamera else {
            return CameraControlState(
                icon: "video.slash",
                title: "No camera",
                help: "No camera available",
                isActive: false,
                isEnabled: false
            )
        }

        if showCamera && isCapturing {
            return CameraControlState(
                icon: "video.fill",
                title: "Camera",
                help: "Hide camera overlay",
                isActive: true,
                isEnabled: true
            )
        }

        if showCamera && !isAuthorized {
            return CameraControlState(
                icon: "video.badge.exclamationmark",
                title: "Camera access",
                help: "Camera access required",
                isActive: false,
                isEnabled: true
            )
        }

        return CameraControlState(
            icon: "video.slash",
            title: "No camera",
            help: isAuthorized ? (showCamera ? "Hide camera overlay" : "Show camera overlay") : "Camera access required",
            isActive: false,
            isEnabled: true
        )
    }
}

struct AudioControlState: Equatable {
    let usesWhiteForeground: Bool
    let usesProminentBackground: Bool

    static func make(isActive: Bool, isProminent: Bool) -> AudioControlState {
        AudioControlState(
            usesWhiteForeground: isProminent && isActive,
            usesProminentBackground: isProminent && isActive
        )
    }
}

struct RecordingButtonState: Equatable {
    let title: String
    let icon: String?
    let isEnabled: Bool
    let isRecording: Bool

    static func make(isRecording: Bool, hasSelectedSource: Bool) -> RecordingButtonState {
        RecordingButtonState(
            title: isRecording ? "Stop Recording" : "Start Recording",
            icon: isRecording ? nil : "record.circle",
            isEnabled: isRecording || hasSelectedSource,
            isRecording: isRecording
        )
    }
}
