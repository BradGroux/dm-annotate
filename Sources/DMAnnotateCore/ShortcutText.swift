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
    private static let specialKeys = [
        "esc": "escape",
        "return": "enter",
        "delete": "delete",
        "backspace": "delete",
        "space": "space"
    ]

    public static func normalize(_ raw: String) -> String {
        let tokens = raw
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .split(separator: "+", omittingEmptySubsequences: false)
            .map(String.init)

        guard !tokens.isEmpty, !tokens.contains("") else { return "" }

        let normalizedTokens = tokens.map { token in
            specialKeys[modifierAliases[token] ?? token] ?? modifierAliases[token] ?? token
        }

        guard let key = normalizedTokens.last, !modifierOrder.contains(key) else { return "" }

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
        let normalized = normalize(raw)
        guard !normalized.isEmpty else { return "None" }

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
                case "space": "Space"
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
