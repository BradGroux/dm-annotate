import Foundation

public enum GlobalShortcutMonitorState: Equatable, Sendable {
    case inactive
    case noGlobalShortcuts
    case consumable(actionCount: Int)
    case eventTapUnavailable(actionCount: Int)

    public static func resolved(actionCount: Int, didStartConsumableTap: Bool) -> GlobalShortcutMonitorState {
        guard actionCount > 0 else { return .noGlobalShortcuts }
        return didStartConsumableTap ? .consumable(actionCount: actionCount) : .eventTapUnavailable(actionCount: actionCount)
    }

    public var label: String {
        switch self {
        case .inactive:
            "Inactive"
        case .noGlobalShortcuts:
            "No global shortcuts"
        case .consumable(let actionCount):
            "Active (\(Self.actionLabel(for: actionCount)))"
        case .eventTapUnavailable(let actionCount):
            "Unavailable (\(Self.actionLabel(for: actionCount)))"
        }
    }

    public var detail: String? {
        switch self {
        case .inactive:
            "Shortcut monitors are stopped."
        case .noGlobalShortcuts:
            "Only app-local shortcuts are configured."
        case .consumable:
            nil
        case .eventTapUnavailable:
            "macOS did not allow the consumable event tap. Global shortcuts are disabled so keystrokes are not also delivered to the foreground app."
        }
    }

    public var needsAttention: Bool {
        if case .eventTapUnavailable = self {
            return true
        }
        return false
    }

    public var allowsGlobalShortcutDispatch: Bool {
        if case .consumable = self {
            return true
        }
        return false
    }

    private static func actionLabel(for count: Int) -> String {
        count == 1 ? "1 shortcut" : "\(count) shortcuts"
    }
}
