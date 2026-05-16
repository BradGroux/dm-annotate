import Foundation

public enum ShortcutResolver {
    public static func duplicateDescriptors(in shortcuts: [ShortcutAction: String]) -> Set<String> {
        let normalized = shortcuts.values
            .map(ShortcutText.normalize)
            .filter { !$0.isEmpty }

        let counts = Dictionary(grouping: normalized, by: { $0 }).mapValues(\.count)
        return Set(counts.filter { $0.value > 1 }.map(\.key))
    }

    public static func usableShortcut(for action: ShortcutAction, in shortcuts: [ShortcutAction: String]) -> String? {
        guard let shortcut = shortcuts[action] else { return nil }

        let normalized = ShortcutText.normalize(shortcut)
        guard !normalized.isEmpty, !duplicateDescriptors(in: shortcuts).contains(normalized) else {
            return nil
        }

        return normalized
    }

    public static func action(for descriptor: String, in shortcuts: [ShortcutAction: String]) -> ShortcutAction? {
        let normalizedDescriptor = ShortcutText.normalize(descriptor)
        guard !normalizedDescriptor.isEmpty, !duplicateDescriptors(in: shortcuts).contains(normalizedDescriptor) else {
            return nil
        }

        return shortcuts.first { _, shortcut in
            ShortcutText.normalize(shortcut) == normalizedDescriptor
        }?.key
    }

    public static func hasConflict(for descriptor: String, in shortcuts: [ShortcutAction: String]) -> Bool {
        let normalizedDescriptor = ShortcutText.normalize(descriptor)
        guard !normalizedDescriptor.isEmpty else { return false }

        return duplicateDescriptors(in: shortcuts).contains(normalizedDescriptor)
    }

    public static func globallyDispatchableActions(in shortcuts: [ShortcutAction: String]) -> [String: ShortcutAction] {
        var actionsByDescriptor: [String: ShortcutAction] = [:]

        for action in ShortcutAction.allCases {
            guard let descriptor = usableShortcut(for: action, in: shortcuts),
                  ShortcutText.canDispatchGlobally(descriptor) else { continue }
            actionsByDescriptor[descriptor] = action
        }

        return actionsByDescriptor
    }
}
