import AppKit
import DMAnnotateCore
import SwiftUI

struct ShortcutRecorderField: NSViewRepresentable {
    @Binding var shortcut: String
    var action: ShortcutAction
    var isDuplicate: Bool

    func makeNSView(context: Context) -> RecordingShortcutField {
        let field = RecordingShortcutField()
        field.onChange = { shortcut = $0 }
        field.actionName = action.displayName
        field.actionIdentifier = action.rawValue
        return field
    }

    func updateNSView(_ nsView: RecordingShortcutField, context: Context) {
        nsView.onChange = { shortcut = $0 }
        nsView.actionName = action.displayName
        nsView.actionIdentifier = action.rawValue
        nsView.shortcut = shortcut
        nsView.isDuplicate = isDuplicate
    }
}

final class RecordingShortcutField: NSTextField {
    var onChange: ((String) -> Void)?
    var actionName = "Keyboard" {
        didSet { updateAccessibilityMetadata() }
    }
    var actionIdentifier = "shortcut" {
        didSet { setAccessibilityIdentifier("settings.shortcut.\(actionIdentifier)") }
    }
    var shortcut: String = "" {
        didSet {
            guard !isRecording else { return }
            stringValue = ShortcutDescriptor.display(shortcut)
            updateAccessibilityMetadata()
        }
    }
    var isDuplicate: Bool = false {
        didSet {
            layer?.borderColor = isDuplicate ? NSColor.systemYellow.cgColor : NSColor.separatorColor.cgColor
            updateAccessibilityMetadata()
        }
    }

    private var isRecording = false
    private var rejectionFeedback: String?
    private var lastAccessibilityState: ShortcutRecorderAccessibilityState?

    init() {
        super.init(frame: .zero)
        isEditable = false
        isSelectable = false
        isBezeled = false
        drawsBackground = true
        backgroundColor = .controlBackgroundColor
        focusRingType = .default
        alignment = .center
        font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        stringValue = ShortcutDescriptor.display(shortcut)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        toolTip = "Click, or focus and press Space or Return, then press a shortcut. Press Delete to clear."
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityIdentifier("settings.shortcut.shortcut")
        updateAccessibilityMetadata()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        updateAccessibilityMetadata()
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        rejectionFeedback = nil
        stringValue = ShortcutDescriptor.display(shortcut)
        updateAccessibilityMetadata()
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        beginRecording()
    }

    override func keyDown(with event: NSEvent) {
        let eventModifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
        if !isRecording {
            if eventModifiers.isEmpty, [36, 49, 76].contains(Int(event.keyCode)) {
                beginRecording()
            } else {
                super.keyDown(with: event)
            }
            return
        }

        var modifiers: ShortcutModifiers = []
        if eventModifiers.contains(.control) { modifiers.insert(.control) }
        if eventModifiers.contains(.option) { modifiers.insert(.option) }
        if eventModifiers.contains(.shift) { modifiers.insert(.shift) }
        if eventModifiers.contains(.command) { modifiers.insert(.command) }

        switch ShortcutRecordingOutcome.resolve(keyCode: Int64(event.keyCode), modifiers: modifiers) {
        case .clear:
            onChange?("")
            shortcut = ""
            window?.makeFirstResponder(nil)
        case .cancel:
            window?.makeFirstResponder(nil)
        case let .accepted(descriptor):
            onChange?(descriptor)
            shortcut = descriptor
            window?.makeFirstResponder(nil)
        case let .rejected(rejection):
            rejectionFeedback = ShortcutRecordingOutcome.rejected(rejection).feedback ?? "Unsupported shortcut"
            stringValue = rejectionFeedback ?? "Unsupported shortcut"
            updateAccessibilityMetadata()
            NSSound.beep()
        }
    }

    override func accessibilityPerformPress() -> Bool {
        window?.makeFirstResponder(self)
        beginRecording()
        return true
    }

    override func accessibilityValue() -> String? {
        accessibilityState.value
    }

    private func beginRecording() {
        isRecording = true
        rejectionFeedback = nil
        stringValue = "Press keys..."
        updateAccessibilityMetadata()
    }

    private func updateAccessibilityMetadata() {
        let state = accessibilityState
        let previousState = lastAccessibilityState
        lastAccessibilityState = state
        setAccessibilityLabel(state.label)
        setAccessibilityHelp(state.help)
        if previousState != nil, previousState != state {
            NSAccessibility.post(element: self, notification: .valueChanged)
        }
    }

    private var accessibilityState: ShortcutRecorderAccessibilityState {
        ShortcutRecorderAccessibilityState(
            actionName: actionName,
            shortcut: shortcut,
            isRecording: isRecording,
            isDuplicate: isDuplicate,
            rejectionFeedback: rejectionFeedback
        )
    }
}
