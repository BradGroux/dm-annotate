import AppKit
import Combine
import DMAnnotateCore

final class OverlayView: NSView, NSTextViewDelegate {
    private let store: AnnotationStore
    private let displayID: UInt32
    private var preview: AnnotationItem?
    private var laserTrail: [TimedPoint] = []
    private var laserTimer: Timer?
    private weak var activeTextView: NSTextView?
    private var activeTextOrigin: CGPoint?
    private var textMove: TextMove?

    private let minimumTextEditorSize = CGSize(width: 220, height: 38)
    private let maximumTextEditorHeight: CGFloat = 280

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
            textMove = nil
            activeTextView?.removeFromSuperview()
            activeTextView = nil
            activeTextOrigin = nil
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

        if let activeTextView, store.activeTool == .text {
            commitTextView(activeTextView)
            needsDisplay = true
            return
        }

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
            if beginTextMove(at: point) {
                break
            }
            beginTextEntry(at: point)
        case .laser:
            appendLaserPoint(point)
        case .whiteboard, .blackboard:
            break
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
        case .text:
            moveText(to: point)
        case .cursor, .whiteboard, .blackboard:
            break
        }

        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        switch store.activeTool {
        case .laser:
            appendLaserPoint(point)
        case .text:
            textAnnotation(at: point) == nil ? NSCursor.iBeam.set() : NSCursor.openHand.set()
        default:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        if let textMove {
            if let updated = store.annotation(id: textMove.original.id) {
                store.recordMove(from: textMove.original, to: updated)
            }
            self.textMove = nil
            NSCursor.openHand.set()
            needsDisplay = true
            return
        }

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
        activeTextView?.removeFromSuperview()

        let textView = NSTextView(
            frame: CGRect(
                x: point.x,
                y: point.y,
                width: minimumTextEditorSize.width,
                height: minimumTextEditorSize.height
            )
        )
        textView.delegate = self
        textView.font = .systemFont(ofSize: store.textFontSize, weight: NSFont.Weight(store.textFontWeight))
        textView.textColor = NSColor(store.currentColor)
        textView.backgroundColor = NSColor.black.withAlphaComponent(0.18)
        textView.drawsBackground = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.minSize = minimumTextEditorSize
        textView.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: maximumTextEditorHeight)
        textView.textContainerInset = CGSize(width: 8, height: 6)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = CGSize(
            width: minimumTextEditorSize.width - (textView.textContainerInset.width * 2),
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.insertionPointColor = NSColor(store.currentColor)
        textView.wantsLayer = true
        textView.layer?.cornerRadius = 6
        textView.layer?.borderWidth = 1
        textView.layer?.borderColor = NSColor.white.withAlphaComponent(0.5).cgColor

        addSubview(textView)
        activeTextView = textView
        activeTextOrigin = point
        window?.makeFirstResponder(textView)
    }

    private func beginTextMove(at point: CGPoint) -> Bool {
        guard let annotation = textAnnotation(at: point),
              let origin = annotation.points.first else {
            return false
        }

        textMove = TextMove(
            original: annotation,
            dragOffset: CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        )
        NSCursor.closedHand.set()
        return true
    }

    private func moveText(to point: CGPoint) {
        guard let textMove else { return }
        var updated = store.annotation(id: textMove.original.id) ?? textMove.original
        updated.points = [
            CGPoint(
                x: point.x - textMove.dragOffset.x,
                y: point.y - textMove.dragOffset.y
            )
        ]
        store.update(updated)
        NSCursor.closedHand.set()
    }

    private func textAnnotation(at point: CGPoint) -> AnnotationItem? {
        store.annotations
            .reversed()
            .first {
                $0.displayID == displayID &&
                    $0.kind == .text &&
                    $0.touches(point, radius: 2)
            }
    }

    private func commitTextView(_ textView: NSTextView) {
        let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let origin = textView.frame.origin
        textView.removeFromSuperview()
        activeTextView = nil
        activeTextOrigin = nil

        guard !text.isEmpty else { return }

        store.add(
            AnnotationItem(
                displayID: displayID,
                kind: .text,
                points: [origin],
                color: store.currentColor,
                lineWidth: store.strokeWidth,
                text: text,
                fontSize: store.textFontSize,
                fontWeight: store.textFontWeight
            )
        )
        needsDisplay = true
    }

    private func cancelTextView(_ textView: NSTextView) {
        textView.removeFromSuperview()
        activeTextView = nil
        activeTextOrigin = nil
        store.exitScreenControls()
        needsDisplay = true
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                textView.insertText("\n", replacementRange: textView.selectedRange())
                resizeTextView(textView)
                return true
            }

            commitTextView(textView)
            return true
        }

        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelTextView(textView)
            return true
        }

        return false
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        resizeTextView(textView)
    }

    private func resizeTextView(_ textView: NSTextView) {
        guard let font = textView.font else { return }

        let inset = textView.textContainerInset
        let horizontalPadding = inset.width * 2 + 2
        let availableWidth = max(120, bounds.maxX - textView.frame.minX - 16)
        let maxWidth = min(availableWidth, bounds.width - 16)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let measuredText = textView.string.isEmpty ? "Text" : textView.string
        let longestLineWidth = measuredText
            .components(separatedBy: .newlines)
            .map { line in
                let value = line.isEmpty ? " " : line
                return ceil((value as NSString).size(withAttributes: attributes).width)
            }
            .max() ?? 0
        let targetWidth = min(max(longestLineWidth + horizontalPadding + 18, minimumTextEditorSize.width), maxWidth)

        let anchor = activeTextOrigin ?? textView.frame.origin
        var frame = CGRect(origin: anchor, size: CGSize(width: targetWidth, height: textView.frame.height))
        textView.frame = clampedTextEditorFrame(frame)

        textView.textContainer?.containerSize = CGSize(
            width: targetWidth - horizontalPadding,
            height: CGFloat.greatestFiniteMagnitude
        )
        if let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            frame.size.height = min(
                max(ceil(usedRect.height + inset.height * 2 + 6), minimumTextEditorSize.height),
                maximumTextEditorHeight
            )
            textView.frame = clampedTextEditorFrame(frame)
        }
    }

    private func clampedTextEditorFrame(_ frame: CGRect) -> CGRect {
        let margin: CGFloat = 8
        let maxX = max(bounds.maxX - frame.width - margin, margin)
        let maxY = max(bounds.maxY - frame.height - margin, margin)
        let origin = CGPoint(
            x: min(max(frame.origin.x, margin), maxX),
            y: min(max(frame.origin.y, margin), maxY)
        )
        return CGRect(origin: origin, size: frame.size)
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

private struct TextMove {
    var original: AnnotationItem
    var dragOffset: CGPoint
}
