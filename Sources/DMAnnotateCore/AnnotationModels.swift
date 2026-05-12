import CoreGraphics
import Foundation

public enum AnnotationTool: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case cursor
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
    case findToolbar
    case toggleAnnotationMode
    case cursorMode
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
        case .findToolbar: "Find Toolbar"
        case .toggleAnnotationMode: "Toggle Annotation Mode"
        case .cursorMode: "Cursor Mode"
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

public struct AnnotationItem: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var displayID: UInt32
    public var kind: AnnotationKind
    public var points: [CGPoint]
    public var color: RGBAColor
    public var lineWidth: CGFloat
    public var text: String
    public var fontSize: CGFloat

    public init(
        id: UUID = UUID(),
        displayID: UInt32,
        kind: AnnotationKind,
        points: [CGPoint],
        color: RGBAColor,
        lineWidth: CGFloat,
        text: String = "",
        fontSize: CGFloat = 24
    ) {
        self.id = id
        self.displayID = displayID
        self.kind = kind
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
        self.text = text
        self.fontSize = fontSize
    }

    public var boundingRect: CGRect {
        switch kind {
        case .pen, .highlighter:
            return points.boundingRect.expanded(by: max(lineWidth, 8))
        case .line, .rectangle, .ellipse, .arrow:
            return points.boundingRect.expanded(by: max(lineWidth, 8))
        case .text:
            guard let point = points.first else { return .zero }
            let width = max(CGFloat(text.count) * fontSize * 0.6, 64)
            let height = fontSize * 1.4
            return CGRect(x: point.x, y: point.y, width: width, height: height)
                .expanded(by: 8)
        }
    }

    public func touches(_ point: CGPoint, radius: CGFloat) -> Bool {
        guard !points.isEmpty else { return false }

        switch kind {
        case .pen, .highlighter:
            return points.lineSegmentsContain(point, tolerance: max(radius, lineWidth))
        case .line, .arrow:
            return points.lineSegmentsContain(point, tolerance: max(radius, lineWidth))
        case .rectangle, .ellipse, .text:
            return boundingRect.expanded(by: radius).contains(point)
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

    func lineSegmentsContain(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        guard count > 1 else {
            return first.map { hypot($0.x - point.x, $0.y - point.y) <= tolerance } ?? false
        }

        for index in 0..<(count - 1) {
            let distance = distanceFrom(point, toSegmentStart: self[index], end: self[index + 1])
            if distance <= tolerance {
                return true
            }
        }

        return false
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
