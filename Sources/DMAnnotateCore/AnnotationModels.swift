import CoreGraphics
import Foundation

public enum AnnotationTool: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case cursor
    case select
    case pen
    case highlighter
    case eraser
    case line
    case rectangle
    case ellipse
    case arrow
    case text
    case laser
    case whiteboard
    case blackboard

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cursor: "Cursor"
        case .select: "Select"
        case .pen: "Pen"
        case .highlighter: "Highlighter"
        case .eraser: "Eraser"
        case .line: "Line"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .arrow: "Arrow"
        case .text: "Text"
        case .laser: "Laser"
        case .whiteboard: "Whiteboard"
        case .blackboard: "Blackboard"
        }
    }
}

public enum AnnotationKind: String, Codable, Equatable, Hashable, Sendable {
    case pen
    case highlighter
    case line
    case rectangle
    case ellipse
    case arrow
    case text
}

public enum ToolbarOrientation: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case vertical
    case horizontal

    public var id: String { rawValue }
}

public enum AppTheme: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case system
    case dark
    case light

    public var id: String { rawValue }
}

public enum ScreenshotOutput: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case clipboard
    case file

    public var id: String { rawValue }
}

public enum ScreenshotDestination: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case preferred
    case clipboard
    case file

    public var id: String { rawValue }
}

public enum ScreenshotRenderMode: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case flattened
    case annotationsOnly

    public var id: String { rawValue }
}

public enum WhiteboardBackground: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case white
    case black
    case lightGrid
    case darkGrid

    public var id: String { rawValue }
}

public enum ShortcutAction: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case toggleToolbarCollapsed
    case toggleToolbarOrientation
    case toggleToolbarCompactMode
    case findToolbar
    case toggleAnnotationMode
    case cursorMode
    case selectTool
    case selectPen
    case selectHighlighter
    case selectEraser
    case selectLine
    case selectRectangle
    case selectEllipse
    case selectArrow
    case selectText
    case selectLaser
    case toggleWhiteboard
    case toggleAnnotationLock
    case toggleAnnotationVisibility
    case undo
    case redo
    case quickColor1
    case quickColor2
    case quickColor3
    case quickColor4
    case customColor
    case decreaseStrokeWidth
    case increaseStrokeWidth
    case clearAll
    case screenshot
    case copyScreenshot
    case saveScreenshot
    case regionScreenshot
    case revealLastScreenshot
    case showPermissions
    case showSettings
    case commandPalette

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .toggleToolbarCollapsed: "Collapse/Expand Toolbar"
        case .toggleToolbarOrientation: "Switch Toolbar Orientation"
        case .toggleToolbarCompactMode: "Compact Presenter Mode"
        case .findToolbar: "Find Toolbar"
        case .toggleAnnotationMode: "Toggle Annotation Mode"
        case .cursorMode: "Cursor Mode"
        case .selectTool: "Select Tool"
        case .selectPen: "Pen Tool"
        case .selectHighlighter: "Highlighter Tool"
        case .selectEraser: "Eraser Tool"
        case .selectLine: "Line Tool"
        case .selectRectangle: "Rectangle Tool"
        case .selectEllipse: "Circle Tool"
        case .selectArrow: "Arrow Tool"
        case .selectText: "Text Tool"
        case .selectLaser: "Laser Pointer"
        case .toggleWhiteboard: "Whiteboard Mode"
        case .toggleAnnotationLock: "Lock/Unlock Annotations"
        case .toggleAnnotationVisibility: "Show/Hide Annotations"
        case .undo: "Undo"
        case .redo: "Redo"
        case .quickColor1: "Quick Color 1"
        case .quickColor2: "Quick Color 2"
        case .quickColor3: "Quick Color 3"
        case .quickColor4: "Quick Color 4"
        case .customColor: "Custom Color"
        case .decreaseStrokeWidth: "Decrease Stroke Width"
        case .increaseStrokeWidth: "Increase Stroke Width"
        case .clearAll: "Clear All"
        case .screenshot: "Screenshot"
        case .copyScreenshot: "Copy Screenshot"
        case .saveScreenshot: "Save Screenshot"
        case .regionScreenshot: "Region Screenshot"
        case .revealLastScreenshot: "Reveal Last Screenshot"
        case .showPermissions: "Permissions"
        case .showSettings: "Settings"
        case .commandPalette: "Command Palette"
        }
    }
}

