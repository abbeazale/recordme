//
//  DesignSystem.swift
//  recordme
//
//  Shared visual tokens and small reusable native controls used across the app.
//  Keeping these in one place lets every view share the same radii, spacing, and
//  toggle/record affordances instead of re-deriving them inline.
//

import SwiftUI

// MARK: - Metrics

enum AppMetrics {
    /// Radius for standard cards and source thumbnails.
    static let cardRadius: CGFloat = 12
    /// Radius for the hero preview stage.
    static let stageRadius: CGFloat = 16

    /// Horizontal inset for the header and control bars.
    static let barHPadding: CGFloat = 16
    /// Vertical inset for the header and control bars.
    static let barVPadding: CGFloat = 12
    /// Left inset that keeps header content clear of the window traffic lights.
    static let trafficLightInset: CGFloat = 78
}

// MARK: - Recording status

/// A pulsing red dot — the standard "live" affordance used in capture UIs.
struct PulsingRecordingDot: View {
    var diameter: CGFloat = 9
    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: diameter, height: diameter)
            .opacity(dimmed ? 0.3 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: dimmed)
            .onAppear { dimmed = true }
            .accessibilityHidden(true)
    }
}

/// Live "● 00:34" recording indicator. Updates once per second via `TimelineView`
/// so there is no manually managed timer to leak.
struct RecordingStatusView: View {
    let startDate: Date

    var body: some View {
        TimelineView(.periodic(from: startDate, by: 1)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startDate))
            HStack(spacing: 7) {
                PulsingRecordingDot()
                Text(Self.format(elapsed))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Recording, \(Self.format(elapsed))")
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Capture toggle

/// A native toggle-button (the same control macOS uses for toolbar toggles).
/// Fills with `tint` when on, bordered when off.
struct CaptureToggle: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    var tint: Color = .accentColor
    var isEnabled: Bool = true
    var help: String
    let action: () -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: { _ in action() })) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.callout.weight(.medium))
                .fixedSize()
        }
        .toggleStyle(.button)
        .tint(tint)
        .controlSize(.large)
        .disabled(!isEnabled)
        .help(help)
    }
}
