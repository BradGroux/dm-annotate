import AppKit
import Combine
import DMAnnotateCore

final class OverlayView: NSView, NSTextViewDelegate {
    private let store: AnnotationStore
    private let displayID: UInt32
    private var preview: AnnotationItem?
    private var laserTrail = LaserTrail()
    private var laserTimer: Timer?
    private var strokePathCache: [AnnotationItem.ID: NSBezierPath] = [:]
    private weak var activeTextView: NSTextView?
    private var activeTextOrigin: CGPoint?
    private var textMove: TextMove?
    private var annotationMove: AnnotationMove?

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

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            laserTimer?.invalidate()
            laserTimer = nil
        }
        super.viewWillMove(toWindow: newWindow)
    }

    func syncInteractionState() {
        if store.activeTool == .cursor {
            preview = nil
            textMove = nil
            annotationMove = nil
            activeTextView?.removeFromSuperview()
            activeTextView = nil
            activeTextOrigin = nil
        }
        needsDisplay = true
    }

    func apply(_ invalidation: AnnotationInvalidation) {
        if invalidation.requiresFullRedraw {
            strokePathCache.removeAll(keepingCapacity: true)
            needsDisplay = true
            return
        }

        invalidation.annotationIDs.forEach { strokePathCache.removeValue(forKey: $0) }
        invalidation.regions
            .filter { $0.displayID == displayID }
            .forEach { setNeedsDisplay($0.rect) }
    }

    override func draw(_ dirtyRect: NSRect) {
        if store.whiteboardModeEnabled {
            AnnotationRenderer.drawWhiteboard(in: bounds, background: store.whiteboardBackground)
        }

        guard store.isVisible else { return }

        store.annotations(intersecting: dirtyRect, displayID: displayID)
            .forEach { annotation in
                if annotation.kind == .pen || annotation.kind == .highlighter {
                    let path = strokePathCache[annotation.id] ?? AnnotationRenderer.makeStrokePath(for: annotation.points)
                    strokePathCache[annotation.id] = path
                    AnnotationRenderer.draw(annotation, strokePath: path)
                } else {
                    AnnotationRenderer.draw(annotation)
                }
                if annotation.id == store.selectedAnnotationID {
                    AnnotationRenderer.drawSelection(annotation)
                }
            }

        if let preview {
            AnnotationRenderer.draw(preview)
        }

        AnnotationRenderer.drawLaserTrail(laserTrail.points)
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
        case .select:
            beginAnnotationSelection(at: point)
        case .pen:
            preview = AnnotationItem(displayID: displayID, kind: .pen, points: [point], color: store.currentColor, lineWidth: store.strokeWidth)
        case .highlighter:
            preview = AnnotationItem(displayID: displayID, kind: .highlighter, points: [point], color: store.currentColor, lineWidth: store.strokeWidth)
        case .eraser:
            store.erase(at: point, radius: max(store.strokeWidth * 3, 14), displayID: displayID)
            return
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
            return
        case .whiteboard, .blackboard:
            break
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard !store.annotationsLocked || store.activeTool == .laser else { return }
        let point = convert(event.locationInWindow, from: nil)

        switch store.activeTool {
        case .select:
            moveSelectedAnnotation(to: point)
            return
        case .pen, .highlighter:
            guard var currentPreview = preview else { return }
            let previousBounds = currentPreview.boundingRect
            currentPreview.appendSessionPoint(point)
            preview = currentPreview
            setNeedsDisplay(previousBounds.union(currentPreview.boundingRect))
            return
        case .line, .rectangle, .ellipse, .arrow:
            guard var currentPreview = preview, let start = currentPreview.points.first else { return }
            currentPreview.points = [start, point]
            preview = currentPreview
        case .eraser:
            store.erase(at: point, radius: max(store.strokeWidth * 3, 14), displayID: displayID)
            return
        case .laser:
            appendLaserPoint(point)
            return
        case .text:
            moveText(to: point)
            return
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
        case .select:
            annotation(at: point) == nil ? NSCursor.arrow.set() : NSCursor.openHand.set()
        case .text:
            textAnnotation(at: point) == nil ? NSCursor.iBeam.set() : NSCursor.openHand.set()
        default:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        if let annotationMove {
            if let updated = store.annotation(id: annotationMove.original.id) {
                store.recordMove(from: annotationMove.original, to: updated)
            }
            self.annotationMove = nil
            NSCursor.openHand.set()
            return
        }

        if let textMove {
            if let updated = store.annotation(id: textMove.original.id) {
                store.recordMove(from: textMove.original, to: updated)
            }
            self.textMove = nil
            NSCursor.openHand.set()
            return
        }

        guard let finalPreview = preview else { return }
        preview = nil

        if !finalPreview.points.isEmpty {
            store.add(finalPreview)
        }

        setNeedsDisplay(finalPreview.boundingRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection([.command]).contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "q" {
            NSApp.terminate(nil)
            return
        }

        if event.keyCode == 53 {
            if store.selectedAnnotationID != nil {
                store.clearSelection()
                return
            }
            store.exitScreenControls()
            return
        }

        if event.keyCode == 51 || event.keyCode == 117 {
            if store.deleteSelectedAnnotation() {
                return
            }
        }

        super.keyDown(with: event)
    }

    private func beginAnnotationSelection(at point: CGPoint) {
        guard let annotation = annotation(at: point) else {
            store.clearSelection()
            annotationMove = nil
            NSCursor.arrow.set()
            return
        }

        store.selectAnnotation(id: annotation.id)
        annotationMove = AnnotationMove(original: annotation, referencePoint: point)
        NSCursor.closedHand.set()
    }

    private func moveSelectedAnnotation(to point: CGPoint) {
        guard let annotationMove else { return }
        let dx = point.x - annotationMove.referencePoint.x
        let dy = point.y - annotationMove.referencePoint.y
        var updated = store.annotation(id: annotationMove.original.id) ?? annotationMove.original
        updated.points = annotationMove.original.points.map { originalPoint in
            CGPoint(x: originalPoint.x + dx, y: originalPoint.y + dy)
        }
        store.update(updated)
        NSCursor.closedHand.set()
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
        annotation(at: point, matching: { $0.kind == .text })
    }

    private func annotation(at point: CGPoint, matching predicate: (AnnotationItem) -> Bool = { _ in true }) -> AnnotationItem? {
        store.annotations
            .reversed()
            .first {
                $0.displayID == displayID &&
                    predicate($0) &&
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
        let previousBounds = laserTrail.boundingRect
        laserTrail.append(point, at: Date())

        if laserTimer == nil {
            laserTimer = Timer.scheduledTimer(
                timeInterval: 1 / 30,
                target: self,
                selector: #selector(trimLaserTrail(_:)),
                userInfo: nil,
                repeats: true
            )
        }

        setNeedsDisplay(previousBounds.union(laserTrail.boundingRect).expanded(by: 12))
    }

    @objc private func trimLaserTrail(_ timer: Timer) {
        let previousBounds = laserTrail.boundingRect
        laserTrail.trim(at: Date())
        setNeedsDisplay(previousBounds.union(laserTrail.boundingRect).expanded(by: 12))
        if laserTrail.points.isEmpty {
            timer.invalidate()
            laserTimer = nil
        }
    }
}

private struct TextMove {
    var original: AnnotationItem
    var dragOffset: CGPoint
}

private struct AnnotationMove {
    var original: AnnotationItem
    var referencePoint: CGPoint
}
