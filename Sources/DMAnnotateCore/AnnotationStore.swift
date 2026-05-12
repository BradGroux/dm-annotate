import Combine
import CoreGraphics
import Foundation

@MainActor
public final class AnnotationStore: ObservableObject {
    public static let supportedStrokeWidths: [CGFloat] = [1, 2, 3, 5, 8, 10, 12, 16, 20, 24, 32, 64]
    public static let minimumStrokeWidth: CGFloat = 1
    public static let maximumStrokeWidth: CGFloat = 64
    public static let supportedTextFontSizes: [CGFloat] = [12, 14, 16, 18, 20, 24, 28, 32, 40, 48, 64, 96]
    public static let minimumTextFontSize: CGFloat = 8
    public static let maximumTextFontSize: CGFloat = 160

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
        undoStack = []
        redoStack = []
        canUndo = false
        canRedo = false
    }

    public func setActiveTool(_ tool: AnnotationTool) {
        switch tool {
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
        strokeWidth = Self.normalizedStrokeWidth(width)
    }

    public func setTextFontSize(_ size: CGFloat) {
        textFontSize = Self.normalizedTextFontSize(size)
    }

    public func setTextFontWeight(_ weight: TextFontWeight) {
        textFontWeight = weight
    }

    public static func normalizedStrokeWidth(_ width: CGFloat) -> CGFloat {
        guard width.isFinite else { return minimumStrokeWidth }

        return Swift.min(
            Swift.max(width.rounded(.toNearestOrAwayFromZero), minimumStrokeWidth),
            maximumStrokeWidth
        )
    }

    public static func normalizedTextFontSize(_ size: CGFloat) -> CGFloat {
        guard size.isFinite else { return 24 }

        return Swift.min(
            Swift.max(size.rounded(.toNearestOrAwayFromZero), minimumTextFontSize),
            maximumTextFontSize
        )
    }

    public func add(_ annotation: AnnotationItem) {
        annotations.append(annotation)
        undoStack.append(.add(annotation))
        redoStack.removeAll()
        updateHistoryFlags()
    }

    public func annotation(id: AnnotationItem.ID) -> AnnotationItem? {
        annotations.first { $0.id == id }
    }

    public func update(_ annotation: AnnotationItem) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        annotations[index] = annotation
    }

    public func recordMove(from previous: AnnotationItem, to next: AnnotationItem) {
        guard previous.id == next.id, previous != next else { return }

        update(next)
        undoStack.append(.update(previous: previous, next: next))
        redoStack.removeAll()
        updateHistoryFlags()
    }

    public func erase(at point: CGPoint, radius: CGFloat, displayID: UInt32) {
        let removed = annotations.filter { $0.displayID == displayID && $0.touches(point, radius: radius) }
        guard !removed.isEmpty else { return }

        let removedIDs = Set(removed.map(\.id))
        annotations.removeAll { removedIDs.contains($0.id) }
        undoStack.append(.remove(removed))
        redoStack.removeAll()
        updateHistoryFlags()
    }

    public func clearAll() {
        guard !annotations.isEmpty else { return }

        let previous = annotations
        annotations.removeAll()
        undoStack.append(.clear(previous))
        redoStack.removeAll()
        updateHistoryFlags()
    }

    public func undo() {
        guard let action = undoStack.popLast() else { return }

        switch action {
        case .add(let item):
            annotations.removeAll { $0.id == item.id }
        case .remove(let items):
            annotations.append(contentsOf: items)
        case .clear(let items):
            annotations = items
        case .update(let previous, let next):
            replace(id: next.id, with: previous)
        }

        redoStack.append(action)
        updateHistoryFlags()
    }

    public func redo() {
        guard let action = redoStack.popLast() else { return }

        switch action {
        case .add(let item):
            annotations.append(item)
        case .remove(let items):
            let removedIDs = Set(items.map(\.id))
            annotations.removeAll { removedIDs.contains($0.id) }
        case .clear:
            annotations.removeAll()
        case .update(let previous, let next):
            replace(id: previous.id, with: next)
        }

        undoStack.append(action)
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
    }

    public func setQuickColor(_ color: RGBAColor) {
        currentColor = color
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

    private func replace(id: AnnotationItem.ID, with annotation: AnnotationItem) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        annotations[index] = annotation
    }
}

private enum HistoryAction {
    case add(AnnotationItem)
    case remove([AnnotationItem])
    case clear([AnnotationItem])
    case update(previous: AnnotationItem, next: AnnotationItem)
}
