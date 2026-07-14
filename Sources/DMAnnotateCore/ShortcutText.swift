import Foundation

public enum ShortcutText {
    public static let modifierOrder = ["control", "option", "shift", "command"]
    private static let modifierAliases = [
        "cmd": "command",
        "⌘": "command",
        "opt": "option",
        "alt": "option",
        "⌥": "option",
        "ctrl": "control",
        "ctl": "control",
        "⌃": "control",
        "⇧": "shift"
    ]
    public static func normalize(_ raw: String) -> String {
        let tokens = raw
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .split(separator: "+", omittingEmptySubsequences: false)
            .map(String.init)

        guard !tokens.isEmpty, !tokens.contains("") else { return "" }

        let normalizedTokens = tokens.map { modifierAliases[$0] ?? $0 }

        guard let rawKey = normalizedTokens.last,
              !modifierOrder.contains(rawKey),
              let key = ShortcutKeyIdentity.canonicalName(for: rawKey) else { return "" }

        if key == "escape" {
            return "escape"
        }

        let modifiers = Set(normalizedTokens.dropLast())
        guard !modifiers.isEmpty, modifiers.allSatisfy({ modifierOrder.contains($0) }) else {
            return ""
        }

        let orderedModifiers = modifierOrder.filter { modifiers.contains($0) }
        return (orderedModifiers + [key]).joined(separator: "+")
    }

    public static func display(_ raw: String) -> String {
        if let legacy = LegacyShortcutDescriptorMigration.unresolvedOriginal(from: raw) {
            return "Legacy shortcut: \(legacy) (record again)"
        }

        let normalized = normalize(raw)
        guard !normalized.isEmpty else {
            return raw.isEmpty ? "None" : "Unsupported: \(raw)"
        }

        return normalized
            .split(separator: "+")
            .map { token in
                switch token {
                case "control": "Control"
                case "option": "Option"
                case "shift": "Shift"
                case "command": "Command"
                case "escape": "Esc"
                case "enter": "Enter"
                case "delete": "Delete"
                case "forward-delete": "Forward Delete"
                case "space": "Space"
                case "tab": "Tab"
                case "page-up": "Page Up"
                case "page-down": "Page Down"
                case "left": "Left Arrow"
                case "right": "Right Arrow"
                case "up": "Up Arrow"
                case "down": "Down Arrow"
                case "-": "-"
                case "=": "="
                default: token.uppercased()
                }
            }
            .joined(separator: "+")
    }

    public static func isValid(_ raw: String) -> Bool {
        !normalize(raw).isEmpty
    }

    public static func canDispatchGlobally(_ raw: String) -> Bool {
        let normalized = normalize(raw)
        guard !normalized.isEmpty, normalized != "escape" else { return false }

        let modifiers = Set(normalized.split(separator: "+").dropLast().map(String.init))
        return modifiers.contains("control") || modifiers.contains("option")
    }
}