public extension ShortcutAction {
    static func toolAction(for tool: AnnotationTool) -> ShortcutAction? {
        switch tool {
        case .cursor: .cursorMode
        case .select: .selectTool
        case .pen: .selectPen
        case .highlighter: .selectHighlighter
        case .eraser: .selectEraser
        case .line: .selectLine
        case .rectangle: .selectRectangle
        case .ellipse: .selectEllipse
        case .arrow: .selectArrow
        case .text: .selectText
        case .laser: .selectLaser
        case .whiteboard: .toggleWhiteboard
        case .blackboard: nil
        }
    }
}

public struct RGBAColor: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public var id: String {
        "\(red)-\(green)-\(blue)-\(alpha)"
    }

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let red = RGBAColor(red: 0.95, green: 0.18, blue: 0.24)
    public static let amber = RGBAColor(red: 0.98, green: 0.65, blue: 0.14)
    public static let yellow = RGBAColor(red: 1.0, green: 0.86, blue: 0.2)
    public static let green = RGBAColor(red: 0.18, green: 0.78, blue: 0.39)
    public static let cyan = RGBAColor(red: 0.12, green: 0.72, blue: 0.88)
    public static let blue = RGBAColor(red: 0.16, green: 0.45, blue: 0.96)
    public static let purple = RGBAColor(red: 0.55, green: 0.36, blue: 0.95)
    public static let pink = RGBAColor(red: 0.95, green: 0.28, blue: 0.65)
    public static let white = RGBAColor(red: 1, green: 1, blue: 1)
    public static let black = RGBAColor(red: 0.02, green: 0.02, blue: 0.025)

    public static let maximumPaletteColorCount = 10
    public static let defaultQuickColors: [RGBAColor] = [.red, .yellow, .green, .blue]
    public static let defaultPaletteColors: [RGBAColor] = [
        .red, .yellow, .green, .blue, .purple,
        .pink, .cyan, .amber, .white, .black
    ]

    public static let palette: [RGBAColor] = defaultPaletteColors
}

public struct SavedColorPalette: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var colors: [RGBAColor]

    public init(id: UUID = UUID(), name: String, colors: [RGBAColor]) {
        self.id = id
        self.name = name
        self.colors = Array(colors.prefix(RGBAColor.maximumPaletteColorCount))
    }
}

public struct ToolbarPreset: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var orientation: ToolbarOrientation
    public var collapsed: Bool
    public var compactMode: Bool
    public var origin: CGPoint
    public var originsByDisplayID: [String: CGPoint]

    public init(
        id: UUID = UUID(),
        name: String,
        orientation: ToolbarOrientation,
        collapsed: Bool,
        compactMode: Bool,
        origin: CGPoint,
        originsByDisplayID: [String: CGPoint]
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Toolbar Preset" : name
        self.orientation = orientation
        self.collapsed = collapsed
        self.compactMode = compactMode
        self.origin = origin
        self.originsByDisplayID = originsByDisplayID
    }
}

public enum TextFontWeight: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case regular
    case medium
    case semibold
    case bold
    case heavy

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        case .bold: "Bold"
        case .heavy: "Heavy"
        }
    }
}

