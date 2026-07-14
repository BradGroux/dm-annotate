import Foundation

public struct ShortcutModifiers: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let control = ShortcutModifiers(rawValue: 1 << 0)
    public static let option = ShortcutModifiers(rawValue: 1 << 1)
    public static let shift = ShortcutModifiers(rawValue: 1 << 2)
    public static let command = ShortcutModifiers(rawValue: 1 << 3)
}

public enum ShortcutDescriptorFormat {
    public static let legacyLayoutDependentVersion = 0
    public static let currentVersion = 1
}

/// Converts descriptors written by the former character-based recorder into the
/// physical-key format. Printable keys must be resolved through the active input
/// layout; values that cannot be resolved return nil so callers can preserve the
/// original text for visible recovery instead of changing its meaning.
public enum LegacyShortcutDescriptorMigration {
    public static let unresolvedPrefix = "legacy-layout:"

    public static func preserveUnresolved(_ raw: String) -> String {
        raw.hasPrefix(unresolvedPrefix) ? raw : unresolvedPrefix + raw
    }

    public static func unresolvedOriginal(from raw: String) -> String? {
        guard raw.hasPrefix(unresolvedPrefix) else { return nil }
        return String(raw.dropFirst(unresolvedPrefix.count))
    }

    public static func migrate(
        _ raw: String,
        keyCodeForCharacter: (String, ShortcutModifiers) -> Int64?
    ) -> String? {
        let tokens = raw
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .split(separator: "+", omittingEmptySubsequences: false)
            .map(String.init)
        guard !tokens.isEmpty, !tokens.contains("") else { return nil }

        let normalizedTokens = tokens.map { modifierAliases[$0] ?? $0 }
        guard let rawKey = normalizedTokens.last,
              !ShortcutText.modifierOrder.contains(rawKey) else { return nil }

        var modifiers: ShortcutModifiers = []
        for modifier in normalizedTokens.dropLast() {
            switch modifier {
            case "control": modifiers.insert(.control)
            case "option": modifiers.insert(.option)
            case "shift": modifiers.insert(.shift)
            case "command": modifiers.insert(.command)
            default: return nil
            }
        }

        let key = keyAliases[rawKey] ?? rawKey
        if key == "escape" {
            return "escape"
        }
        guard !modifiers.isEmpty else { return nil }

        let directKeyCode = ShortcutKeyIdentity.primaryKeyCode(forName: key)
        let keyCode: Int64?
        if let directKeyCode,
           directKeyCode > 50 || nonPrintableANSIKeyCodes.contains(directKeyCode) {
            keyCode = directKeyCode
        } else {
            keyCode = keyCodeForCharacter(key, modifiers)
        }
        guard let keyCode else { return nil }
        return PortableShortcutDescriptor.resolve(keyCode: keyCode, modifiers: modifiers)
    }

    private static let modifierAliases = [
        "cmd": "command", "⌘": "command",
        "opt": "option", "alt": "option", "⌥": "option",
        "ctrl": "control", "ctl": "control", "⌃": "control",
        "⇧": "shift"
    ]

    private static let keyAliases = [
        "esc": "escape",
        "return": "enter",
        "backspace": "delete",
        "spacebar": "space",
        "left-arrow": "left",
        "right-arrow": "right",
        "up-arrow": "up",
        "down-arrow": "down",
        "pageup": "page-up",
        "pagedown": "page-down"
    ]

    // Return, Tab, and Space sit inside the ANSI printable key-code range but
    // are named controls rather than characters from the active layout.
    private static let nonPrintableANSIKeyCodes: Set<Int64> = [36, 48, 49]
}

public enum PortableShortcutDescriptor {
    public static func resolve(keyCode: Int64, modifiers: ShortcutModifiers) -> String? {
        guard let key = ShortcutKeyIdentity.name(forKeyCode: keyCode) else { return nil }
        if key == "escape" {
            return "escape"
        }

        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("control") }
        if modifiers.contains(.option) { parts.append("option") }
        if modifiers.contains(.shift) { parts.append("shift") }
        if modifiers.contains(.command) { parts.append("command") }
        parts.append(key)

        let descriptor = ShortcutText.normalize(parts.joined(separator: "+"))
        return descriptor.isEmpty ? nil : descriptor
    }
}

public struct PortableShortcutMenuEquivalent: Equatable, Sendable {
    public let key: String
    public let modifiers: ShortcutModifiers

    public init(key: String, modifiers: ShortcutModifiers) {
        self.key = key
        self.modifiers = modifiers
    }
}

