import AppKit
import DMAnnotateCore
import SwiftUI

struct ShortcutRecorderField: NSViewRepresentable {
    @Binding var shortcut: String
    var isDuplicate: Bool

    func makeNSView(context: Context) -> RecordingShortcutField {
        let field = RecordingShortcutField()
        field.onChange = { shortcut = $0 }
        return field
    }

    func updateNSView(_ nsView: RecordingShortcutField, context: Context) {
        nsView.onChange = { shortcut = $0 }
        nsView.shortcut = shortcut
        nsView.isDuplicate = isDuplicate
    }
}

final class RecordingShortcutField: NSTextField {
    var onChange: ((String) -> Void)?
    var shortcut: String = "" {
        didSet {
            guard !isRecording else { return }
            stringValue = ShortcutDescriptor.display(shortcut)
        }
    }
    var isDuplicate: Bool = false {
        didSet {
            layer?.borderColor = isDuplicate ? NSColor.systemYellow.cgColor : NSColor.separatorColor.cgColor
        }
    }

    private var isRecording = false

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
        toolTip = "Click, then press a shortcut. Press Delete to clear."
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        stringValue = "Press keys..."
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        stringValue = ShortcutDescriptor.display(shortcut)
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let eventModifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
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
            stringValue = ShortcutRecordingOutcome.rejected(rejection).feedback ?? "Unsupported shortcut"
            NSSound.beep()
        }
    }
}
