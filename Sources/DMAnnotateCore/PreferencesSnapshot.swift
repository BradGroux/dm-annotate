import CoreGraphics
import Foundation

public struct PreferencesSnapshot: Codable, Equatable, Sendable {
    public var theme: AppTheme
    public var toolbarOrientation: ToolbarOrientation
    public var toolbarCollapsed: Bool
    public var toolbarCompactMode: Bool
    public var toolbarOriginX: Double
    public var toolbarOriginY: Double
    public var toolbarOriginsByDisplayID: [String: CGPoint]
    public var toolbarPresets: [ToolbarPreset]
    public var highContrastToolbar: Bool
    public var toolbarTooltipsEnabled: Bool
    public var screenshotOutput: ScreenshotOutput
    public var screenshotFolder: String
    public var revealScreenshotAfterSave: Bool
    public var confirmScreenshotFilename: Bool
    public var defaultColor: RGBAColor
    public var quickColors: [RGBAColor]
    public var paletteColors: [RGBAColor]
    public var savedColorPalettes: [SavedColorPalette]
    public var visibleTools: Set<AnnotationTool>
    public var shortcuts: [ShortcutAction: String]
    public var whiteboardBackground: WhiteboardBackground

    private enum CodingKeys: String, CodingKey {
        case theme
        case toolbarOrientation
        case toolbarCollapsed
        case toolbarCompactMode
        case toolbarOriginX
        case toolbarOriginY
        case toolbarOriginsByDisplayID
        case toolbarPresets
        case highContrastToolbar
        case toolbarTooltipsEnabled
        case screenshotOutput
        case screenshotFolder
        case revealScreenshotAfterSave
        case confirmScreenshotFilename
        case defaultColor
        case quickColors
        case paletteColors
        case savedColorPalettes
        case visibleTools
        case shortcuts
        case whiteboardBackground
    }

