import AppKit
import SwiftUI

struct VideoEditorView: View {
    @StateObject private var model: VideoEditorModel
    @State private var exportTask: Task<Void, Never>?
    @State private var showExportSettings = false
    @State private var showCursorEffects = false

    let onSaved: (URL) -> Void
    let onClose: () -> Void

    init(sourceURL: URL, onSaved: @escaping (URL) -> Void, onClose: @escaping () -> Void) {
        _model = StateObject(wrappedValue: VideoEditorModel(sourceURL: sourceURL))
        self.onSaved = onSaved
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(spacing: 0) {
                TrimmingPlayerView(model: model)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.stageRadius))
                    .padding(20)
                Divider()
                CanvasStyleControls(style: $model.canvasStyle)
                    .disabled(model.isExporting)
            }

            Divider()
            editorControls
        }
        .background(Color(.windowBackgroundColor))
        .alert("Couldn't Edit Recording", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onChange(of: model.cursorEffects) { model.updateComposition() }
        .onChange(of: model.canvasStyle) { model.updateComposition() }
        .onDisappear {
            exportTask?.cancel()
            model.cancelExport()
            model.pause()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Label("New Recording", systemImage: "chevron.backward")
            }
            .buttonStyle(.borderless)
            .disabled(model.isExporting)

            VStack(alignment: .leading, spacing: 1) {
                Text("Edit Recording")
                    .font(.headline)
                Text(model.sourceURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button("Show Original in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([model.sourceURL])
            }
            .buttonStyle(.link)
            .disabled(model.isExporting)
        }
        .padding(.leading, AppMetrics.trafficLightInset)
        .padding(.trailing, AppMetrics.barHPadding)
        .padding(.vertical, AppMetrics.barVPadding)
        .background(.bar)
    }

    private var editorControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    model.beginTrimming()
                } label: {
                    Label("Trim…", systemImage: "scissors")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!model.canTrim || model.isExporting)
                .help("Choose the beginning and end using the native video trim controls")

                if let trimDescription = model.trimDescription {
                    Text(trimDescription)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Button("Reset") {
                        model.resetTrim()
                    }
                    .buttonStyle(.link)
                    .disabled(model.isExporting)
                } else {
                    Text("Trim or style your recording, then save a copy.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showCursorEffects = true
                } label: {
                    Image(systemName: "cursorarrow.rays")
                }
                .help("Cursor effects")
                .disabled(model.isExporting)
                .popover(isPresented: $showCursorEffects) {
                    CursorEffectsControls(settings: $model.cursorEffects, eventCount: model.cursorRecording.events.count)
                }
                Spacer(minLength: 16)
                Button {
                    showExportSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .help("Export settings")
                .disabled(model.isExporting)
                .popover(isPresented: $showExportSettings) {
                    ExportSettingsControls(settings: $model.exportSettings)
                }


                if model.isExporting {
                    Button("Cancel Export", role: .cancel) {
                        exportTask?.cancel()
                        model.cancelExport()
                    }
                    .controlSize(.large)
                } else {
                    Button {
                        startExport()
                    } label: {
                        Label("Save Edited Copy", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!model.canExport)
                }
            }

            if model.isExporting {
                HStack(spacing: 10) {
                    ProgressView(value: model.exportProgress)
                    Text(model.exportProgress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, AppMetrics.barHPadding)
        .padding(.vertical, AppMetrics.barVPadding)
        .background(.bar)
        .animation(.easeInOut(duration: 0.2), value: model.isExporting)
    }

    private func startExport() {
        guard exportTask == nil else { return }

        exportTask = Task { @MainActor in
            defer { exportTask = nil }
            if let outputURL = await model.exportEditedCopy() {
                onSaved(outputURL)
            }
        }
    }
}
