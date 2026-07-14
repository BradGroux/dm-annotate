import AppKit
import DMAnnotateCore
import SwiftUI

enum ToolbarAccessibilitySafetyMode: Equatable {
    case safeMode
    case cursor
    case drawing

    static func resolve(
        activeTool: AnnotationTool,
        whiteboardModeEnabled: Bool,
        isSafeMode: Bool
    ) -> Self {
        if isSafeMode { return .safeMode }
        return activeTool == .cursor && !whiteboardModeEnabled ? .cursor : .drawing
    }
}

struct ToolbarControlAccessibility: Equatable {
    let label: String
    let value: String
    let hint: String
    let identifier: String
    let isSelected: Bool
}

struct ToolbarAccessibilityState: Equatable {
    let activeTool: AnnotationTool
    let whiteboardModeEnabled: Bool
    let whiteboardBackground: WhiteboardBackground
    let annotationsLocked: Bool
    let annotationsVisible: Bool
    let currentColor: RGBAColor
    let strokeWidth: CGFloat
    let textFontSize: CGFloat
    let textFontWeight: TextFontWeight
    let isSafeMode: Bool

    var safetyMode: ToolbarAccessibilitySafetyMode {
        .resolve(
            activeTool: activeTool,
            whiteboardModeEnabled: whiteboardModeEnabled,
            isSafeMode: isSafeMode
        )
    }

    var activeToolValue: String {
        guard whiteboardModeEnabled else { return activeTool.displayName }
        return whiteboardBackground.isDarkBoard ? "Blackboard" : "Whiteboard"
    }

    var boardValue: String {
        guard whiteboardModeEnabled else {
            return "Off, preferred \(boardBackgroundName)"
        }
        let family = whiteboardBackground.isDarkBoard ? "Blackboard" : "Whiteboard"
        return "On, \(family) family, \(boardBackgroundName)"
    }

    var lockValue: String { annotationsLocked ? "Locked" : "Unlocked" }
    var visibilityValue: String { annotationsVisible ? "Visible" : "Hidden" }
    var strokeWidthValue: String { "\(formatted(strokeWidth)) pixels" }
    var textStyleValue: String { "\(formatted(textFontSize)) pixels, \(textFontWeight.displayName)" }

    var colorValue: String {
        colorValue(for: currentColor)
    }

    func colorValue(for color: RGBAColor) -> String {
        let named: [(RGBAColor, String)] = [
            (.red, "Red"), (.amber, "Amber"), (.yellow, "Yellow"), (.green, "Green"),
            (.cyan, "Cyan"), (.blue, "Blue"), (.purple, "Purple"), (.pink, "Pink"),
            (.white, "White"), (.black, "Black")
        ]
        if let match = named.first(where: { $0.0 == color }) {
            return match.1
        }
        return "Custom color, \(percent(color.red)) red, \(percent(color.green)) green, " +
            "\(percent(color.blue)) blue, \(percent(color.alpha)) opacity"
    }

    var summary: String {
        "\(safetySummary). Active tool: \(activeToolValue). Board: \(boardValue). " +
            "Annotations: \(lockValue), \(visibilityValue). Color: \(colorValue). " +
            "Stroke width: \(strokeWidthValue). Text size: \(textStyleValue)."
    }

    func tool(_ tool: AnnotationTool, isEnabled: Bool) -> ToolbarControlAccessibility {
        let selected: Bool
        switch tool {
        case .whiteboard:
            selected = isEnabled && whiteboardModeEnabled && !whiteboardBackground.isDarkBoard
        case .blackboard:
            selected = isEnabled && whiteboardModeEnabled && whiteboardBackground.isDarkBoard
        default:
            selected = isEnabled && !whiteboardModeEnabled && activeTool == tool
        }

        let value: String
        if !isEnabled {
            value = "Unavailable in Safe Mode"
        } else if selected && (tool == .whiteboard || tool == .blackboard) {
            value = "Current board; \(boardBackgroundName); pointer input captured"
        } else if selected {
            value = tool == .cursor
                ? "Current tool; pointer input passes through"
                : "Current tool; pointer input captured"
        } else {
            value = "Available"
        }

        return ToolbarControlAccessibility(
            label: tool.displayName,
            value: value,
            hint: isEnabled ? "Select \(tool.displayName)" : "Exit Safe Mode to use \(tool.displayName)",
            identifier: "toolbar.tool.\(tool.rawValue)",
            isSelected: selected
        )
    }