    public init(
        theme: AppTheme = .system,
        toolbarOrientation: ToolbarOrientation = .vertical,
        toolbarCollapsed: Bool = false,
        toolbarCompactMode: Bool = false,
        toolbarOriginX: Double = 24,
        toolbarOriginY: Double = 220,
        toolbarOriginsByDisplayID: [String: CGPoint] = [:],
        toolbarPresets: [ToolbarPreset] = [],
        highContrastToolbar: Bool = false,
        toolbarTooltipsEnabled: Bool = true,
        screenshotOutput: ScreenshotOutput = .file,
        screenshotFolder: String = "~/Downloads",
        revealScreenshotAfterSave: Bool = false,
        confirmScreenshotFilename: Bool = false,
        defaultColor: RGBAColor = .red,
        quickColors: [RGBAColor] = RGBAColor.defaultQuickColors,
        paletteColors: [RGBAColor] = [],
        savedColorPalettes: [SavedColorPalette] = [],
        visibleTools: Set<AnnotationTool> = Set(AnnotationTool.allCases),
        shortcuts: [ShortcutAction: String] = ShortcutAction.defaultShortcuts,
        whiteboardBackground: WhiteboardBackground = .white
    ) {
        self.theme = theme
        self.toolbarOrientation = toolbarOrientation
        self.toolbarCollapsed = toolbarCollapsed
        self.toolbarCompactMode = toolbarCompactMode
        self.toolbarOriginX = toolbarOriginX
        self.toolbarOriginY = toolbarOriginY
        self.toolbarOriginsByDisplayID = toolbarOriginsByDisplayID
        self.toolbarPresets = toolbarPresets
        self.highContrastToolbar = highContrastToolbar
        self.toolbarTooltipsEnabled = toolbarTooltipsEnabled
        self.screenshotOutput = screenshotOutput
        self.screenshotFolder = screenshotFolder
        self.revealScreenshotAfterSave = revealScreenshotAfterSave
        self.confirmScreenshotFilename = confirmScreenshotFilename
        self.defaultColor = defaultColor
        self.paletteColors = paletteColors.isEmpty ? Self.paletteSeed(quickColors: quickColors) : Self.normalizedPaletteColors(paletteColors)
        self.quickColors = Array(self.paletteColors.prefix(4))
        self.savedColorPalettes = savedColorPalettes.map { palette in
            SavedColorPalette(id: palette.id, name: palette.name, colors: Self.normalizedPaletteColors(palette.colors))
        }
        self.visibleTools = Self.normalizedVisibleTools(visibleTools)
        self.shortcuts = Self.normalizedShortcuts(shortcuts)
        self.whiteboardBackground = whiteboardBackground
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let quickColors = try container.decodeIfPresent([RGBAColor].self, forKey: .quickColors) ?? RGBAColor.defaultQuickColors
        let paletteColors = try container.decodeIfPresent([RGBAColor].self, forKey: .paletteColors)
            ?? Self.paletteSeed(quickColors: quickColors)

        self.init(
            theme: try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system,
            toolbarOrientation: try container.decodeIfPresent(ToolbarOrientation.self, forKey: .toolbarOrientation) ?? .vertical,
            toolbarCollapsed: try container.decodeIfPresent(Bool.self, forKey: .toolbarCollapsed) ?? false,
            toolbarCompactMode: try container.decodeIfPresent(Bool.self, forKey: .toolbarCompactMode) ?? false,
            toolbarOriginX: try container.decodeIfPresent(Double.self, forKey: .toolbarOriginX) ?? 24,
            toolbarOriginY: try container.decodeIfPresent(Double.self, forKey: .toolbarOriginY) ?? 220,
            toolbarOriginsByDisplayID: try container.decodeIfPresent([String: CGPoint].self, forKey: .toolbarOriginsByDisplayID) ?? [:],
            toolbarPresets: try container.decodeIfPresent([ToolbarPreset].self, forKey: .toolbarPresets) ?? [],
            highContrastToolbar: try container.decodeIfPresent(Bool.self, forKey: .highContrastToolbar) ?? false,
            toolbarTooltipsEnabled: try container.decodeIfPresent(Bool.self, forKey: .toolbarTooltipsEnabled) ?? true,
            screenshotOutput: try container.decodeIfPresent(ScreenshotOutput.self, forKey: .screenshotOutput) ?? .file,
            screenshotFolder: try container.decodeIfPresent(String.self, forKey: .screenshotFolder) ?? "~/Downloads",
            revealScreenshotAfterSave: try container.decodeIfPresent(Bool.self, forKey: .revealScreenshotAfterSave) ?? false,
            confirmScreenshotFilename: try container.decodeIfPresent(Bool.self, forKey: .confirmScreenshotFilename) ?? false,
            defaultColor: try container.decodeIfPresent(RGBAColor.self, forKey: .defaultColor) ?? .red,
            quickColors: quickColors,
            paletteColors: paletteColors,
            savedColorPalettes: try container.decodeIfPresent([SavedColorPalette].self, forKey: .savedColorPalettes) ?? [],
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

    public static func normalizedPaletteColors(_ colors: [RGBAColor]) -> [RGBAColor] {
        let normalized = Array(colors.prefix(RGBAColor.maximumPaletteColorCount))
        return normalized.isEmpty ? RGBAColor.defaultPaletteColors : normalized
    }

    public static func paletteSeed(quickColors: [RGBAColor]) -> [RGBAColor] {
        var colors = Array(quickColors.prefix(4))

        for color in RGBAColor.defaultPaletteColors where colors.count < RGBAColor.maximumPaletteColorCount && !colors.contains(color) {
            colors.append(color)
        }

        return normalizedPaletteColors(colors)
    }

    public static func normalizedVisibleTools(_ tools: Set<AnnotationTool>) -> Set<AnnotationTool> {
        var normalized = tools

        normalized.insert(.cursor)

        if normalized.contains(.whiteboard) || normalized.contains(.blackboard) {
            normalized.insert(.whiteboard)
            normalized.insert(.blackboard)
        }

        if normalized.count == 1 {
            normalized.insert(.pen)
        }

        return normalized
    }

    public static func normalizedShortcuts(_ shortcuts: [ShortcutAction: String]) -> [ShortcutAction: String] {
        var normalized = ShortcutAction.defaultShortcuts

        for (action, shortcut) in shortcuts {
            normalized[action] = shortcut.isEmpty ? "" : ShortcutText.normalize(shortcut)
        }

        return normalized
    }

    public mutating func setPaletteColor(_ color: RGBAColor, at index: Int) {
        guard paletteColors.indices.contains(index) else { return }

        paletteColors[index] = color
        syncQuickColors()
    }

    @discardableResult
    public mutating func appendPaletteColor(_ color: RGBAColor) -> Bool {
        guard paletteColors.count < RGBAColor.maximumPaletteColorCount else { return false }

        paletteColors.append(color)
        syncQuickColors()
        return true
    }

    public mutating func removePaletteColor(at index: Int) {
        guard paletteColors.count > 1, paletteColors.indices.contains(index) else { return }

        paletteColors.remove(at: index)
        syncQuickColors()
    }

    public mutating func saveCurrentPalette() {
        let colors = Self.normalizedPaletteColors(paletteColors)
        guard !savedColorPalettes.contains(where: { $0.colors == colors }) else { return }

        savedColorPalettes.append(
            SavedColorPalette(
                name: "Palette \(savedColorPalettes.count + 1)",
                colors: colors
            )
        )
    }

    public mutating func loadPalette(_ palette: SavedColorPalette) {
        paletteColors = Self.normalizedPaletteColors(palette.colors)
        syncQuickColors()
    }

    public mutating func saveToolbarPreset(named name: String) {
        toolbarPresets.append(
            ToolbarPreset(
                name: name,
                orientation: toolbarOrientation,
                collapsed: toolbarCollapsed,
                compactMode: toolbarCompactMode,
                origin: toolbarOrigin,
                originsByDisplayID: toolbarOriginsByDisplayID
            )
        )
    }

    public mutating func applyToolbarPreset(_ preset: ToolbarPreset, availableDisplayIDs: Set<String> = []) {
        toolbarOrientation = preset.orientation
        toolbarCollapsed = preset.collapsed
        toolbarCompactMode = preset.compactMode
        toolbarOrigin = preset.origin

        if availableDisplayIDs.isEmpty {
            toolbarOriginsByDisplayID = preset.originsByDisplayID
        } else {
            toolbarOriginsByDisplayID = preset.originsByDisplayID.filter { availableDisplayIDs.contains($0.key) }
        }
    }

    public mutating func deleteToolbarPreset(id: ToolbarPreset.ID) {
        toolbarPresets.removeAll { $0.id == id }
    }

    private mutating func syncQuickColors() {
        quickColors = Array(paletteColors.prefix(4))
    }
}

public extension ShortcutAction {
    static let defaultShortcuts: [ShortcutAction: String] = [
        .toggleToolbarCollapsed: "option+command+t",
        .toggleToolbarOrientation: "option+command+o",
        .toggleToolbarCompactMode: "option+command+m",
        .findToolbar: "option+command+f",
        .toggleAnnotationMode: "option+command+a",
        .cursorMode: "escape",
        .selectTool: "control+option+s",
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
