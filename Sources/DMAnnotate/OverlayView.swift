import AppKit
import Combine
import DMAnnotateCore

final class OverlayView: NSView, NSTextFieldDelegate {
    private let store: AnnotationStore
    private let displayID: UInt32
    private var preview: AnnotationItem?
    private var laserTrail: [TimedPoint] = []
    private var laserTimer: Timer?
    private weak var activeTextField: NSTextField?

    init(frame: CGRect, store: AnnotationStore, displayID: UInt32) {
        self.store = store
        self.displayID = displayID
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        window?.acceptsMouseMovedEvents = true
    }

    func syncWithStore() {
        if store.activeTool == .cursor {
            preview = nil
            activeTextField?.removeFromSuperview()
            activeTextField = nil
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if store.whiteboardModeEnabled {
            AnnotationRenderer.drawWhiteboard(in: bounds, background: store.whiteboardBackground)
        }

        guard store.isVisible else { return }

        store.annotations
            .filter { $0.displayID == displayID }
            .forEach(AnnotationRenderer.draw)

        if let preview {
            AnnotationRenderer.draw(preview)
        }

        AnnotationRenderer.drawLaserTrail(laserTrail)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)

        guard !store.annotationsLocked || store.activeTool == .laser else {
            NSSound.beep()
            return
        }

        switch store.activeTool {
        case .cursor:
            return
        case .pen:
            preview = AnnotationItem(displayID: displayID, kind: .pen, points: [point], color: store.currentColor, lineWidth: store.strokeWidth)
        case .highlighter:
            preview = AnnotationItem(displayID: displayID, kind: .highlighter, points: [point], color: store.currentColor, lineWidth: store.strokeWidth)
        case .eraser:
            store.erase(at: point, radius: max(store.strokeWidth * 3, 14), displayID: displayID)
        case .line:
            preview = AnnotationItem(displayID: displayID, kind: .line, points: [point, point], color: store.currentColor, lineWidth: store.strokeWidth)
        case .rectangle:
            preview = AnnotationItem(displayID: displayID, kind: .rectangle, points: [point, point], color: store.currentColor, lineWidth: store.strokeWidth)
        case .ellipse:
            preview = AnnotationItem(displayID: displayID, kind: .ellipse, points: [point, point], color: store.currentColor, lineWidth: store.strokeWidth)
        case .arrow:
            preview = AnnotationItem(displayID: displayID, kind: .arrow, points: [point, point], color: store.currentColor, lineWidth: store.strokeWidth)
        case .text:
            beginTextEntry(at: point)
        case .laser:
            appendLaserPoint(point)
        case .whiteboard:
            store.setActiveTool(.whiteboard)
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard !store.annotationsLocked || store.activeTool == .laser else { return }
        let point = convert(event.locationInWindow, from: nil)

        switch store.activeTool {
        case .pen, .highlighter:
            preview?.points.append(point)
        case .line, .rectangle, .ellipse, .arrow:
            guard var currentPreview = preview, let start = currentPreview.points.first else { return }
            currentPreview.points = [start, point]
            preview = currentPreview
        case .eraser:
            store.erase(at: point, radius: max(store.strokeWidth * 3, 14), displayID: displayID)
        case .laser:
            appendLaserPoint(point)
        case .cursor, .text, .whiteboard:
            break
        }

        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        guard store.activeTool == .laser else { return }
        appendLaserPoint(convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        guard let finalPreview = preview else { return }
        preview = nil

        if finalPreview.points.count > 1 || finalPreview.kind != .pen {
            store.add(finalPreview)
        }

        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection([.command]).contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "q" {
            NSApp.terminate(nil)
            return
        }

        if event.keyCode == 53 {
            store.exitScreenControls()
            return
        }

        super.keyDown(with: event)
    }

    private func beginTextEntry(at point: CGPoint) {
        activeTextField?.removeFromSuperview()

        let field = NSTextField(frame: CGRect(x: point.x, y: point.y, width: 280, height: 34))
        field.font = .systemFont(ofSize: 24, weight: .semibold)
        field.textColor = NSColor(store.currentColor)
        field.backgroundColor = NSColor.black.withAlphaComponent(0.18)
        field.drawsBackground = true
        field.isBordered = true
        field.focusRingType = .default
        field.placeholderString = "Text"
        field.delegate = self
        addSubview(field)
        activeTextField = field
        window?.makeFirstResponder(field)
    }

    private func commitTextField(_ field: NSTextField) {
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let origin = field.frame.origin
        field.removeFromSuperview()

        guard !text.isEmpty else { return }

        store.add(
            AnnotationItem(
                displayID: displayID,
                kind: .text,
                points: [origin],
                color: store.currentColor,
                lineWidth: store.strokeWidth,
                text: text,
                fontSize: textFontSize(for: store.strokeWidth)
            )
        )
        needsDisplay = true
    }

    private func textFontSize(for strokeWidth: CGFloat) -> CGFloat {
        switch strokeWidth {
        case ...1:
            18
        case ...3:
            24
        case ...5:
            32
        default:
            44
        }
    }

    private func cancelTextField(_ field: NSTextField) {
        field.removeFromSuperview()
        activeTextField = nil
        store.exitScreenControls()
        needsDisplay = true
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard let field = control as? NSTextField else { return false }

        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commitTextField(field)
            return true
        }

        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelTextField(field)
            return true
        }

        return false
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, field.superview != nil else { return }
        commitTextField(field)
    }

    private func appendLaserPoint(_ point: CGPoint) {
        laserTrail.append(TimedPoint(point: point, timestamp: Date()))
        laserTrail = laserTrail.filter { Date().timeIntervalSince($0.timestamp) < 1.5 }

        laserTimer?.invalidate()
        laserTimer = Timer.scheduledTimer(
            timeInterval: 1 / 30,
            target: self,
            selector: #selector(trimLaserTrail(_:)),
            userInfo: nil,
            repeats: true
        )

        needsDisplay = true
    }

    @objc private func trimLaserTrail(_ timer: Timer) {
        laserTrail = laserTrail.filter { Date().timeIntervalSince($0.timestamp) < 1.5 }
        needsDisplay = true
        if laserTrail.isEmpty {
            timer.invalidate()
        }
    }
}
