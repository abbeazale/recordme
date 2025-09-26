//
//  DebugPermissionTest.swift
//  recordme
//
//  Created by abbe on 2025-09-26.
//

import SwiftUI
import ScreenCaptureKit

struct DebugPermissionView: View {
    @State private var testResults: [String] = []
    @State private var isRunning = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Screen Recording Permission Debug")
                .font(.title)
                .padding()
            
            Button("Run Permission Tests") {
                Task {
                    await runTests()
                }
            }
            .disabled(isRunning)
            
            if isRunning {
                ProgressView("Running tests...")
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(testResults, id: \.self) { result in
                        Text(result)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
                .padding()
            }
            .frame(height: 300)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private func addResult(_ message: String) {
        DispatchQueue.main.async {
            testResults.append(message)
        }
    }
    
    private func runTests() async {
        isRunning = true
        testResults = []
        
        addResult("🧪 Starting permission tests...")
        
        // Test 1: Try to get shareable content
        addResult("\n📺 Test 1: Getting shareable content...")
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            addResult("✅ SUCCESS: Got shareable content")
            addResult("📊 Displays: \(content.displays.count)")
            addResult("🪟 Windows: \(content.windows.count)")
            
            for (index, display) in content.displays.enumerated() {
                addResult("   Display \(index): ID=\(display.displayID), Size=\(display.width)x\(display.height)")
            }
            
            addResult("🔍 First 5 windows:")
            for (index, window) in content.windows.prefix(5).enumerated() {
                let appName = window.owningApplication?.applicationName ?? "Unknown"
                let title = window.title ?? "No title"
                addResult("   Window \(index): \(appName) - \(title)")
            }
            
        } catch {
            addResult("❌ FAILED: \(error)")
            addResult("📋 Error details: \(error.localizedDescription)")
        }
        
        // Test 2: Try to capture a screenshot
        addResult("\n📸 Test 2: Attempting screenshot capture...")
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            if let firstDisplay = content.displays.first {
                let filter = SCContentFilter(display: firstDisplay, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = 100
                config.height = 100
                config.pixelFormat = kCVPixelFormatType_32BGRA
                
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                addResult("✅ SUCCESS: Screenshot captured \(image.width)x\(image.height)")
            } else {
                addResult("⚠️ No displays available for screenshot")
            }
        } catch {
            addResult("❌ SCREENSHOT FAILED: \(error)")
        }
        
        addResult("\n🏁 Tests completed!")
        isRunning = false
    }
}