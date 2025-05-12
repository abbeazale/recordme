//
//  ContentView.swift
//  recordme
//
//  Created by abbe on 2025-04-10.
//

import SwiftUI
import ScreenCaptureKit
import AVFoundation

struct ContentView: View {
    @StateObject private var recorder = RecordingManager()
    @State private var showPicker = false
    @State private var selectedFilter: SCContentFilter?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("Screen Recorder")
                .font(.largeTitle.weight(.semibold))
                .padding(.top)

            preview
                .frame(width: 400, height: 225)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))

            Toggle(isOn: $recorder.captureMicrophone) {
                Text("Capture Microphone Audio")
            }
            .padding(.horizontal, 50)
            .disabled(recorder.isRecording)
            HStack {
                Button(action: primaryButtonTapped) {
                    Text(buttonText)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(buttonColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.bottom, 32)
                if selectedFilter != nil {
                        Button(action: {
                            selectedFilter = nil
                            showPicker = true
                        }) {
                            Text("Change Source")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                        }
                        .padding(.bottom, 32)
                    }
            }
        }
        .frame(minWidth: 500)
        .sheet(isPresented: $showPicker) {
            SourcePickerView { filter in
                selectedFilter = filter
                showPicker = false
                
                // Start preview when source is selected
                Task {
                    do {
                        try await recorder.stopPreview()  // Stop existing preview first
                        try await recorder.startPreview(filter: filter)
                    } catch {
                        errorMessage = "Failed to start preview: \(error.localizedDescription)"
                        print("Preview start error: \(error)")
                    }
                }
            }
        }
        // Simple error alert
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onDisappear {
            // Stop preview when view disappears
            Task {
                await recorder.stopPreview()
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let img = recorder.previewImage {
            Image(img, scale: 1.0, label: Text("Preview"))
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.25))
                .overlay(Text("Live Preview").foregroundColor(.white))
        }
    }

    // Computed properties for button appearance
    private var buttonText: String {
        if recorder.isRecording {
            return "Stop Recording"
        } else if selectedFilter == nil {
            return "Select Source"
        } else {
            return "Start Recording"
        }
    }
    
    //sets button colour
    private var buttonColor: Color {
        if recorder.isRecording {
            return .red
        } else if selectedFilter == nil {
            return .blue
        } else {
            return .green
        }
    }
    

    //function of the button
    private func primaryButtonTapped() {
        if selectedFilter == nil {
            showPicker = true
            return
        }

        if recorder.isRecording {
            Task {
                do {
                    try await recorder.stop()
                } catch {
                    errorMessage = "Failed to save recording: \(error.localizedDescription)"
                    print("Recording stop error: \(error)")
                }
            }
        } else {
            Task {
                do {
                    let downloads = FileManager.default.urls(for: .downloadsDirectory,
                                                             in: .userDomainMask).first!
                    let filename  = "ScreenRecording-\(ISO8601DateFormatter().string(from: Date())).mov"
                    let sanitizedFilename = filename.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") // e.g., "ScreenRecording-2025-04-23T01-14-46Z.mov"


                    let url       = downloads.appendingPathComponent(sanitizedFilename)
                    try await recorder.start(filter: selectedFilter!, saveURL: url)
                } catch {
                    errorMessage = "Failed to start recording: \(error.localizedDescription)"
                    print("Recording start error: \(error)")
                }
            }
        }
    }
}
