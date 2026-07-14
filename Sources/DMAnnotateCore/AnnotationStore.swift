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
    private var annotationWork: [AnnotationItem.ID: AnnotationWorkIndex]
    private let annotationInvalidationSubject = PassthroughSubject<AnnotationInvalidation, Never>()

    public var annotationInvalidations: AnyPublisher<AnnotationInvalidation, Never> {
        annotationInvalidationSubject.eraseToAnyPublisher()
    }

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
        annotationWork = Self.makeWorkIndex(for: annotations)
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

    nonisolated public static func sessionSaveFailureMessage(for error: Error) -> String {
        let recoverySuggestion = (error as? LocalizedError)?.recoverySuggestion
        let recovery = recoverySuggestion.map { " \($0)" } ?? ""
        return "Annotation session save failed. No partial session was saved, and an existing file was left unchanged. " +
            "\(error.localizedDescription)\(recovery)"
    }

    @discardableResult
    public func add(_ annotation: AnnotationItem) -> Bool {
        guard annotations.count < Self.maximumAnnotationCount else { return false }

        annotations.append(annotation)
        annotationWork[annotation.id] = AnnotationWorkIndex(annotation: annotation)
        invalidate(annotation)
        appendUndo(.add(annotation))
        redoStack.removeAll()
        updateHistoryFlags()
        return true
    }

    public func annotation(id: AnnotationItem.ID) -> AnnotationItem? {
        annotations.first { $0.id == id }
    }

    public func annotations(intersecting rect: CGRect, displayID: UInt32) -> [AnnotationItem] {
        annotations.filter { annotation in
            annotation.displayID == displayID && (
                annotation.kind == .text || annotationWork[annotation.id]?.bounds.intersects(rect) == true
            )
        }
    }

    @discardableResult
    public func update(_ annotation: AnnotationItem) -> Bool {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return false }
        let previous = annotations[index]
        let previousBounds = annotationWork[previous.id]?.bounds ?? previous.boundingRect
        annotations[index] = annotation
        annotationWork[annotation.id] = AnnotationWorkIndex(annotation: annotation)
        if previous.kind == .text || annotation.kind == .text {
            annotationInvalidationSubject.send(.fullRedraw)
            return true
        }
        invalidate(
            annotationIDs: [annotation.id],
            regions: [
                AnnotationInvalidationRegion(displayID: previous.displayID, rect: previousBounds.expanded(by: 6)),
                AnnotationInvalidationRegion(displayID: annotation.displayID, rect: annotationWork[annotation.id]!.bounds.expanded(by: 6))
            ]
        )
        return true
    }

    public func recordMove(from previous: AnnotationItem, to next: AnnotationItem) {
        guard previous.id == next.id, previous != next else { return }
        if annotation(id: next.id) != next {
            guard update(next) else { return }
        }

        appendUndo(.update(previous: previous, next: next))
        redoStack.removeAll()
        updateHistoryFlags()
    }

    @discardableResult
    public func erase(at point: CGPoint, radius: CGFloat, displayID: UInt32) -> EraseWorkReport {
        let evaluation = evaluateErase(at: point, radius: radius, displayID: displayID)
        let removed = evaluation.removed
        let report = evaluation.report
        guard !removed.isEmpty else { return report }

        let removedIDs = Set(removed.map(\.item.id))
        invalidate(removed.map(\.item))
        annotations.removeAll { removedIDs.contains($0.id) }
        removedIDs.forEach { annotationWork.removeValue(forKey: $0) }
        if let selectedAnnotationID, removedIDs.contains(selectedAnnotationID) {
            self.selectedAnnotationID = nil
        }
        appendUndo(.remove(removed))
        redoStack.removeAll()
        updateHistoryFlags()
        return report
    }

    public func eraseWork(at point: CGPoint, radius: CGFloat, displayID: UInt32) -> EraseWorkReport {
        evaluateErase(at: point, radius: radius, displayID: displayID).report
    }

    public func clearAll() {
        guard !annotations.isEmpty else { return }

        let previous = annotations
        invalidate(previous)
        annotations.removeAll()
        annotationWork.removeAll(keepingCapacity: true)
        selectedAnnotationID = nil
        appendUndo(.clear(previous))
        redoStack.removeAll()
        updateHistoryFlags()
    }

    public func undo() {
        guard let action = undoStack.popLast() else { return }

        switch action {
        case .add(let item):
            invalidate(item)
            annotations.removeAll { $0.id == item.id }
            annotationWork.removeValue(forKey: item.id)
            if selectedAnnotationID == item.id {
                selectedAnnotationID = nil
            }
        case .remove(let items):
            restoreRemoved(items)
        case .clear(let items):
            annotations = items
            annotationWork = Self.makeWorkIndex(for: items)
            invalidate(items)
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
                annotationWork[item.id] = AnnotationWorkIndex(annotation: item)
                invalidate(item)
            }
        case .remove(let items):
            let removedIDs = Set(items.map(\.item.id))
            invalidate(items.map(\.item))
            annotations.removeAll { removedIDs.contains($0.id) }
            removedIDs.forEach { annotationWork.removeValue(forKey: $0) }
            if let selectedAnnotationID, removedIDs.contains(selectedAnnotationID) {
                self.selectedAnnotationID = nil
            }
        case .clear:
            let previous = annotations
            invalidate(previous)
            annotations.removeAll()
            annotationWork.removeAll(keepingCapacity: true)
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

        let previous = selectedAnnotation
        selectedAnnotationID = annotations.contains { $0.id == id } ? id : nil
        invalidateSelection(previous, selectedAnnotation)
    }

    public func clearSelection() {
        let previous = selectedAnnotation
        selectedAnnotationID = nil
        invalidateSelection(previous, nil)
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
        invalidate(removed.item)
        annotations.remove(at: index)
        annotationWork.removeValue(forKey: selectedAnnotationID)
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

    public func sessionData(createdAt: Date = Date()) throws -> Data {
        try sessionDocument(createdAt: createdAt).encodedData()
    }

    public func exportSession(to url: URL, createdAt: Date = Date()) throws {
        let data = try sessionData(createdAt: createdAt)
        try data.write(to: url, options: .atomic)
    }

    public func loadSession(_ session: AnnotationSessionDocument) {
        annotations = session.annotations
        annotationWork = Self.makeWorkIndex(for: session.annotations)
        annotationInvalidationSubject.send(.fullRedraw)
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
        let previous = annotations[index]
        let previousBounds = annotationWork[id]?.bounds ?? previous.boundingRect
        annotations[index] = annotation
        annotationWork.removeValue(forKey: id)
        annotationWork[annotation.id] = AnnotationWorkIndex(annotation: annotation)
        if previous.kind == .text || annotation.kind == .text {
            annotationInvalidationSubject.send(.fullRedraw)
            return
        }
        invalidate(
            annotationIDs: [annotation.id],
            regions: [
                AnnotationInvalidationRegion(displayID: previous.displayID, rect: previousBounds.expanded(by: 6)),
                AnnotationInvalidationRegion(displayID: annotation.displayID, rect: annotationWork[annotation.id]!.bounds.expanded(by: 6))
            ]
        )
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
            annotationWork[removed.item.id] = AnnotationWorkIndex(annotation: removed.item)
        }
        invalidate(items.map(\.item))
    }

    private func invalidate(_ annotations: AnnotationItem...) {
        invalidate(annotations)
    }

    private func invalidate(_ annotations: [AnnotationItem]) {
        guard !annotations.isEmpty else { return }
        if annotations.contains(where: { $0.kind == .text }) {
            annotationInvalidationSubject.send(.fullRedraw)
            return
        }
        invalidate(
            annotationIDs: Set(annotations.map(\.id)),
            regions: annotations.map { annotation in
                let bounds = annotationWork[annotation.id]?.bounds ?? annotation.boundingRect
                return AnnotationInvalidationRegion(displayID: annotation.displayID, rect: bounds.expanded(by: 6))
            }
        )
    }

    private func invalidate(
        annotationIDs: Set<AnnotationItem.ID>,
        regions: [AnnotationInvalidationRegion]
    ) {
        annotationInvalidationSubject.send(
            AnnotationInvalidation(
                annotationIDs: annotationIDs,
                regions: regions,
                requiresFullRedraw: false
            )
        )
    }

    private func invalidateSelection(_ previous: AnnotationItem?, _ next: AnnotationItem?) {
        invalidate([previous, next].compactMap { $0 })
    }

    private func evaluateErase(at point: CGPoint, radius: CGFloat, displayID: UInt32) -> EraseEvaluation {
        var boundsCandidates = 0
        var chunksExamined = 0
        var segmentsExamined = 0
        let removed = annotations.enumerated().compactMap { index, item -> RemovedAnnotation? in
            guard item.displayID == displayID,
                  let work = annotationWork[item.id],
                  work.bounds.expanded(by: radius).containsInclusively(point) else {
                return nil
            }
            boundsCandidates += 1

            let isHit: Bool
            if work.segmentChunks.isEmpty {
                let result = item.hitTest(at: point, radius: radius)
                segmentsExamined += result.segmentsExamined
                isHit = result.isHit
            } else {
                let tolerance = max(radius, item.lineWidth)
                var matched = false
                for chunk in work.segmentChunks {
                    chunksExamined += 1
                    guard chunk.bounds.expanded(by: tolerance).containsInclusively(point) else { continue }
                    let result = item.points.lineSegmentHitTest(
                        point,
                        tolerance: tolerance,
                        segmentRange: chunk.segmentRange
                    )
                    segmentsExamined += result.segmentsExamined
                    if result.isHit {
                        matched = true
                        break
                    }
                }
                isHit = matched
            }

            guard isHit else { return nil }
            return RemovedAnnotation(index: index, item: item)
        }

        return EraseEvaluation(
            report: EraseWorkReport(
                annotationsExamined: annotations.count,
                boundsCandidates: boundsCandidates,
                chunksExamined: chunksExamined,
                segmentsExamined: segmentsExamined,
                annotationsRemoved: removed.count
            ),
            removed: removed
        )
    }

    private nonisolated static func makeWorkIndex(for annotations: [AnnotationItem]) -> [AnnotationItem.ID: AnnotationWorkIndex] {
        var index: [AnnotationItem.ID: AnnotationWorkIndex] = [:]
        index.reserveCapacity(annotations.count)
        for annotation in annotations {
            index[annotation.id] = AnnotationWorkIndex(annotation: annotation)
        }
        return index
    }
}