public enum PortableShortcutMenuAdapter {
    public static func resolve(
        _ raw: String,
        characterForKeyCode: (Int64) -> String?
    ) -> PortableShortcutMenuEquivalent? {
        let normalized = ShortcutText.normalize(raw)
        guard !normalized.isEmpty else { return nil }

        let parts = normalized.split(separator: "+").map(String.init)
        guard let keyName = parts.last,
              let keyCode = ShortcutKeyIdentity.primaryKeyCode(forName: keyName),
              let key = characterForKeyCode(keyCode),
              !key.isEmpty else { return nil }

        var modifiers: ShortcutModifiers = []
        for modifier in parts.dropLast() {
            switch modifier {
            case "control": modifiers.insert(.control)
            case "option": modifiers.insert(.option)
            case "shift": modifiers.insert(.shift)
            case "command": modifiers.insert(.command)
            default: return nil
            }
        }

        return PortableShortcutMenuEquivalent(key: key, modifiers: modifiers)
    }
}

public enum ShortcutRecordingRejection: Equatable, Sendable {
    case unsupportedKey
    case missingModifier
}

public enum ShortcutRecordingOutcome: Equatable, Sendable {
    case accepted(String)
    case clear
    case cancel
    case rejected(ShortcutRecordingRejection)

    public static func resolve(keyCode: Int64, modifiers: ShortcutModifiers) -> ShortcutRecordingOutcome {
        if keyCode == 53 {
            return .cancel
        }
        if (keyCode == 51 || keyCode == 117), modifiers.isEmpty {
            return .clear
        }
        guard ShortcutKeyIdentity.name(forKeyCode: keyCode) != nil else {
            return .rejected(.unsupportedKey)
        }
        guard let descriptor = PortableShortcutDescriptor.resolve(keyCode: keyCode, modifiers: modifiers) else {
            return .rejected(.missingModifier)
        }
        return .accepted(descriptor)
    }

    public var feedback: String? {
        switch self {
        case .accepted, .clear, .cancel: nil
        case .rejected(.unsupportedKey): "Unsupported key"
        case .rejected(.missingModifier): "Use modifier..."
        }
    }
}

/// Portable key identities used by recording, validation, menus, and global dispatch.
///
/// Letter and punctuation names describe the physical ANSI key position, not the
/// character produced by the active input source. This keeps a recorded shortcut
/// stable when the user changes keyboard layouts.
public enum ShortcutKeyIdentity {
    public static var allKeyCodes: Set<Int64> {
        Set(namesByKeyCode.keys)
    }

    public static var allCanonicalNames: Set<String> {
        Set(namesByKeyCode.values)
    }

    public static func name(forKeyCode keyCode: Int64) -> String? {
        namesByKeyCode[keyCode]
    }

    public static func keyCodes(forName rawName: String) -> Set<Int64> {
        guard let name = canonicalName(for: rawName) else { return [] }
        return keyCodesByName[name] ?? []
    }

    public static func supports(_ rawName: String) -> Bool {
        !keyCodes(forName: rawName).isEmpty
    }

    public static func primaryKeyCode(forName rawName: String) -> Int64? {
        keyCodes(forName: rawName).min()
    }

    public static func canonicalName(for rawName: String) -> String? {
        let name = rawName.lowercased()
        let canonical = aliases[name] ?? name
        return keyCodesByName[canonical] == nil ? nil : canonical
    }

    private static let aliases: [String: String] = [
        "esc": "escape",
        "return": "enter",
        "backspace": "delete",
        "spacebar": "space",
        "left-arrow": "left",
        "right-arrow": "right",
        "up-arrow": "up",
        "down-arrow": "down",
        "pageup": "page-up",
        "pagedown": "page-down",
        "forwarddelete": "forward-delete"
    ]

    private static let namesByKeyCode: [Int64: String] = [
        // ANSI physical key positions.
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
        8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y",
        17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=",
        25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "o", 32: "u",
        33: "[", 34: "i", 35: "p", 36: "enter", 37: "l", 38: "j", 39: "'", 40: "k",
        41: ";", 42: "\\", 43: ",", 44: "/", 45: "n", 46: "m", 47: ".", 48: "tab",
        49: "space", 50: "`", 51: "delete", 53: "escape",

        // Function and navigation keys.
        64: "f17", 79: "f18", 80: "f19", 90: "f20", 96: "f5", 97: "f6",
        98: "f7", 99: "f3", 100: "f8", 101: "f9", 103: "f11", 105: "f13",
        106: "f16", 107: "f14", 109: "f10", 111: "f12", 113: "f15", 114: "help",
        115: "home", 116: "page-up", 117: "forward-delete", 118: "f4", 119: "end",
        120: "f2", 121: "page-down", 122: "f1", 123: "left", 124: "right",
        125: "down", 126: "up"
    ]

    private static let keyCodesByName: [String: Set<Int64>] = {
        Dictionary(grouping: namesByKeyCode, by: \.value)
            .mapValues { Set($0.map(\.key)) }
    }()
}
