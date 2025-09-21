import SwiftUI

// MARK: - Modern Button Styles

struct ModernButtonStyle: ButtonStyle {
    let color: Color
    let isProminent: Bool
    
    init(color: Color = .accentColor, isProminent: Bool = false) {
        self.color = color
        self.isProminent = isProminent
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundFill(configuration))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(strokeColor(configuration), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private func backgroundFill(_ configuration: Configuration) -> some ShapeStyle {
        if isProminent {
            return AnyShapeStyle(color.opacity(configuration.isPressed ? 0.8 : 1.0))
        } else {
            return AnyShapeStyle(color.opacity(configuration.isPressed ? 0.2 : 0.1))
        }
    }
    
    private func strokeColor(_ configuration: Configuration) -> Color {
        if isProminent {
            return color.opacity(0.3)
        } else {
            return color.opacity(configuration.isPressed ? 0.4 : 0.2)
        }
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.8 : 1.0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ToggleButtonStyle: ButtonStyle {
    let isActive: Bool
    let color: Color
    
    init(isActive: Bool, color: Color = .accentColor) {
        self.isActive = isActive
        self.color = color
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .rounded, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundFill(configuration))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(strokeColor(configuration), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private func backgroundFill(_ configuration: Configuration) -> Color {
        if isActive {
            return color.opacity(configuration.isPressed ? 0.8 : 1.0)
        } else {
            return Color(.controlBackgroundColor).opacity(configuration.isPressed ? 0.8 : 1.0)
        }
    }
    
    private func strokeColor(_ configuration: Configuration) -> Color {
        if isActive {
            return color.opacity(0.3)
        } else {
            return Color(.separatorColor)
        }
    }
}

struct CircularButtonStyle: ButtonStyle {
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 32, color: Color = Color(.controlAccentColor)) {
        self.size = size
        self.color = color
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.4, weight: .medium))
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(color.opacity(configuration.isPressed ? 0.7 : 1.0))
                    .overlay(
                        Circle()
                            .strokeBorder(color.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SourceSelectionButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.caption, design: .rounded, weight: .medium))
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundFill(configuration))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(strokeColor(configuration), lineWidth: 1.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private func backgroundFill(_ configuration: Configuration) -> Color {
        if isSelected {
            return Color.accentColor.opacity(configuration.isPressed ? 0.7 : 0.8)
        } else {
            return Color(.controlBackgroundColor).opacity(configuration.isPressed ? 0.7 : 1.0)
        }
    }
    
    private func strokeColor(_ configuration: Configuration) -> Color {
        if isSelected {
            return Color.accentColor
        } else {
            return Color(.separatorColor)
        }
    }
}