public struct EraseWorkReport: Equatable, Sendable {
    public var annotationsExamined: Int
    public var boundsCandidates: Int
    public var chunksExamined: Int
    public var segmentsExamined: Int
    public var annotationsRemoved: Int

    public init(
        annotationsExamined: Int,
        boundsCandidates: Int,
        chunksExamined: Int,
        segmentsExamined: Int,
        annotationsRemoved: Int
    ) {
        self.annotationsExamined = annotationsExamined
        self.boundsCandidates = boundsCandidates
        self.chunksExamined = chunksExamined
        self.segmentsExamined = segmentsExamined
        self.annotationsRemoved = annotationsRemoved
    }
}

public struct AnnotationInvalidation: Equatable, Sendable {
    public var annotationIDs: Set<AnnotationItem.ID>
    public var regions: [AnnotationInvalidationRegion]
    public var requiresFullRedraw: Bool

    public init(
        annotationIDs: Set<AnnotationItem.ID>,
        regions: [AnnotationInvalidationRegion],
        requiresFullRedraw: Bool
    ) {
        self.annotationIDs = annotationIDs
        self.regions = regions
        self.requiresFullRedraw = requiresFullRedraw
    }

    public static let fullRedraw = AnnotationInvalidation(
        annotationIDs: [],
        regions: [],
        requiresFullRedraw: true
    )
}

