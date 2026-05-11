import AppKit
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
        if event.keyCode == 51 || event.keyCode == 117 {
            onChange?("")
            shortcut = ""
            window?.makeFirstResponder(nil)
            return
        }

        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }

        let descriptor = ShortcutDescriptor(event: event).normalized
        guard ShortcutDescriptor.isValid(descriptor) else {
            stringValue = "Use modifier..."
            NSSound.beep()
            return
        }

        onChange?(descriptor)
        shortcut = descriptor
        window?.makeFirstResponder(nil)
    }
}
