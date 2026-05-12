import CoreGraphics
import Foundation
import Testing
@testable import DMAnnotateCore

@MainActor
@Test func addUndoRedoClearRoundTrip() {
    let store = AnnotationStore()
    let item = AnnotationItem(
        displayID: 1,
        kind: .pen,
        points: [CGPoint(x: 0, y: 0), CGPoint(x: 20, y: 20)],
        color: .red,
        lineWidth: 3
    )

    store.add(item)
    #expect(store.annotations == [item])
    #expect(store.canUndo)
    #expect(!store.canRedo)

    store.undo()
    #expect(store.annotations.isEmpty)
    #expect(store.canRedo)

    store.redo()
    #expect(store.annotations == [item])

    store.clearAll()
    #expect(store.annotations.isEmpty)

    store.undo()
    #expect(store.annotations == [item])
}

@MainActor
@Test func eraseOnlyRemovesTouchedAnnotationsOnSameDisplay() {
    let store = AnnotationStore()
    let touched = AnnotationItem(
        displayID: 1,
        kind: .line,
        points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)],
        color: .red,
        lineWidth: 3
    )
    let otherDisplay = AnnotationItem(
        displayID: 2,
        kind: .line,
        points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)],
        color: .blue,
        lineWidth: 3
    )
    let untouched = AnnotationItem(
        displayID: 1,
        kind: .rectangle,
        points: [CGPoint(x: 200, y: 200), CGPoint(x: 260, y: 260)],
        color: .green,
        lineWidth: 3
    )

    store.add(touched)
    store.add(otherDisplay)
    store.add(untouched)

    store.erase(at: CGPoint(x: 50, y: 2), radius: 8, displayID: 1)

    #expect(store.annotations == [otherDisplay, untouched])

    store.undo()
    #expect(store.annotations.contains(touched))
}

@Test func preferencesDefaultShortcutsMatchPRD() {
    let snapshot = PreferencesSnapshot()

    #expect(snapshot.shortcuts[.toggleAnnotationMode] == "option+command+a")
    #expect(snapshot.shortcuts[.cursorMode] == "escape")
    #expect(snapshot.shortcuts[.toggleToolbarCollapsed] == "option+command+t")
    #expect(snapshot.shortcuts[.toggleToolbarOrientation] == "option+command+o")
    #expect(snapshot.shortcuts[.findToolbar] == "option+command+f")
    #expect(snapshot.shortcuts[.toggleAnnotationLock] == "option+command+l")
    #expect(snapshot.shortcuts[.toggleAnnotationVisibility] == "option+command+v")
    #expect(snapshot.shortcuts[.undo] == "command+z")
    #expect(snapshot.shortcuts[.redo] == "shift+command+z")
    #expect(snapshot.shortcuts[.customColor] == "control+option+c")
    #expect(snapshot.shortcuts[.clearAll] == "option+command+c")
    #expect(snapshot.shortcuts[.screenshot] == "option+command+s")
    #expect(snapshot.shortcuts[.copyScreenshot] == "option+shift+command+c")
    #expect(snapshot.shortcuts[.saveScreenshot] == "option+shift+command+s")
    #expect(snapshot.shortcuts[.regionScreenshot] == "option+command+r")
    #expect(snapshot.shortcuts[.revealLastScreenshot] == "option+shift+command+r")
    #expect(snapshot.shortcuts[.showPermissions] == "option+command+p")
    #expect(snapshot.shortcuts[.showSettings] == "command+,")
    #expect(snapshot.shortcuts[.commandPalette] == "command+k")
    #expect(Set(snapshot.shortcuts.keys) == Set(ShortcutAction.allCases))
    #expect(Set(snapshot.shortcuts.values).count == snapshot.shortcuts.values.count)
    #expect(snapshot.shortcuts.values.allSatisfy(ShortcutText.isValid))
}

@MainActor
@Test func annotationLockTogglesWithoutChangingExistingAnnotations() {
    let store = AnnotationStore()
    let item = AnnotationItem(
        displayID: 1,
        kind: .pen,
        points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)],
        color: .red,
        lineWidth: 3
    )

    store.add(item)
    store.toggleAnnotationLock()

    #expect(store.annotationsLocked)
    #expect(store.annotations == [item])

    store.toggleAnnotationLock()
    #expect(!store.annotationsLocked)
}

@Test func preferencesSnapshotDecodesLegacyPreferencesWithNewDefaults() throws {
    let json = """
    {
      "theme": "system",
      "toolbarOrientation": "vertical",
      "toolbarCollapsed": false,
      "toolbarOriginX": 24,
      "toolbarOriginY": 220,
      "screenshotOutput": "file",
      "screenshotFolder": "~/Downloads",
      "defaultColor": { "red": 0.95, "green": 0.18, "blue": 0.24, "alpha": 1 },
      "quickColors": [],
      "visibleTools": ["cursor", "pen"],
      "whiteboardBackground": "white"
    }
    """.data(using: .utf8)!

    let snapshot = try JSONDecoder().decode(PreferencesSnapshot.self, from: json)

    #expect(snapshot.toolbarOriginsByDisplayID.isEmpty)
    #expect(!snapshot.highContrastToolbar)
    #expect(snapshot.toolbarTooltipsEnabled)
    #expect(snapshot.paletteColors == RGBAColor.defaultPaletteColors)
    #expect(snapshot.quickColors == Array(RGBAColor.defaultPaletteColors.prefix(4)))
    #expect(!snapshot.revealScreenshotAfterSave)
    #expect(!snapshot.confirmScreenshotFilename)
}