public struct AnnotationItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var displayID: UInt32
    public var kind: AnnotationKind
    public var points: [CGPoint]
    public var color: RGBAColor
    public var lineWidth: CGFloat
    public var text: String
    public var fontSize: CGFloat
    public var fontWeight: TextFontWeight

    public init(
        id: UUID = UUID(),
        displayID: UInt32,
        kind: AnnotationKind,
        points: [CGPoint],
        color: RGBAColor,
        lineWidth: CGFloat,
        text: String = "",
        fontSize: CGFloat = 24,
        fontWeight: TextFontWeight = .semibold
    ) {
        self.id = id
        self.displayID = displayID
        self.kind = kind
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
        self.text = text
        self.fontSize = fontSize
        self.fontWeight = fontWeight
    }

    public mutating func appendSessionPoint(_ point: CGPoint) {
        while points.count >= AnnotationSessionDocument.maximumPointsPerAnnotation {
            points = Self.geometryAwareReduction(of: points)
        }

        points.append(point)
    }

    private static func geometryAwareReduction(of points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var reduced = [points[0]]
        reduced.reserveCapacity((points.count / 2) + 1)
        let finalIndex = points.index(before: points.endIndex)
        var index = points.index(after: points.startIndex)

        while index < finalIndex {
            let pairedIndex = points.index(after: index)
            guard pairedIndex < finalIndex else {
                reduced.append(points[index])
                break
            }

            let firstImportance = geometricImportance(
                previous: points[points.index(before: index)],
                point: points[index],
                next: points[points.index(after: index)]
            )
            let secondImportance = geometricImportance(
                previous: points[points.index(before: pairedIndex)],
                point: points[pairedIndex],
                next: points[points.index(after: pairedIndex)]
            )
            reduced.append(firstImportance >= secondImportance ? points[index] : points[pairedIndex])
            index = points.index(index, offsetBy: 2)
        }

        reduced.append(points[finalIndex])
        return reduced
    }

    private static func geometricImportance(previous: CGPoint, point: CGPoint, next: CGPoint) -> CGFloat {
        let chordX = next.x - previous.x
        let chordY = next.y - previous.y
        let chordLengthSquared = (chordX * chordX) + (chordY * chordY)

        guard chordLengthSquared > 0 else {
            let offsetX = point.x - previous.x
            let offsetY = point.y - previous.y
            return (offsetX * offsetX) + (offsetY * offsetY)
        }

        let crossProduct = (point.x - previous.x) * chordY - (point.y - previous.y) * chordX
        return (crossProduct * crossProduct) / chordLengthSquared
    }

    public var boundingRect: CGRect {
        switch kind {
        case .pen:
            return points.boundingRect.expanded(by: max(lineWidth, 8))
        case .highlighter:
            return points.boundingRect.expanded(by: max(lineWidth * 3, 8))
        case .line, .rectangle, .ellipse:
            return points.boundingRect.expanded(by: max(lineWidth, 8))
        case .arrow:
            return points.boundingRect.expanded(by: max(lineWidth * 4, 18) + lineWidth)
        case .text:
            guard let point = points.first else { return .zero }
            let lines = text.components(separatedBy: .newlines)
            let longestLineCount = lines.map(\.count).max() ?? text.count
            let width = max(CGFloat(longestLineCount) * fontSize * 0.62, 64)
            let lineCount = max(lines.count, 1)
            let height = CGFloat(lineCount) * fontSize * 1.3
            return CGRect(x: point.x, y: point.y, width: width, height: height)
                .expanded(by: 8)
        }
    }

    public func touches(_ point: CGPoint, radius: CGFloat) -> Bool {
        hitTest(at: point, radius: radius).isHit
    }

    public func hitTest(at point: CGPoint, radius: CGFloat) -> AnnotationHitTestResult {
        guard !points.isEmpty else {
            return AnnotationHitTestResult(isHit: false, segmentsExamined: 0)
        }

        switch kind {
        case .pen, .highlighter:
            return points.lineSegmentHitTest(point, tolerance: max(radius, lineWidth))
        case .line, .arrow:
            return points.lineSegmentHitTest(point, tolerance: max(radius, lineWidth))
        case .rectangle, .ellipse, .text:
            return AnnotationHitTestResult(
                isHit: boundingRect.expanded(by: radius).contains(point),
                segmentsExamined: 0
            )
        }
    }
}

public struct AnnotationHitTestResult: Equatable, Sendable {
    public var isHit: Bool
    public var segmentsExamined: Int

    public init(isHit: Bool, segmentsExamined: Int) {
        self.isHit = isHit
        self.segmentsExamined = segmentsExamined
    }
}

