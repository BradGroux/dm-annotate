import AppKit
import CoreGraphics
import DMAnnotateCore

enum ActiveKeyboardLayout {
    static func character(forKeyCode keyCode: Int64, modifiers: ShortcutModifiers = []) -> String? {
        guard keyCode >= 0, keyCode <= Int64(CGKeyCode.max),
              let event = CGEvent(
                  keyboardEventSource: nil,
                  virtualKey: CGKeyCode(keyCode),
                  keyDown: true
              ) else { return nil }

        var flags: CGEventFlags = []
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        event.flags = flags
        return NSEvent(cgEvent: event)?.charactersIgnoringModifiers
    }

    static func keyCode(forLegacyCharacter character: String, modifiers: ShortcutModifiers) -> Int64? {
        let expected = character.lowercased()
        let printableKeyCodes = ShortcutKeyIdentity.allKeyCodes
            .filter { $0 <= 50 }
            .sorted()

        if let exactMatch = printableKeyCodes.first(where: { keyCode in
                self.character(forKeyCode: keyCode, modifiers: modifiers)?.lowercased() == expected
        }) {
            return exactMatch
        }

        // Hand-edited legacy preferences sometimes named the unshifted key while
        // still including Shift. The old recorder named the shifted character.
        guard modifiers.contains(.shift) else { return nil }
        var unshiftedModifiers = modifiers
        unshiftedModifiers.remove(.shift)
        return printableKeyCodes.first { keyCode in
            self.character(forKeyCode: keyCode, modifiers: unshiftedModifiers)?.lowercased() == expected
        }
    }
}
