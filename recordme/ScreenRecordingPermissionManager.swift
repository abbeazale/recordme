//
//  ScreenRecordingPermissionManager.swift
//  recordme
//
//  Created by abbe on 2025-09-26.
//

import SwiftUI
import ScreenCaptureKit
import os.log

@MainActor
class ScreenRecordingPermissionManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ScreenRecordingPermissions")
    
    enum AuthorizationStatus {
        case notDetermined
        case denied
        case authorized
        case checking
    }
    
    init() {
        checkAuthorizationStatus()
    }
    
    /// Check current screen recording authorization status
    func checkAuthorizationStatus() {
        Task {
            do {
                // Try to get shareable content to check permissions
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                
                // If we successfully get content and have displays/windows, we have permission
                if !content.displays.isEmpty || !content.windows.isEmpty {
                    await MainActor.run {
                        self.isAuthorized = true
                        self.authorizationStatus = .authorized
                        self.logger.info("Screen recording authorized - found \(content.displays.count) displays and \(content.windows.count) windows")
                    }
                } else {
                    // No content available might mean no permission
                    await MainActor.run {
                        self.isAuthorized = false
                        self.authorizationStatus = .denied
                        self.logger.warning("No shareable content available - permission likely denied")
                    }
                }
            } catch {
                // Error getting content likely means no permission
                await MainActor.run {
                    self.isAuthorized = false
                    self.authorizationStatus = .denied
                    self.logger.error("Failed to get shareable content: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Request screen recording permission by attempting to get shareable content
    func requestPermission() async {
        await MainActor.run {
            self.authorizationStatus = .checking
        }
        
        do {
            // This will trigger the system permission dialog if needed
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            await MainActor.run {
                if !content.displays.isEmpty || !content.windows.isEmpty {
                    self.isAuthorized = true
                    self.authorizationStatus = .authorized
                    self.logger.info("Permission granted - found \(content.displays.count) displays and \(content.windows.count) windows")
                } else {
                    self.isAuthorized = false
                    self.authorizationStatus = .denied
                    self.logger.warning("Permission granted but no content available")
                }
            }
        } catch {
            await MainActor.run {
                self.isAuthorized = false
                self.authorizationStatus = .denied
                self.logger.error("Permission request failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Open System Preferences to screen recording settings
    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}