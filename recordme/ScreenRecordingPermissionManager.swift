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
                
                await MainActor.run {
                    self.logger.info("Permission check - Displays: \(content.displays.count), Windows: \(content.windows.count)")
                    
                    // If we successfully got content, we have permission (even if no displays/windows)
                    // This can happen if all windows are filtered out but permission is granted
                    self.isAuthorized = true
                    self.authorizationStatus = .authorized
                    self.logger.info("Screen recording authorized - API call succeeded")
                }
            } catch {
                await MainActor.run {
                    self.logger.error("Permission check failed: \(error.localizedDescription)")
                    print("❌ Screen recording permission check error: \(error)")
                    
                    // Check if this is a permission-related error
                    let errorDescription = error.localizedDescription.lowercased()
                    if errorDescription.contains("permission") || errorDescription.contains("denied") || 
                       errorDescription.contains("unauthorized") || errorDescription.contains("tcc") ||
                       errorDescription.contains("declined") {
                        self.isAuthorized = false
                        self.authorizationStatus = .denied
                        self.logger.error("TCC permission denied - user needs to grant permission in System Preferences")
                    } else {
                        // For other errors, assume we might have permission but there's another issue
                        self.isAuthorized = false
                        self.authorizationStatus = .notDetermined
                    }
                }
            }
        }
    }
    
    /// Request screen recording permission by attempting to get shareable content
    func requestPermission() async {
        await MainActor.run {
            self.authorizationStatus = .checking
            print("🔄 Requesting screen recording permission...")
        }
        
        do {
            // This will trigger the system permission dialog if needed
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            await MainActor.run {
                print("✅ Permission request succeeded - Displays: \(content.displays.count), Windows: \(content.windows.count)")
                
                // If the API call succeeded, we have permission
                self.isAuthorized = true
                self.authorizationStatus = .authorized
                self.logger.info("Permission granted - API call succeeded")
            }
        } catch {
            await MainActor.run {
                print("❌ Permission request failed: \(error)")
                self.logger.error("Permission request failed: \(error.localizedDescription)")
                
                // Check if this is specifically a permission denial
                let errorDescription = error.localizedDescription.lowercased()
                if errorDescription.contains("permission") || errorDescription.contains("denied") || 
                   errorDescription.contains("unauthorized") || errorDescription.contains("tcc") ||
                   errorDescription.contains("declined") {
                    self.isAuthorized = false
                    self.authorizationStatus = .denied
                    self.logger.error("TCC permission denied during request - user needs to grant permission")
                } else {
                    // For other errors, set to not determined so user can try again
                    self.isAuthorized = false
                    self.authorizationStatus = .notDetermined
                }
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