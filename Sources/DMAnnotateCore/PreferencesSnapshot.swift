import CoreGraphics
import Foundation

public struct PreferencesSnapshot: Codable, Equatable, Sendable {
    public var theme: AppTheme
    public var toolbarOrientation: ToolbarOrientation
    public var toolbarCollapsed: Bool
    public var toolbarOriginX: Double
    public var toolbarOriginY: Double
    public var toolbarOriginsByDisplayID: [String: CGPoint]
    public var highContrastToolbar: Bool
    public var screenshotOutput: ScreenshotOutput
    public var screenshotFolder: String
    public var revealScreenshotAfterSave: Bool
    public var confirmScreenshotFilename: Bool
    public var defaultColor: RGBAColor
    public var quickColors: [RGBAColor]
    public var visibleTools: Set<AnnotationTool>
    public var shortcuts: [ShortcutAction: String]
    public var whiteboardBackground: WhiteboardBackground

    private enum CodingKeys: String, CodingKey {
        case theme
        case toolbarOrientation
        case toolbarCollapsed
        case toolbarOriginX
        case toolbarOriginY
        case toolbarOriginsByDisplayID
        case highContrastToolbar
        case screenshotOutput
        case screenshotFolder
        case revealScreenshotAfterSave
        case confirmScreenshotFilename
        case defaultColor
        case quickColors
        case visibleTools
        case shortcuts
        case whiteboardBackground
    }

    public init(
        theme: AppTheme = .system,
        toolbarOrientation: ToolbarOrientation = .vertical,
        toolbarCollapsed: Bool = false,
        toolbarOriginX: Double = 24,
        toolbarOriginY: Double = 220,
        toolbarOriginsByDisplayID: [String: CGPoint] = [:],
        highContrastToolbar: Bool = false,
        screenshotOutput: ScreenshotOutput = .file,
        screenshotFolder: String = "~/Downloads",
        revealScreenshotAfterSave: Bool = false,
        confirmScreenshotFilename: Bool = false,
        defaultColor: RGBAColor = .red,
        quickColors: [RGBAColor] = RGBAColor.defaultQuickColors,
        visibleTools: Set<AnnotationTool> = Set(AnnotationTool.allCases),
        shortcuts: [ShortcutAction: String] = ShortcutAction.defaultShortcuts,
        whiteboardBackground: WhiteboardBackground = .white
    ) {
        self.theme = theme
        self.toolbarOrientation = toolbarOrientation
        self.toolbarCollapsed = toolbarCollapsed
        self.toolbarOriginX = toolbarOriginX
        self.toolbarOriginY = toolbarOriginY
        self.toolbarOriginsByDisplayID = toolbarOriginsByDisplayID
        self.highContrastToolbar = highContrastToolbar
        self.screenshotOutput = screenshotOutput
        self.screenshotFolder = screenshotFolder
        self.revealScreenshotAfterSave = revealScreenshotAfterSave
        self.confirmScreenshotFilename = confirmScreenshotFilename
        self.defaultColor = defaultColor
        self.quickColors = Array(quickColors.prefix(4))
        while self.quickColors.count < 4 {
            self.quickColors.append(.red)
        }
        self.visibleTools = visibleTools
        self.shortcuts = shortcuts.mapValues(ShortcutText.normalize)
        self.whiteboardBackground = whiteboardBackground
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            theme: try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system,
            toolbarOrientation: try container.decodeIfPresent(ToolbarOrientation.self, forKey: .toolbarOrientation) ?? .vertical,
            toolbarCollapsed: try container.decodeIfPresent(Bool.self, forKey: .toolbarCollapsed) ?? false,
            toolbarOriginX: try container.decodeIfPresent(Double.self, forKey: .toolbarOriginX) ?? 24,
            toolbarOriginY: try container.decodeIfPresent(Double.self, forKey: .toolbarOriginY) ?? 220,
            toolbarOriginsByDisplayID: try container.decodeIfPresent([String: CGPoint].self, forKey: .toolbarOriginsByDisplayID) ?? [:],
            highContrastToolbar: try container.decodeIfPresent(Bool.self, forKey: .highContrastToolbar) ?? false,
            screenshotOutput: try container.decodeIfPresent(ScreenshotOutput.self, forKey: .screenshotOutput) ?? .file,
            screenshotFolder: try container.decodeIfPresent(String.self, forKey: .screenshotFolder) ?? "~/Downloads",
            revealScreenshotAfterSave: try container.decodeIfPresent(Bool.self, forKey: .revealScreenshotAfterSave) ?? false,
            confirmScreenshotFilename: try container.decodeIfPresent(Bool.self, forKey: .confirmScreenshotFilename) ?? false,
            defaultColor: try container.decodeIfPresent(RGBAColor.self, forKey: .defaultColor) ?? .red,
            quickColors: try container.decodeIfPresent([RGBAColor].self, forKey: .quickColors) ?? RGBAColor.defaultQuickColors,
            visibleTools: try container.decodeIfPresent(Set<AnnotationTool>.self, forKey: .visibleTools) ?? Set(AnnotationTool.allCases),
            shortcuts: try container.decodeIfPresent([ShortcutAction: String].self, forKey: .shortcuts) ?? ShortcutAction.defaultShortcuts,
            whiteboardBackground: try container.decodeIfPresent(WhiteboardBackground.self, forKey: .whiteboardBackground) ?? .white
        )
    }

    public var toolbarOrigin: CGPoint {
        get { CGPoint(x: toolbarOriginX, y: toolbarOriginY) }
        set {
            toolbarOriginX = newValue.x
            toolbarOriginY = newValue.y
        }
    }
}

public extension ShortcutAction {
    static let defaultShortcuts: [ShortcutAction: String] = [
        .toggleToolbarCollapsed: "option+command+t",
        .toggleToolbarOrientation: "option+command+o",
        .findToolbar: "option+command+f",
        .toggleAnnotationMode: "option+command+a",
        .cursorMode: "escape",
        .selectPen: "control+option+p",
        .selectHighlighter: "control+option+h",
        .selectEraser: "control+option+e",
        .selectLine: "control+option+l",
        .selectRectangle: "control+option+r",
        .selectEllipse: "control+option+o",
        .selectArrow: "control+option+a",
        .selectText: "control+option+t",
        .selectLaser: "control+option+d",
        .toggleWhiteboard: "control+option+w",
        .toggleAnnotationLock: "option+command+l",
        .toggleAnnotationVisibility: "option+command+v",
        .undo: "command+z",
        .redo: "command+shift+z",
        .quickColor1: "command+1",
        .quickColor2: "command+2",
        .quickColor3: "command+3",
        .quickColor4: "command+4",
        .customColor: "control+option+c",
        .decreaseStrokeWidth: "command+-",
        .increaseStrokeWidth: "command+=",
        .clearAll: "option+command+c",
        .screenshot: "option+command+s",
        .copyScreenshot: "option+shift+command+c",
        .saveScreenshot: "option+shift+command+s",
        .regionScreenshot: "option+command+r",
        .revealLastScreenshot: "option+shift+command+r",
        .showPermissions: "option+command+p",
        .showSettings: "command+,",
        .commandPalette: "command+k"
    ]
}