public struct AnnotationSessionDocument: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let maximumEncodedByteCount: UInt64 = 10 * 1024 * 1024
    public static let maximumPointsPerAnnotation = 20_000
    public static let maximumTextLength = 8_000
    public static let maximumCoordinateMagnitude: CGFloat = 1_000_000

    public var version: Int
    public var createdAt: Date
    public var annotations: [AnnotationItem]
    public var currentColor: RGBAColor
    public var strokeWidth: CGFloat
    public var textFontSize: CGFloat
    public var textFontWeight: TextFontWeight
    public var isVisible: Bool
    public var annotationsLocked: Bool
    public var whiteboardModeEnabled: Bool
    public var whiteboardBackground: WhiteboardBackground

    public init(
        version: Int = currentVersion,
        createdAt: Date = Date(),
        annotations: [AnnotationItem],
        currentColor: RGBAColor,
        strokeWidth: CGFloat,
        textFontSize: CGFloat,
        textFontWeight: TextFontWeight,
        isVisible: Bool,
        annotationsLocked: Bool,
        whiteboardModeEnabled: Bool,
        whiteboardBackground: WhiteboardBackground
    ) {
        self.version = version
        self.createdAt = createdAt
        self.annotations = annotations
        self.currentColor = currentColor
        self.strokeWidth = AnnotationStore.normalizedStrokeWidth(strokeWidth)
        self.textFontSize = AnnotationStore.normalizedTextFontSize(textFontSize)
        self.textFontWeight = textFontWeight
        self.isVisible = isVisible
        self.annotationsLocked = annotationsLocked
        self.whiteboardModeEnabled = whiteboardModeEnabled
        self.whiteboardBackground = whiteboardBackground
    }

    public func validated() throws -> AnnotationSessionDocument {
        guard version == Self.currentVersion else {
            throw AnnotationSessionError.unsupportedVersion(version)
        }
        guard Self.isValidColor(currentColor) else {
            throw AnnotationSessionError.invalidCurrentColor
        }

        let nonEmptyAnnotations = annotations.filter { !$0.points.isEmpty }
        guard nonEmptyAnnotations.count <= AnnotationStore.maximumAnnotationCount else {
            throw AnnotationSessionError.tooManyAnnotations(
                count: nonEmptyAnnotations.count,
                maximum: AnnotationStore.maximumAnnotationCount
            )
        }

        var annotationIDs = Set<AnnotationItem.ID>()
        for annotation in nonEmptyAnnotations {
            guard annotationIDs.insert(annotation.id).inserted else {
                throw AnnotationSessionError.duplicateAnnotationID(annotation.id)
            }
        }

        var copy = self
        copy.annotations = try nonEmptyAnnotations.map(Self.validatedAnnotation)
        copy.strokeWidth = AnnotationStore.normalizedStrokeWidth(strokeWidth)
        copy.textFontSize = AnnotationStore.normalizedTextFontSize(textFontSize)
        return copy
    }

    public func retargetingMissingDisplays(
        availableDisplayIDs: Set<UInt32>,
        fallbackDisplayID: UInt32
    ) -> AnnotationSessionDocument {
        guard !availableDisplayIDs.isEmpty else { return self }

        var copy = self
        copy.annotations = annotations.map { annotation in
            guard !availableDisplayIDs.contains(annotation.displayID) else { return annotation }
            var retargeted = annotation
            retargeted.displayID = fallbackDisplayID
            return retargeted
        }
        return copy
    }

    public func encodedData() throws -> Data {
        let validatedDocument = try validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(validatedDocument)
        try Self.validateEncodedByteCount(UInt64(data.count))
        return data
    }

    public static func decode(from data: Data) throws -> AnnotationSessionDocument {
        try validateEncodedByteCount(UInt64(data.count))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AnnotationSessionDocument.self, from: data).validated()
    }

    public static func validateEncodedByteCount(_ byteCount: UInt64) throws {
        guard byteCount <= maximumEncodedByteCount else {
            throw AnnotationSessionError.fileTooLarge(byteCount: byteCount, maximum: maximumEncodedByteCount)
        }
    }

    private static func validatedAnnotation(_ annotation: AnnotationItem) throws -> AnnotationItem {
        guard annotation.points.count <= maximumPointsPerAnnotation else {
            throw AnnotationSessionError.tooManyPoints(
                annotationID: annotation.id,
                count: annotation.points.count,
                maximum: maximumPointsPerAnnotation
            )
        }

        guard annotation.points.allSatisfy({ point in
            point.x.isFinite &&
                point.y.isFinite &&
                abs(point.x) <= maximumCoordinateMagnitude &&
                abs(point.y) <= maximumCoordinateMagnitude
        }) else {
            throw AnnotationSessionError.invalidGeometry(annotationID: annotation.id)
        }

        guard isValidColor(annotation.color) else {
            throw AnnotationSessionError.invalidColor(annotationID: annotation.id)
        }

        guard annotation.lineWidth.isFinite, annotation.fontSize.isFinite else {
            throw AnnotationSessionError.invalidStyle(annotationID: annotation.id)
        }

        guard annotation.text.count <= maximumTextLength else {
            throw AnnotationSessionError.textTooLong(
                annotationID: annotation.id,
                count: annotation.text.count,
                maximum: maximumTextLength
            )
        }

        var copy = annotation
        copy.lineWidth = AnnotationStore.normalizedStrokeWidth(annotation.lineWidth)
        copy.fontSize = AnnotationStore.normalizedTextFontSize(annotation.fontSize)
        return copy
    }

    private static func isValidColor(_ color: RGBAColor) -> Bool {
        [color.red, color.green, color.blue, color.alpha].allSatisfy {
            $0.isFinite && (0...1).contains($0)
        }
    }
}