@Test func paletteColorsSeedFromLegacyQuickColorsAndStayCapped() throws {
    let json = """
    {
      "quickColors": [
        { "red": 0.1, "green": 0.2, "blue": 0.3, "alpha": 1 },
        { "red": 0.4, "green": 0.5, "blue": 0.6, "alpha": 1 }
      ]
    }
    """.data(using: .utf8)!

    var snapshot = try JSONDecoder().decode(PreferencesSnapshot.self, from: json)

    #expect(snapshot.paletteColors.count == RGBAColor.maximumPaletteColorCount)
    #expect(snapshot.quickColors == Array(snapshot.paletteColors.prefix(4)))

    snapshot.appendPaletteColor(.pink)
    #expect(snapshot.paletteColors.count == RGBAColor.maximumPaletteColorCount)

    snapshot.setPaletteColor(.black, at: 0)
    #expect(snapshot.quickColors[0] == .black)
}

@Test func savedPaletteRoundTripReloadsPaletteColors() {
    var snapshot = PreferencesSnapshot()

    snapshot.setPaletteColor(.black, at: 0)
    snapshot.saveCurrentPalette()
    snapshot.setPaletteColor(.white, at: 0)

    let saved = snapshot.savedColorPalettes[0]
    snapshot.loadPalette(saved)

    #expect(snapshot.paletteColors[0] == .black)
    #expect(snapshot.quickColors[0] == .black)
}

@MainActor
@Test func exitScreenControlsRestoresSafeClickThroughState() {
    let store = AnnotationStore(activeTool: .pen, whiteboardModeEnabled: true)

    #expect(store.isControllingScreen)

    store.exitScreenControls()

    #expect(store.activeTool == .cursor)
    #expect(!store.whiteboardModeEnabled)
    #expect(!store.isControllingScreen)
}

@MainActor
@Test func boardToolsToggleWhiteAndBlackBackgrounds() {
    let store = AnnotationStore()

    store.setActiveTool(.whiteboard)
    #expect(store.whiteboardModeEnabled)
    #expect(store.whiteboardBackground == .white)
    #expect(store.activeTool == .pen)

    store.setActiveTool(.blackboard)
    #expect(store.whiteboardModeEnabled)
    #expect(store.whiteboardBackground == .black)
    #expect(store.activeTool == .pen)

    store.setActiveTool(.blackboard)
    #expect(!store.whiteboardModeEnabled)
}

@MainActor
@Test func textMoveCanUndoAndRedo() {
    let store = AnnotationStore()
    let original = AnnotationItem(
        displayID: 1,
        kind: .text,
        points: [CGPoint(x: 10, y: 20)],
        color: .red,
        lineWidth: 3,
        text: "Move me",
        fontSize: 24
    )
    var moved = original
    moved.points = [CGPoint(x: 80, y: 120)]

    store.add(original)
    store.recordMove(from: original, to: moved)

    #expect(store.annotation(id: original.id)?.points == moved.points)

    store.undo()
    #expect(store.annotation(id: original.id)?.points == original.points)

    store.redo()
    #expect(store.annotation(id: original.id)?.points == moved.points)
}

@MainActor
@Test func strokeWidthKeyboardStepsClampToSupportedWidths() {
    let store = AnnotationStore(strokeWidth: 3)

    store.increaseStrokeWidth()
    #expect(store.strokeWidth == 5)

    store.increaseStrokeWidth()
    #expect(store.strokeWidth == 8)

    for _ in 0..<20 {
        store.increaseStrokeWidth()
    }
    #expect(store.strokeWidth == 64)

    store.decreaseStrokeWidth()
    #expect(store.strokeWidth == 32)

    for _ in 0..<20 {
        store.decreaseStrokeWidth()
    }
    #expect(store.strokeWidth == 1)
}

@MainActor
@Test func customStrokeWidthIsRoundedAndClamped() {
    let store = AnnotationStore(strokeWidth: 3)

    store.setStrokeWidth(7.6)
    #expect(store.strokeWidth == 8)

    store.setStrokeWidth(120)
    #expect(store.strokeWidth == 64)

    store.setStrokeWidth(-4)
    #expect(store.strokeWidth == 1)
}

@Test func shortcutTextNormalizesAliasesAndRejectsUnsafeShortcuts() {
    #expect(ShortcutText.normalize("cmd+shift+z") == "shift+command+z")
    #expect(ShortcutText.normalize("Control + Option + P") == "control+option+p")
    #expect(ShortcutText.normalize("esc") == "escape")
    #expect(ShortcutText.display("control+option+p") == "Control+Option+P")

    #expect(ShortcutText.normalize("p").isEmpty)
    #expect(ShortcutText.normalize("command").isEmpty)
    #expect(ShortcutText.normalize("command+").isEmpty)
    #expect(ShortcutText.normalize("+command+p").isEmpty)
}

@Test func preferencesSnapshotNormalizesShortcutInput() {
    let snapshot = PreferencesSnapshot(shortcuts: [
        .selectPen: "Control + Option + P",
        .selectEraser: "p"
    ])

    #expect(snapshot.shortcuts[.selectPen] == "control+option+p")
    #expect(snapshot.shortcuts[.selectEraser] == "")
}

@Test func screenshotNamerAvoidsSameSecondCollisions() {
    let folder = URL(fileURLWithPath: "/tmp", isDirectory: true)
    let date = Date(timeIntervalSince1970: 1_777_777_777)
    let existing = Set([
        folder.appendingPathComponent(ScreenshotNamer.fileName(date: date)),
        folder.appendingPathComponent(ScreenshotNamer.fileName(date: date, suffix: 2))
    ])

    let url = ScreenshotNamer.uniqueFileURL(in: folder, date: date) { existing.contains($0) }

    #expect(url.lastPathComponent == ScreenshotNamer.fileName(date: date, suffix: 3))
}