public struct AnnotationInvalidationRegion: Equatable, Sendable {
    public var displayID: UInt32
    public var rect: CGRect

    public init(displayID: UInt32, rect: CGRect) {
        self.displayID = displayID
        self.rect = rect
    }
}

private struct EraseEvaluation {
    var report: EraseWorkReport
    var removed: [RemovedAnnotation]
}

private struct AnnotationWorkIndex {
    private static let segmentsPerChunk = 64

    var bounds: CGRect
    var segmentChunks: [SegmentChunk]

    init(annotation: AnnotationItem) {
        bounds = annotation.boundingRect
        guard annotation.kind == .pen || annotation.kind == .highlighter ||
                annotation.kind == .line || annotation.kind == .arrow,
              annotation.points.count > 1 else {
            segmentChunks = []
            return
        }

        let segmentCount = annotation.points.count - 1
        segmentChunks = stride(from: 0, to: segmentCount, by: Self.segmentsPerChunk).map { start in
            let end = min(start + Self.segmentsPerChunk, segmentCount)
            return SegmentChunk(
                bounds: Self.bounds(for: annotation.points, from: start, through: end),
                segmentRange: start..<end
            )
        }
    }

    private static func bounds(for points: [CGPoint], from start: Int, through end: Int) -> CGRect {
        var minX = points[start].x
        var minY = points[start].y
        var maxX = minX
        var maxY = minY
        for index in (start + 1)...end {
            minX = min(minX, points[index].x)
            minY = min(minY, points[index].y)
            maxX = max(maxX, points[index].x)
            maxY = max(maxY, points[index].y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

private struct SegmentChunk {
    var bounds: CGRect
    var segmentRange: Range<Int>
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

private extension CGRect {
    func containsInclusively(_ point: CGPoint) -> Bool {
        !isNull &&
            point.x >= minX && point.x <= maxX &&
            point.y >= minY && point.y <= maxY
    }
}