public enum AnnotationSessionError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case invalidCurrentColor
    case fileTooLarge(byteCount: UInt64, maximum: UInt64)
    case tooManyAnnotations(count: Int, maximum: Int)
    case duplicateAnnotationID(UUID)
    case tooManyPoints(annotationID: UUID, count: Int, maximum: Int)
    case invalidGeometry(annotationID: UUID)
    case invalidColor(annotationID: UUID)
    case invalidStyle(annotationID: UUID)
    case textTooLong(annotationID: UUID, count: Int, maximum: Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "Unsupported annotation session version \(version)."
        case .invalidCurrentColor:
            "Annotation session contains invalid current color values."
        case .fileTooLarge(let byteCount, let maximum):
            "Annotation session is too large (\(byteCount) bytes). Maximum supported size is \(maximum) bytes."
        case .tooManyAnnotations(let count, let maximum):
            "Annotation session contains \(count) annotations. Maximum supported count is \(maximum)."
        case .duplicateAnnotationID(let annotationID):
            "Annotation session contains duplicate annotation identifier \(annotationID)."
        case .tooManyPoints(let annotationID, let count, let maximum):
            "Annotation \(annotationID) contains \(count) points. Maximum supported count is \(maximum)."
        case .invalidGeometry(let annotationID):
            "Annotation \(annotationID) contains invalid geometry."
        case .invalidColor(let annotationID):
            "Annotation \(annotationID) contains invalid color values."
        case .invalidStyle(let annotationID):
            "Annotation \(annotationID) contains invalid style values."
        case .textTooLong(let annotationID, let count, let maximum):
            "Annotation \(annotationID) contains \(count) characters. Maximum supported count is \(maximum)."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unsupportedVersion:
            "Update Digital Meld Annotate or load a session exported by this version."
        case .fileTooLarge:
            "Remove some annotations or split the work across smaller session files, then save again."
        case .tooManyAnnotations:
            "Remove some annotations, then save again."
        case .duplicateAnnotationID:
            "Re-export the session from its source or remove the duplicate annotation entry, then try again."
        case .tooManyPoints:
            "Undo or clear the longest strokes and redraw them as shorter strokes, then save again."
        case .textTooLong:
            "Shorten the affected text annotation, then save again."
        case .invalidCurrentColor, .invalidColor, .invalidGeometry, .invalidStyle:
            "Remove or recreate the affected annotation, then save again."
        }
    }
}

public extension Array where Element == CGPoint {
    var boundingRect: CGRect {
        guard let first else { return .zero }
        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y

        for point in self {
            minX = Swift.min(minX, point.x)
            minY = Swift.min(minY, point.y)
            maxX = Swift.max(maxX, point.x)
            maxY = Swift.max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).standardized
    }

    func lineSegmentHitTest(
        _ point: CGPoint,
        tolerance: CGFloat,
        segmentRange: Range<Int>? = nil
    ) -> AnnotationHitTestResult {
        guard count > 1 else {
            return AnnotationHitTestResult(
                isHit: first.map { hypot($0.x - point.x, $0.y - point.y) <= tolerance } ?? false,
                segmentsExamined: 0
            )
        }

        let availableSegments = 0..<(count - 1)
        let requestedSegments = segmentRange ?? availableSegments
        let segments = requestedSegments.clamped(to: availableSegments)
        var examined = 0
        for index in segments {
            examined += 1
            let distance = distanceFrom(point, toSegmentStart: self[index], end: self[index + 1])
            if distance <= tolerance {
                return AnnotationHitTestResult(isHit: true, segmentsExamined: examined)
            }
        }

        return AnnotationHitTestResult(isHit: false, segmentsExamined: examined)
    }

    private func distanceFrom(_ point: CGPoint, toSegmentStart start: CGPoint, end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y

        guard dx != 0 || dy != 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }

        let t = Swift.max(0, Swift.min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / (dx * dx + dy * dy)))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(point.x - projection.x, point.y - projection.y)
    }
}

public extension CGRect {
    func expanded(by amount: CGFloat) -> CGRect {
        insetBy(dx: -amount, dy: -amount)
    }
}
