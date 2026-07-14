import DMAnnotateCore
import Testing
@testable import DMAnnotate

@Test func toolbarAccessibilitySummaryNamesCursorSafetyAndEveryCurrentState() {
    let state = ToolbarAccessibilityState(
        activeTool: .cursor,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white,
        annotationsLocked: false,
        annotationsVisible: true,
        currentColor: .red,
        strokeWidth: 3,
        textFontSize: 24,
        textFontWeight: .semibold,
        isSafeMode: false
    )

    #expect(state.safetyMode == .cursor)
    #expect(state.activeToolValue == "Cursor")
    #expect(state.boardValue == "Off, preferred White")
    #expect(state.lockValue == "Unlocked")
    #expect(state.visibilityValue == "Visible")
    #expect(state.colorValue == "Red")
    #expect(state.strokeWidthValue == "3 pixels")
    #expect(state.textStyleValue == "24 pixels, Semibold")
    #expect(
        state.summary ==
            "Cursor mode; pointer input passes through. Active tool: Cursor. Board: Off, preferred White. " +
            "Annotations: Unlocked, Visible. Color: Red. Stroke width: 3 pixels. Text size: 24 pixels, Semibold."
    )
}

@Test func toolbarAccessibilityToolSemanticsMatchDrawingAndBoardSelection() {
    let drawing = ToolbarAccessibilityState(
        activeTool: .pen,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white,
        annotationsLocked: true,
        annotationsVisible: false,
        currentColor: .blue,
        strokeWidth: 8,
        textFontSize: 32,
        textFontWeight: .bold,
        isSafeMode: false
    )

    #expect(drawing.safetyMode == .drawing)
    #expect(drawing.tool(.pen, isEnabled: true).isSelected)
    #expect(drawing.tool(.pen, isEnabled: true).value == "Current tool; pointer input captured")
    #expect(!drawing.tool(.line, isEnabled: true).isSelected)

    let board = ToolbarAccessibilityState(
        activeTool: .pen,
        whiteboardModeEnabled: true,
        whiteboardBackground: .lightGrid,
        annotationsLocked: false,
        annotationsVisible: true,
        currentColor: .red,
        strokeWidth: 3,
        textFontSize: 24,
        textFontWeight: .semibold,
        isSafeMode: false
    )

    #expect(board.activeToolValue == "Whiteboard")
    #expect(board.boardValue == "On, Whiteboard family, Light Grid")
    #expect(board.tool(.whiteboard, isEnabled: true).isSelected)
    #expect(board.tool(.whiteboard, isEnabled: true).value == "Current board; Light Grid; pointer input captured")
    #expect(!board.tool(.blackboard, isEnabled: true).isSelected)
}

@Test func safeModeSuppressesUnavailableSelectionButKeepsCursorSemantic() {
    let state = ToolbarAccessibilityState(
        activeTool: .cursor,
        whiteboardModeEnabled: false,
        whiteboardBackground: .darkGrid,
        annotationsLocked: false,
        annotationsVisible: true,
        currentColor: .green,
        strokeWidth: 5,
        textFontSize: 20,
        textFontWeight: .medium,
        isSafeMode: true
    )

    #expect(state.safetyMode == .safeMode)
    #expect(state.tool(.cursor, isEnabled: true).isSelected)
    #expect(!state.tool(.pen, isEnabled: false).isSelected)
    #expect(state.tool(.pen, isEnabled: false).value == "Unavailable in Safe Mode")
    #expect(state.summary.hasPrefix("Safe Mode; pointer input passes through."))
}

@Test func toolbarAccessibilityNamesCustomColorWithoutRelyingOnTheSwatch() {
    let state = ToolbarAccessibilityState(
        activeTool: .text,
        whiteboardModeEnabled: false,
        whiteboardBackground: .black,
        annotationsLocked: false,
        annotationsVisible: true,
        currentColor: RGBAColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 0.5),
        strokeWidth: 12,
        textFontSize: 48,
        textFontWeight: .heavy,
        isSafeMode: false
    )

    #expect(state.colorValue == "Custom color, 25% red, 50% green, 75% blue, 50% opacity")
}

@Test func toolbarAnnouncementsCoalesceRapidReversalsToTheFinalImportantState() {
    let cursor = ToolbarAccessibilitySafetyMode.resolve(
        activeTool: .cursor,
        whiteboardModeEnabled: false,
        isSafeMode: false
    )
    let pen = ToolbarAccessibilitySafetyMode.resolve(
        activeTool: .pen,
        whiteboardModeEnabled: false,
        isSafeMode: false
    )
    let line = ToolbarAccessibilitySafetyMode.resolve(
        activeTool: .line,
        whiteboardModeEnabled: false,
        isSafeMode: false
    )

    #expect(pen == line)
    #expect(cursor != pen)

    var coalescer = ToolbarAccessibilityAnnouncementCoalescer()
    coalescer.schedule(
        ToolbarAccessibilityAnnouncementSnapshot(
            safetyMode: cursor,
            annotationsLocked: true,
            annotationsVisible: false
        ),
        at: 10
    )
    coalescer.schedule(
        ToolbarAccessibilityAnnouncementSnapshot(
            safetyMode: pen,
            annotationsLocked: false,
            annotationsVisible: true
        ),
        at: 10.1
    )

    #expect(coalescer.takeReady(at: 10.34) == nil)
    let final = coalescer.takeReady(at: 10.35)
    #expect(final?.safetyMode == .drawing)
    #expect(final?.annotationsLocked == false)
    #expect(final?.annotationsVisible == true)
    #expect(
        final?.message ==
            "Drawing mode. Pointer input captured. Annotations unlocked and visible."
    )
    #expect(coalescer.pendingSnapshot == nil)
}

@Test func toolbarAnnouncementCancellationCannotSpeakAStalePendingSnapshot() {
    var coalescer = ToolbarAccessibilityAnnouncementCoalescer()
    coalescer.schedule(
        ToolbarAccessibilityAnnouncementSnapshot(
            safetyMode: .cursor,
            annotationsLocked: true,
            annotationsVisible: false
        ),
        at: 20
    )
    coalescer.cancel()

    #expect(coalescer.pendingSnapshot == nil)
    #expect(coalescer.deadline == nil)
    #expect(coalescer.takeReady(at: 21) == nil)
}
