//
//  SourcePickerView.swift
//  recordme
//
//  Display and window choosers presented as a sheet. They render whatever
//  sources/thumbnails the host view has loaded and report the chosen source back
//  through callbacks, keeping all capture/permission state in ContentView.
//

import SwiftUI
import ScreenCaptureKit
import AppKit

// MARK: - Display picker

struct DisplayPickerView: View {
    let displays: [SCDisplay]
    let previews: [CGDirectDisplayID: CGImage]
    let onSelect: (SCDisplay) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PickerHeader(title: "Choose a Display", subtitle: "Pick a screen to record.", onClose: onClose)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                    ForEach(displays, id: \.displayID) { display in
                        SourceCard { onSelect(display) } content: {
                            SourceThumbnail(aspectRatio: thumbnailAspect(for: display)) {
                                if let preview = previews[display.displayID] {
                                    Image(preview, scale: 1.0, label: Text("Display preview"))
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    ProgressView().controlSize(.small)
                                }
                            }
                            SourceCaption(
                                title: "Display \(display.displayID)",
                                detail: "\(display.width) × \(display.height)"
                            )
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 580, minHeight: 480)
        .background(Color(.windowBackgroundColor))
    }

    private func thumbnailAspect(for display: SCDisplay) -> CGFloat {
        guard display.height > 0 else { return 16.0 / 9.0 }
        return CGFloat(display.width) / CGFloat(display.height)
    }
}

// MARK: - Window picker

struct WindowPickerView: View {
    let windows: [SCWindow]
    let thumbnails: [CGWindowID: NSImage]
    let onSelect: (SCWindow) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PickerHeader(title: "Choose a Window", subtitle: "Pick an open window to record.", onClose: onClose)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    ForEach(windows, id: \.windowID) { window in
                        SourceCard { onSelect(window) } content: {
                            SourceThumbnail(aspectRatio: 16.0 / 10.0) {
                                if let thumbnail = thumbnails[window.windowID] {
                                    Image(nsImage: thumbnail)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } else {
                                    ProgressView().controlSize(.small)
                                }
                            }
                            SourceCaption(
                                title: window.title?.isEmpty == false ? window.title! : "Untitled",
                                detail: window.owningApplication?.applicationName
                            )
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 620, minHeight: 500)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Shared pieces

/// Sheet header with a title, hint, and a native close button (Escape dismisses).
private struct PickerHeader: View {
    let title: String
    let subtitle: String
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Close")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.bar)
    }
}

/// A selectable card with a hover highlight and accent border on hover.
private struct SourceCard<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                    .fill(Color(.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                    .strokeBorder(hovering ? Color.accentColor : Color(.separatorColor),
                                  lineWidth: hovering ? 2 : 1)
            )
            .shadow(color: .black.opacity(hovering ? 0.18 : 0), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .scaleEffect(hovering ? 1.02 : 1)
        .animation(.easeInOut(duration: 0.12), value: hovering)
        .onHover { hovering = $0 }
    }
}

/// Fixed-aspect thumbnail well with a dark backdrop.
private struct SourceThumbnail<Content: View>: View {
    var aspectRatio: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.black.opacity(0.85))
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                content()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SourceCaption: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