    func control(
        label: String,
        value: String,
        hint: String,
        identifier: String,
        isSelected: Bool = false
    ) -> ToolbarControlAccessibility {
        ToolbarControlAccessibility(
            label: label,
            value: value,
            hint: hint,
            identifier: identifier,
            isSelected: isSelected
        )
    }

    private var safetySummary: String {
        switch safetyMode {
        case .safeMode: "Safe Mode; pointer input passes through"
        case .cursor: "Cursor mode; pointer input passes through"
        case .drawing: "Drawing mode; pointer input captured"
        }
    }

    private var boardBackgroundName: String {
        switch whiteboardBackground {
        case .white: "White"
        case .black: "Black"
        case .lightGrid: "Light Grid"
        case .darkGrid: "Dark Grid"
        }
    }

    private func formatted(_ value: CGFloat) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct ToolbarAccessibilityStateKey: EnvironmentKey {
    static let defaultValue = ToolbarAccessibilityState(
        activeTool: .cursor,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white,
        annotationsLocked: false,
        annotationsVisible: true,
        currentColor: .red,
        strokeWidth: 3,
        textFontSize: 24,
        textFontWeight: .semibold,
        isSafeMode: false
    )
}

extension EnvironmentValues {
    var toolbarAccessibilityState: ToolbarAccessibilityState {
        get { self[ToolbarAccessibilityStateKey.self] }
        set { self[ToolbarAccessibilityStateKey.self] = newValue }
    }
}

private struct ToolbarAccessibilityModifier: ViewModifier {
    let semantics: ToolbarControlAccessibility

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(semantics.label)
            .accessibilityValue(semantics.value)
            .accessibilityHint(semantics.hint)
            .accessibilityIdentifier(semantics.identifier)
            .accessibilityAddTraits(semantics.isSelected ? .isSelected : [])
    }
}

extension View {
    func toolbarAccessibility(_ semantics: ToolbarControlAccessibility) -> some View {
        modifier(ToolbarAccessibilityModifier(semantics: semantics))
    }
}

struct ToolbarAccessibilityAnnouncementSnapshot: Equatable {
    let safetyMode: ToolbarAccessibilitySafetyMode
    let annotationsLocked: Bool
    let annotationsVisible: Bool

    var message: String {
        let safety: String
        switch safetyMode {
        case .safeMode: safety = "Safe Mode. Pointer input passes through."
        case .cursor: safety = "Cursor mode. Pointer input passes through."
        case .drawing: safety = "Drawing mode. Pointer input captured."
        }
        let lock = annotationsLocked ? "locked" : "unlocked"
        let visibility = annotationsVisible ? "visible" : "hidden"
        return "\(safety) Annotations \(lock) and \(visibility)."
    }
}

struct ToolbarAccessibilityAnnouncementCoalescer {
    static let delay: TimeInterval = 0.25

    private(set) var pendingSnapshot: ToolbarAccessibilityAnnouncementSnapshot?
    private(set) var deadline: TimeInterval?

    mutating func schedule(_ snapshot: ToolbarAccessibilityAnnouncementSnapshot, at uptime: TimeInterval) {
        pendingSnapshot = snapshot
        deadline = uptime + Self.delay
    }

    mutating func takeReady(at uptime: TimeInterval) -> ToolbarAccessibilityAnnouncementSnapshot? {
        guard let deadline, uptime >= deadline else { return nil }
        defer { cancel() }
        return pendingSnapshot
    }

    mutating func cancel() {
        pendingSnapshot = nil
        deadline = nil
    }
}

@MainActor
protocol ToolbarStateAccessibilityAnnouncing: AnyObject {
    func announce(_ message: String, from element: Any)
}

@MainActor
final class AppKitToolbarStateAccessibilityAnnouncer: ToolbarStateAccessibilityAnnouncing {
    func announce(_ message: String, from element: Any) {
        NSAccessibility.post(
            element: element,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }
}
