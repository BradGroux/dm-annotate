import Combine
import CoreGraphics
import Foundation

@MainActor
public final class AnnotationStore: ObservableObject {
    nonisolated public static let supportedStrokeWidths: [CGFloat] = [1, 2, 3, 5, 8, 10, 12, 16, 20, 24, 32, 64]
    nonisolated public static let minimumStrokeWidth: CGFloat = 1
    nonisolated public static let maximumStrokeWidth: CGFloat = 64
    nonisolated public static let supportedTextFontSizes: [CGFloat] = [12, 14, 16, 18, 20, 24, 28, 32, 40, 48, 64, 96]
    nonisolated public static let minimumTextFontSize: CGFloat = 8
    nonisolated public static let maximumTextFontSize: CGFloat = 160
    nonisolated public static let maximumAnnotationCount = 10_000
    nonisolated public static let maximumUndoDepth = 200

    @Published public private(set) var annotations: [AnnotationItem]
    @Published public var activeTool: AnnotationTool
    @Published public var currentColor: RGBAColor
    @Published public var strokeWidth: CGFloat
    @Published public var textFontSize: CGFloat
    @Published public var textFontWeight: TextFontWeight
    @Published public var isVisible: Bool
    @Published public var annotationsLocked: Bool
    @Published public var whiteboardModeEnabled: Bool
    @Published public var whiteboardBackground: WhiteboardBackground
    @Published public private(set) var selectedAnnotationID: AnnotationItem.ID?
    @Published public private(set) var canUndo: Bool
    @Published public private(set) var canRedo: Bool

    private var undoStack: [HistoryAction]
    private var redoStack: [HistoryAction]

    public init(
        annotations: [AnnotationItem] = [],
        activeTool: AnnotationTool = .cursor,
        currentColor: RGBAColor = .red,
        strokeWidth: CGFloat = 3,
        textFontSize: CGFloat = 24,
        textFontWeight: TextFontWeight = .semibold,
        isVisible: Bool = true,
        annotationsLocked: Bool = false,
        whiteboardModeEnabled: Bool = false,
        whiteboardBackground: WhiteboardBackground = .white
    ) {
        self.annotations = annotations
        self.activeTool = activeTool
        self.currentColor = currentColor
        self.strokeWidth = Self.normalizedStrokeWidth(strokeWidth)
        self.textFontSize = Self.normalizedTextFontSize(textFontSize)
        self.textFontWeight = textFontWeight
        self.isVisible = isVisible
        self.annotationsLocked = annotationsLocked
        self.whiteboardModeEnabled = whiteboardModeEnabled
        self.whiteboardBackground = whiteboardBackground
        selectedAnnotationID = nil
        undoStack = []
        redoStack = []
        canUndo = false
        canRedo = false
    }

    public func setActiveTool(_ tool: AnnotationTool) {
        switch tool {
        case .cursor:
            activeTool = tool
            clearSelection()
            return
        case .whiteboard:
            toggleBoard(background: .white)
            return
        case .blackboard:
            toggleBoard(background: .black)
            return
        default:
            activeTool = tool
        }
    }

    public func decreaseStrokeWidth() {
        setStrokeWidth(relativeOffset: -1)
    }

    public func increaseStrokeWidth() {
        setStrokeWidth(relativeOffset: 1)
    }

    public func setStrokeWidth(_ width: CGFloat) {
        let normalized = Self.normalizedStrokeWidth(width)
        strokeWidth = normalized
        updateSelectedAnnotation { annotation in
            guard annotation.kind != .text else { return annotation }
            var next = annotation
            next.lineWidth = normalized
            return next
        }
    }

    public func setTextFontSize(_ size: CGFloat) {
        let normalized = Self.normalizedTextFontSize(size)
        textFontSize = normalized
        updateSelectedAnnotation { annotation in
            guard annotation.kind == .text else { return annotation }
            var next = annotation
            next.fontSize = normalized
            return next
        }
    }

    public func setTextFontWeight(_ weight: TextFontWeight) {
        textFontWeight = weight
        updateSelectedAnnotation { annotation in
            guard annotation.kind == .text else { return annotation }
            var next = annotation
            next.fontWeight = weight
            return next
        }
    }

    nonisolated public static func normalizedStrokeWidth(_ width: CGFloat) -> CGFloat {
        guard width.isFinite else { return minimumStrokeWidth }

        return Swift.min(
            Swift.max(width.rounded(.toNearestOrAwayFromZero), minimumStrokeWidth),
            maximumStrokeWidth
        )
    }

