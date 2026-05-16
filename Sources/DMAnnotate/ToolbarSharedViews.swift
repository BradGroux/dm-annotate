import AppKit
import DMAnnotateCore
import SwiftUI

struct ToolbarIcon: View {
    var systemName: String

    init(_ systemName: String) {
        self.systemName = systemName
    }

    var body: some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 16, weight: .medium))
            .frame(width: ToolbarLayoutMetrics.buttonSize, height: ToolbarLayoutMetrics.buttonSize)
    }
}

struct ToolbarIconButton: View {
    var systemName: String
    var active: Bool
    var enabled = true
    var highContrast: Bool
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ToolbarIcon(systemName)
        }
        .buttonStyle(ToolbarIconButtonStyle(active: active, highContrast: highContrast))
        .disabled(!enabled)
        .toolbarHelp(help)
        .accessibilityLabel(help)
    }
}

struct ToolbarIconButtonStyle: ButtonStyle {
    var active: Bool
    var highContrast: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(active ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fillColor(isPressed: configuration.isPressed))
            )
    }

    private func fillColor(isPressed: Bool) -> Color {
        if active {
            return .accentColor
        }
        if highContrast {
            return Color.primary.opacity(isPressed ? 0.24 : 0.14)
        }
        return Color.white.opacity(isPressed ? 0.14 : 0.07)
    }
}

struct ToolbarTooltipModifier: ViewModifier {
    @Environment(\.toolbarTooltipsEnabled) private var tooltipsEnabled

    let text: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if tooltipsEnabled {
            content
                .help(text)
                .accessibilityHint(text)
                .onHover { isHovering in
                    if isHovering {
                        ToolbarTooltipController.shared.show(text, near: NSEvent.mouseLocation)
                    } else {
                        ToolbarTooltipController.shared.hide()
                    }
                }
        } else {
            content
                .accessibilityHint(text)
                .onHover { isHovering in
                    if !isHovering {
                        ToolbarTooltipController.shared.hide()
                    }
                }
        }
    }
}

struct ToolbarTooltipsEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var toolbarTooltipsEnabled: Bool {
        get { self[ToolbarTooltipsEnabledKey.self] }
        set { self[ToolbarTooltipsEnabledKey.self] = newValue }
    }
}

extension View {
    func toolbarHelp(_ text: String) -> some View {
        modifier(ToolbarTooltipModifier(text: text))
    }
}

extension Color {
    init(_ color: RGBAColor) {
        self.init(
            red: color.red,
            green: color.green,
            blue: color.blue,
            opacity: color.alpha
        )
    }
}

extension RGBAColor {
    init(_ color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            alpha: Double(nsColor.alphaComponent)
        )
    }
}
