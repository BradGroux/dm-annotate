import AppKit
import SwiftUI

enum AdaptiveSelectedControlContrast {
    enum Foreground: Equatable {
        case black
        case white

        var nsColor: NSColor {
            switch self {
            case .black: .black
            case .white: .white
            }
        }
    }

    static let minimumRatio = 4.5

    static func foreground(red: Double, green: Double, blue: Double) -> Foreground {
        let backgroundLuminance = relativeLuminance(red: red, green: green, blue: blue)
        let blackRatio = contrastRatio(luminanceA: backgroundLuminance, luminanceB: 0)
        let whiteRatio = contrastRatio(luminanceA: backgroundLuminance, luminanceB: 1)
        return blackRatio >= whiteRatio ? .black : .white
    }

    static func contrastRatio(
        foreground: Foreground,
        backgroundRed red: Double,
        green: Double,
        blue: Double
    ) -> Double {
        let foregroundLuminance = foreground == .black ? 0.0 : 1.0
        let backgroundLuminance = relativeLuminance(red: red, green: green, blue: blue)
        return contrastRatio(luminanceA: foregroundLuminance, luminanceB: backgroundLuminance)
    }

    private static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        let linearRed = linearized(red)
        let linearGreen = linearized(green)
        let linearBlue = linearized(blue)
        return (0.2126 * linearRed) + (0.7152 * linearGreen) + (0.0722 * linearBlue)
    }

    private static func linearized(_ component: Double) -> Double {
        let clamped = min(max(component, 0), 1)
        return clamped <= 0.04045
            ? clamped / 12.92
            : pow((clamped + 0.055) / 1.055, 2.4)
    }

    private static func contrastRatio(luminanceA: Double, luminanceB: Double) -> Double {
        let lighter = max(luminanceA, luminanceB)
        let darker = min(luminanceA, luminanceB)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

enum AdaptiveSelectedControlColors {
    struct ResolvedPair {
        var background: NSColor
        var foreground: AdaptiveSelectedControlContrast.Foreground

        var contrastRatio: Double {
            AdaptiveSelectedControlContrast.contrastRatio(
                foreground: foreground,
                backgroundRed: Double(background.redComponent),
                green: Double(background.greenComponent),
                blue: Double(background.blueComponent)
            )
        }
    }

    static func background(isActive: Bool) -> Color {
        Color(nsColor: semanticBackground(isActive: isActive))
    }

    static func foreground(isActive: Bool) -> Color {
        Color(nsColor: adaptiveForeground(isActive: isActive))
    }

    static func resolvedPair(isActive: Bool, appearance: NSAppearance) -> ResolvedPair {
        var resolvedBackground = NSColor.labelColor.usingColorSpace(.sRGB) ?? .black
        appearance.performAsCurrentDrawingAppearance {
            resolvedBackground = semanticBackground(isActive: isActive)
                .usingColorSpace(.sRGB) ?? resolvedBackground
        }
        let foreground = AdaptiveSelectedControlContrast.foreground(
            red: Double(resolvedBackground.redComponent),
            green: Double(resolvedBackground.greenComponent),
            blue: Double(resolvedBackground.blueComponent)
        )
        return ResolvedPair(background: resolvedBackground, foreground: foreground)
    }

    static func resolvedDynamicForeground(isActive: Bool, appearance: NSAppearance) -> NSColor {
        var resolvedForeground = NSColor.labelColor.usingColorSpace(.sRGB) ?? .black
        appearance.performAsCurrentDrawingAppearance {
            resolvedForeground = adaptiveForeground(isActive: isActive)
                .usingColorSpace(.sRGB) ?? resolvedForeground
        }
        return resolvedForeground
    }

    private static func semanticBackground(isActive: Bool) -> NSColor {
        isActive ? .selectedControlColor : .unemphasizedSelectedContentBackgroundColor
    }

    private static func adaptiveForeground(isActive: Bool) -> NSColor {
        NSColor(name: nil) { appearance in
            resolvedPair(isActive: isActive, appearance: appearance).foreground.nsColor
        }
    }
}

struct AdaptiveSelectedControlStyle: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var selected: Bool
    var unselectedForeground: Color
    var unselectedBackground: Color
    var cornerRadius: CGFloat
    var emphasizeContrast: Bool
    var disabledOpacity: Double
    var suppressSelectionWhenDisabled: Bool
    var isPressed: Bool

    func body(content: Content) -> some View {
        let selectedIsVisible = Self.selectionIsVisible(
            selected: selected,
            isEnabled: isEnabled,
            suppressSelectionWhenDisabled: suppressSelectionWhenDisabled
        )
        let isActive = controlActiveState != .inactive
        let foreground = AdaptiveSelectedControlColors.foreground(isActive: isActive)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .foregroundStyle(selectedIsVisible ? foreground : unselectedForeground)
            .background(
                shape.fill(
                    selectedIsVisible
                        ? AdaptiveSelectedControlColors.background(isActive: isActive)
                        : unselectedBackground
                )
            )
            .overlay(
                shape.stroke(
                    Self.contrastOutlineIsVisible(
                        selectedIsVisible: selectedIsVisible,
                        emphasizeContrast: emphasizeContrast,
                        increasedContrast: colorSchemeContrast == .increased
                    )
                        ? foreground.opacity(0.72)
                        : Color.clear,
                    lineWidth: 1
                )
            )
            .opacity(isEnabled ? 1 : disabledOpacity)
            .scaleEffect(
                Self.selectedScale(
                    selectedIsVisible: selectedIsVisible,
                    isEnabled: isEnabled,
                    isPressed: isPressed
                )
            )
            .accessibilityAddTraits(selectedIsVisible ? .isSelected : [])
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    static func selectionIsVisible(
        selected: Bool,
        isEnabled: Bool,
        suppressSelectionWhenDisabled: Bool
    ) -> Bool {
        selected && (isEnabled || !suppressSelectionWhenDisabled)
    }

    static func selectedScale(selectedIsVisible: Bool, isEnabled: Bool, isPressed: Bool) -> CGFloat {
        selectedIsVisible && isEnabled && isPressed ? 0.94 : 1
    }

    static func contrastOutlineIsVisible(
        selectedIsVisible: Bool,
        emphasizeContrast: Bool,
        increasedContrast: Bool
    ) -> Bool {
        selectedIsVisible && (emphasizeContrast || increasedContrast)
    }
}

extension View {
    func adaptiveSelectedControl(
        selected: Bool,
        unselectedForeground: Color = .primary,
        unselectedBackground: Color = .clear,
        cornerRadius: CGFloat,
        emphasizeContrast: Bool = false,
        disabledOpacity: Double = 0.55,
        suppressSelectionWhenDisabled: Bool = false,
        isPressed: Bool = false
    ) -> some View {
        modifier(
            AdaptiveSelectedControlStyle(
                selected: selected,
                unselectedForeground: unselectedForeground,
                unselectedBackground: unselectedBackground,
                cornerRadius: cornerRadius,
                emphasizeContrast: emphasizeContrast,
                disabledOpacity: disabledOpacity,
                suppressSelectionWhenDisabled: suppressSelectionWhenDisabled,
                isPressed: isPressed
            )
        )
    }
}