    nonisolated public static func normalizedTextFontSize(_ size: CGFloat) -> CGFloat {
        guard size.isFinite else { return 24 }

        return Swift.min(
            Swift.max(size.rounded(.toNearestOrAwayFromZero), minimumTextFontSize),
            maximumTextFontSize
        )
    }

    @discardableResult
    public func add(_ annotation: AnnotationItem) -> Bool {
        guard annotations.count < Self.maximumAnnotationCount else { return false }

        annotations.append(annotation)
        appendUndo(.add(annotation))
        redoStack.removeAll()
        updateHistoryFlags()
        return true
    }

    public func annotation(id: AnnotationItem.ID) -> AnnotationItem? {
        annotations.first { $0.id == id }
    }

    @discardableResult
    public func update(_ annotation: AnnotationItem) -> Bool {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return false }
        annotations[index] = annotation
        return true
    }

    public func recordMove(from previous: AnnotationItem, to next: AnnotationItem) {
        guard previous.id == next.id, previous != next else { return }
        guard update(next) else { return }

        appendUndo(.update(previous: previous, next: next))
        redoStack.removeAll()
        updateHistoryFlags()
    }

    public func erase(at point: CGPoint, radius: CGFloat, displayID: UInt32) {
        let removed = annotations.enumerated().compactMap { index, item -> RemovedAnnotation? in
            guard item.displayID == displayID, item.touches(point, radius: radius) else { return nil }
            return RemovedAnnotation(index: index, item: item)
        }
        guard !removed.isEmpty else { return }

        let removedIDs = Set(removed.map(\.item.id))
        annotations.removeAll { removedIDs.contains($0.id) }
        if let selectedAnnotationID, removedIDs.contains(selectedAnnotationID) {
            self.selectedAnnotationID = nil
        }
        appendUndo(.remove(removed))
        redoStack.removeAll()
        updateHistoryFlags()
    }

    public func clearAll() {
        guard !annotations.isEmpty else { return }

        let previous = annotations
        annotations.removeAll()
        selectedAnnotationID = nil
        appendUndo(.clear(previous))
        redoStack.removeAll()
        updateHistoryFlags()
    }

    public func undo() {
        guard let action = undoStack.popLast() else { return }

        switch action {
        case .add(let item):
            annotations.removeAll { $0.id == item.id }
            if selectedAnnotationID == item.id {
                selectedAnnotationID = nil
            }
        case .remove(let items):
            restoreRemoved(items)
        case .clear(let items):
            annotations = items
            selectedAnnotationID = nil
        case .update(let previous, let next):
            replace(id: next.id, with: previous)
        }

        appendRedo(action)
        updateHistoryFlags()
    }

    public func redo() {
        guard let action = redoStack.popLast() else { return }

        switch action {
        case .add(let item):
            if annotations.count < Self.maximumAnnotationCount {
                annotations.append(item)
            }
        case .remove(let items):
            let removedIDs = Set(items.map(\.item.id))
            annotations.removeAll { removedIDs.contains($0.id) }
            if let selectedAnnotationID, removedIDs.contains(selectedAnnotationID) {
                self.selectedAnnotationID = nil
            }
        case .clear:
            annotations.removeAll()
            selectedAnnotationID = nil
        case .update(let previous, let next):
            replace(id: previous.id, with: next)
        }

        appendUndo(action)
        updateHistoryFlags()
    }

    public func toggleVisibility() {
        isVisible.toggle()
    }

    public func toggleAnnotationLock() {
        annotationsLocked.toggle()
    }

    public var isControllingScreen: Bool {
        activeTool != .cursor || whiteboardModeEnabled
    }

    public func exitScreenControls() {
        activeTool = .cursor
        whiteboardModeEnabled = false
        clearSelection()
    }

    public func setQuickColor(_ color: RGBAColor) {
        setCurrentColor(color)
    }

    public func setCurrentColor(_ color: RGBAColor) {
        currentColor = color
        updateSelectedAnnotation { annotation in
            var next = annotation
            next.color = color
            return next
        }
    }

    public func selectAnnotation(id: AnnotationItem.ID?) {
        guard let id else {
            clearSelection()
            return
        }

        selectedAnnotationID = annotations.contains { $0.id == id } ? id : nil
    }

    public func clearSelection() {
        selectedAnnotationID = nil
    }

    public var selectedAnnotation: AnnotationItem? {
        selectedAnnotationID.flatMap { annotation(id: $0) }
    }

    public var undoDepth: Int {
        undoStack.count
    }

    public var redoDepth: Int {
        redoStack.count
    }

    @discardableResult
    public func deleteSelectedAnnotation() -> Bool {
        guard let selectedAnnotationID,
              let index = annotations.firstIndex(where: { $0.id == selectedAnnotationID }) else {
            return false
        }

        let removed = RemovedAnnotation(index: index, item: annotations[index])
        annotations.remove(at: index)
        self.selectedAnnotationID = nil
        appendUndo(.remove([removed]))
        redoStack.removeAll()
        updateHistoryFlags()
        return true
    }

    public func sessionDocument(createdAt: Date = Date()) -> AnnotationSessionDocument {
        AnnotationSessionDocument(
            createdAt: createdAt,
            annotations: annotations,
            currentColor: currentColor,
            strokeWidth: strokeWidth,
            textFontSize: textFontSize,
            textFontWeight: textFontWeight,
            isVisible: isVisible,
            annotationsLocked: annotationsLocked,
            whiteboardModeEnabled: whiteboardModeEnabled,
            whiteboardBackground: whiteboardBackground
        )
    }

    public func loadSession(_ session: AnnotationSessionDocument) {
        annotations = session.annotations
        activeTool = .cursor
        currentColor = session.currentColor
        strokeWidth = Self.normalizedStrokeWidth(session.strokeWidth)
        textFontSize = Self.normalizedTextFontSize(session.textFontSize)
        textFontWeight = session.textFontWeight
        isVisible = session.isVisible
        annotationsLocked = session.annotationsLocked
        whiteboardModeEnabled = session.whiteboardModeEnabled
        whiteboardBackground = session.whiteboardBackground
        selectedAnnotationID = nil
        undoStack.removeAll()
        redoStack.removeAll()
        updateHistoryFlags()
    }

    private func setStrokeWidth(relativeOffset: Int) {
        let widths = Self.supportedStrokeWidths
        let currentIndex = widths.firstIndex(of: strokeWidth) ?? nearestStrokeWidthIndex(in: widths)
        let nextIndex = min(max(currentIndex + relativeOffset, widths.startIndex), widths.index(before: widths.endIndex))
        setStrokeWidth(widths[nextIndex])
    }

    private func nearestStrokeWidthIndex(in widths: [CGFloat]) -> Int {
        widths.enumerated().min { lhs, rhs in
            abs(lhs.element - strokeWidth) < abs(rhs.element - strokeWidth)
        }?.offset ?? 1
    }

    private func toggleBoard(background: WhiteboardBackground) {
        if whiteboardModeEnabled, whiteboardBackground == background {
            whiteboardModeEnabled = false
            return
        }

        whiteboardBackground = background
        whiteboardModeEnabled = true
        if activeTool == .cursor {
            activeTool = .pen
        }
    }

    private func updateHistoryFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func appendUndo(_ action: HistoryAction) {
        undoStack.append(action)
        trimHistory(&undoStack)
    }

    private func appendRedo(_ action: HistoryAction) {
        redoStack.append(action)
        trimHistory(&redoStack)
    }

    private func trimHistory(_ stack: inout [HistoryAction]) {
        guard stack.count > Self.maximumUndoDepth else { return }
        stack.removeFirst(stack.count - Self.maximumUndoDepth)
    }

    private func replace(id: AnnotationItem.ID, with annotation: AnnotationItem) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        annotations[index] = annotation
    }

    private func updateSelectedAnnotation(_ transform: (AnnotationItem) -> AnnotationItem) {
        guard let selectedAnnotationID,
              let previous = annotation(id: selectedAnnotationID) else {
            return
        }

        let next = transform(previous)
        guard previous != next else { return }
        recordMove(from: previous, to: next)
    }

    private func restoreRemoved(_ items: [RemovedAnnotation]) {
        for removed in items.sorted(by: { $0.index < $1.index }) {
            let insertionIndex = min(removed.index, annotations.endIndex)
            annotations.insert(removed.item, at: insertionIndex)
        }
    }
}

private struct RemovedAnnotation {
    var index: Int
    var item: AnnotationItem
}

private enum HistoryAction {
    case add(AnnotationItem)
    case remove([RemovedAnnotation])
    case clear([AnnotationItem])
    case update(previous: AnnotationItem, next: AnnotationItem)
}
