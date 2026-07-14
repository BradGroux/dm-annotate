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
@Test func undoHistoryIsCappedForLongSessions() {
    let store = AnnotationStore()

    for index in 0..<(AnnotationStore.maximumUndoDepth + 5) {
        store.add(
            AnnotationItem(
                displayID: 1,
                kind: .pen,
                points: [CGPoint(x: CGFloat(index), y: 0)],
                color: .red,
                lineWidth: 3
            )
        )
    }

    #expect(store.undoDepth == AnnotationStore.maximumUndoDepth)
    #expect(store.canUndo)
}

@MainActor
@Test func addRejectsAnnotationsPastLiveLimit() {
    let annotations = (0..<AnnotationStore.maximumAnnotationCount).map { index in
        AnnotationItem(
            displayID: 1,
            kind: .pen,
            points: [CGPoint(x: CGFloat(index), y: 0)],
            color: .red,
            lineWidth: 3
        )
    }
    let store = AnnotationStore(annotations: annotations)
    let accepted = store.add(
        AnnotationItem(
            displayID: 1,
            kind: .pen,
            points: [CGPoint(x: 0, y: 1)],
            color: .blue,
            lineWidth: 3
        )
    )

    #expect(!accepted)
    #expect(store.annotations.count == AnnotationStore.maximumAnnotationCount)
    #expect(store.undoDepth == 0)
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
    #expect(store.annotations == [touched, otherDisplay, untouched])
}

@Test func preferencesDefaultShortcutsMatchPRD() {
    let snapshot = PreferencesSnapshot()

    #expect(snapshot.shortcuts[.toggleAnnotationMode] == "option+command+a")
    #expect(snapshot.shortcuts[.cursorMode] == "escape")
    #expect(snapshot.shortcuts[.toggleToolbarCollapsed] == "option+command+t")
    #expect(snapshot.shortcuts[.toggleToolbarOrientation] == "option+command+o")
    #expect(snapshot.shortcuts[.toggleToolbarCompactMode] == "option+command+m")
    #expect(snapshot.shortcuts[.findToolbar] == "option+command+f")
    #expect(snapshot.shortcuts[.selectTool] == "control+option+s")
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
    #expect(snapshot.shortcutDescriptorVersion == ShortcutDescriptorFormat.legacyLayoutDependentVersion)
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

    #expect(store.annotations.count == 1)
    #expect(store.annotation(id: original.id)?.points == moved.points)

    store.undo()
    #expect(store.annotations.count == 1)
    #expect(store.annotation(id: original.id)?.points == original.points)

    store.redo()
    #expect(store.annotations.count == 1)
    #expect(store.annotation(id: original.id)?.points == moved.points)
}

@MainActor
@Test func recordMoveIgnoresAnnotationsThatAreNotInStore() {
    let store = AnnotationStore()
    let original = AnnotationItem(
        displayID: 1,
        kind: .text,
        points: [CGPoint(x: 10, y: 20)],
        color: .red,
        lineWidth: 3,
        text: "Missing",
        fontSize: 24
    )
    var moved = original
    moved.points = [CGPoint(x: 80, y: 120)]

    store.recordMove(from: original, to: moved)

    #expect(store.annotations.isEmpty)
    #expect(!store.canUndo)
    #expect(!store.canRedo)
}

@MainActor
@Test func selectedAnnotationCanMoveRecolorResizeDeleteAndUndo() {
    let store = AnnotationStore()
    let original = AnnotationItem(
        displayID: 1,
        kind: .rectangle,
        points: [CGPoint(x: 10, y: 10), CGPoint(x: 60, y: 60)],
        color: .red,
        lineWidth: 3
    )
    var moved = original
    moved.points = [CGPoint(x: 20, y: 30), CGPoint(x: 70, y: 80)]

    store.add(original)
    store.selectAnnotation(id: original.id)
    store.recordMove(from: original, to: moved)
    store.setCurrentColor(.blue)
    store.setStrokeWidth(12)

    #expect(store.annotation(id: original.id)?.points == moved.points)
    #expect(store.annotation(id: original.id)?.color == .blue)
    #expect(store.annotation(id: original.id)?.lineWidth == 12)

    #expect(store.deleteSelectedAnnotation())
    #expect(store.annotations.isEmpty)

    store.undo()
    #expect(store.annotations.count == 1)
    store.undo()
    #expect(store.annotation(id: original.id)?.lineWidth == 3)
    store.undo()
    #expect(store.annotation(id: original.id)?.color == .red)
    store.undo()
    #expect(store.annotation(id: original.id)?.points == original.points)
}

@MainActor
@Test func annotationSessionRoundTripsAndRetargetsMissingDisplays() throws {
    let store = AnnotationStore(
        currentColor: .green,
        strokeWidth: 9,
        textFontSize: 32,
        textFontWeight: .bold,
        isVisible: false,
        annotationsLocked: true,
        whiteboardModeEnabled: true,
        whiteboardBackground: .darkGrid
    )
    let item = AnnotationItem(
        displayID: 42,
        kind: .text,
        points: [CGPoint(x: 12, y: 34)],
        color: .blue,
        lineWidth: 3,
        text: "Saved",
        fontSize: 24,
        fontWeight: .semibold
    )

    store.add(item)
    let data = try store.sessionDocument(createdAt: Date(timeIntervalSince1970: 1_777_777_777)).encodedData()
    let decoded = try AnnotationSessionDocument.decode(from: data)
        .retargetingMissingDisplays(availableDisplayIDs: [7], fallbackDisplayID: 7)
    let restored = AnnotationStore()

    restored.loadSession(decoded)

    #expect(restored.annotations.count == 1)
    #expect(restored.annotations[0].displayID == 7)
    #expect(restored.currentColor == .green)
    #expect(restored.strokeWidth == 9)
    #expect(restored.textFontSize == 32)
    #expect(restored.textFontWeight == .bold)
    #expect(!restored.isVisible)
    #expect(restored.annotationsLocked)
    #expect(restored.whiteboardModeEnabled)
    #expect(restored.whiteboardBackground == .darkGrid)
    #expect(!restored.canUndo)
}

@Test func annotationSessionEncodedByteBoundaryAcceptsMaximumAndRejectsNextByte() throws {
    try AnnotationSessionDocument.validateEncodedByteCount(AnnotationSessionDocument.maximumEncodedByteCount)

    expectSessionError(.fileTooLarge(
        byteCount: AnnotationSessionDocument.maximumEncodedByteCount + 1,
        maximum: AnnotationSessionDocument.maximumEncodedByteCount
    )) {
        try AnnotationSessionDocument.validateEncodedByteCount(AnnotationSessionDocument.maximumEncodedByteCount + 1)
    }
}

@Test func annotationSessionRejectsTooManyAnnotationsAndPoints() {
    let tooManyAnnotations = (0...AnnotationStore.maximumAnnotationCount).map { index in
        AnnotationItem(
            displayID: 1,
            kind: .pen,
            points: [CGPoint(x: CGFloat(index), y: 0)],
            color: .red,
            lineWidth: 3
        )
    }
    let crowdedDocument = AnnotationSessionDocument(
        annotations: tooManyAnnotations,
        currentColor: .red,
        strokeWidth: 3,
        textFontSize: 24,
        textFontWeight: .semibold,
        isVisible: true,
        annotationsLocked: false,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white
    )
    let tooManyPointsID = UUID()
    let tooManyPointsDocument = AnnotationSessionDocument(
        annotations: [
            AnnotationItem(
                id: tooManyPointsID,
                displayID: 1,
                kind: .pen,
                points: (0...AnnotationSessionDocument.maximumPointsPerAnnotation).map { CGPoint(x: CGFloat($0), y: 0) },
                color: .red,
                lineWidth: 3
            )
        ],
        currentColor: .red,
        strokeWidth: 3,
        textFontSize: 24,
        textFontWeight: .semibold,
        isVisible: true,
        annotationsLocked: false,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white
    )

    expectSessionError(.tooManyAnnotations(
        count: AnnotationStore.maximumAnnotationCount + 1,
        maximum: AnnotationStore.maximumAnnotationCount
    )) {
        _ = try crowdedDocument.validated()
    }
    expectSessionError(.tooManyPoints(
        annotationID: tooManyPointsID,
        count: AnnotationSessionDocument.maximumPointsPerAnnotation + 1,
        maximum: AnnotationSessionDocument.maximumPointsPerAnnotation
    )) {
        _ = try tooManyPointsDocument.validated()
    }
}

@Test func annotationSessionEncodingRejectsTooManyPoints() {
    let annotationID = UUID()
    let document = AnnotationSessionDocument(
        annotations: [
            AnnotationItem(
                id: annotationID,
                displayID: 1,
                kind: .pen,
                points: (0...AnnotationSessionDocument.maximumPointsPerAnnotation).map {
                    CGPoint(x: CGFloat($0), y: 0)
                },
                color: .red,
                lineWidth: 3
            )
        ],
        currentColor: .red,
        strokeWidth: 3,
        textFontSize: 24,
        textFontWeight: .semibold,
        isVisible: true,
        annotationsLocked: false,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white
    )

    expectSessionError(.tooManyPoints(
        annotationID: annotationID,
        count: AnnotationSessionDocument.maximumPointsPerAnnotation + 1,
        maximum: AnnotationSessionDocument.maximumPointsPerAnnotation
    )) {
        _ = try document.encodedData()
    }
}

@Test func annotationSessionLivePointAppendStaysBoundedAndPreservesPathBasics() {
    var annotation = AnnotationItem(
        displayID: 1,
        kind: .pen,
        points: [CGPoint(x: 0, y: 0)],
        color: .red,
        lineWidth: 3
    )
    let finalX = AnnotationSessionDocument.maximumPointsPerAnnotation * 2 + 1

    for x in 1...finalX {
        annotation.appendSessionPoint(CGPoint(x: CGFloat(x), y: CGFloat(x % 7)))
        #expect(annotation.points.count <= AnnotationSessionDocument.maximumPointsPerAnnotation)
    }

    #expect(annotation.points.first == CGPoint(x: 0, y: 0))
    #expect(annotation.points.last == CGPoint(x: CGFloat(finalX), y: CGFloat(finalX % 7)))
    #expect(zip(annotation.points, annotation.points.dropFirst()).allSatisfy { $0.x < $1.x })
}

@Test func annotationSessionLivePointReductionPreservesOddIndexSharpTurn() {
    let maximum = AnnotationSessionDocument.maximumPointsPerAnnotation
    let sharpTurnIndex = 9_999
    var points = (0..<maximum).map { CGPoint(x: CGFloat($0), y: 0) }
    let sharpTurn = CGPoint(x: CGFloat(sharpTurnIndex), y: 500)
    points[sharpTurnIndex] = sharpTurn
    var annotation = AnnotationItem(
        displayID: 1,
        kind: .pen,
        points: points,
        color: .red,
        lineWidth: 3
    )

    annotation.appendSessionPoint(CGPoint(x: CGFloat(maximum), y: 0))

    #expect(annotation.points.count <= maximum)
    #expect(annotation.points.first == points.first)
    #expect(annotation.points.last == CGPoint(x: CGFloat(maximum), y: 0))
    #expect(annotation.points.contains(sharpTurn))
}

@MainActor
@Test func annotationSessionReducedStrokeRemainsOneUndoableAnnotation() {
    let maximum = AnnotationSessionDocument.maximumPointsPerAnnotation
    var annotation = AnnotationItem(
        displayID: 1,
        kind: .pen,
        points: (0..<maximum).map { CGPoint(x: CGFloat($0), y: CGFloat($0 % 5)) },
        color: .red,
        lineWidth: 3
    )
    annotation.appendSessionPoint(CGPoint(x: CGFloat(maximum), y: 0))
    let store = AnnotationStore()

    #expect(store.add(annotation))
    #expect(store.annotations == [annotation])
    #expect(store.canUndo)

    store.undo()

    #expect(store.annotations.isEmpty)
    #expect(!store.canUndo)
    #expect(store.canRedo)
}

@MainActor
@Test func annotationSessionStoreExportsOnlyReloadableData() throws {
    let store = AnnotationStore()
    let annotation = AnnotationItem(
        displayID: 1,
        kind: .pen,
        points: (0..<AnnotationSessionDocument.maximumPointsPerAnnotation).map {
            CGPoint(x: CGFloat($0), y: 0)
        },
        color: .red,
        lineWidth: 3
    )

    #expect(store.add(annotation))

    let data = try store.sessionData(createdAt: Date(timeIntervalSince1970: 1_777_777_777))
    let decoded = try AnnotationSessionDocument.decode(from: data)

    #expect(decoded.annotations == [annotation])
}

@Test func annotationSessionEncodingRejectsOversizedOutput() {
    let text = String(repeating: "a", count: AnnotationSessionDocument.maximumTextLength)
    let annotations = (0..<1_400).map { index in
        AnnotationItem(
            displayID: 1,
            kind: .text,
            points: [CGPoint(x: CGFloat(index), y: 0)],
            color: .red,
            lineWidth: 3,
            text: text,
            fontSize: 24
        )
    }
    let document = AnnotationSessionDocument(
        annotations: annotations,
        currentColor: .red,
        strokeWidth: 3,
        textFontSize: 24,
        textFontWeight: .semibold,
        isVisible: true,
        annotationsLocked: false,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white
    )

    do {
        _ = try document.encodedData()
        Issue.record("Expected oversized encoded session data to be rejected.")
    } catch let AnnotationSessionError.fileTooLarge(byteCount, maximum) {
        #expect(byteCount > maximum)
        #expect(maximum == AnnotationSessionDocument.maximumEncodedByteCount)
    } catch {
        Issue.record("Expected fileTooLarge, but received \(error).")
    }
}

@MainActor
@Test func annotationSessionStoreFailedExportPreservesExistingDecodableFile() throws {
    let annotationID = UUID()
    let store = AnnotationStore(annotations: [
        AnnotationItem(
            id: annotationID,
            displayID: 1,
            kind: .pen,
            points: (0...AnnotationSessionDocument.maximumPointsPerAnnotation).map {
                CGPoint(x: CGFloat($0), y: 0)
            },
            color: .red,
            lineWidth: 3
        )
    ])
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("Existing.dmannotate-session")
    let existingAnnotation = AnnotationItem(
        displayID: 1,
        kind: .line,
        points: [CGPoint(x: 10, y: 20), CGPoint(x: 30, y: 40)],
        color: .blue,
        lineWidth: 5
    )
    let existingData = try AnnotationStore(annotations: [existingAnnotation]).sessionData(
        createdAt: Date(timeIntervalSince1970: 1_777_777_777)
    )
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try existingData.write(to: url)
    defer { try? FileManager.default.removeItem(at: directory) }

    expectSessionError(.tooManyPoints(
        annotationID: annotationID,
        count: AnnotationSessionDocument.maximumPointsPerAnnotation + 1,
        maximum: AnnotationSessionDocument.maximumPointsPerAnnotation
    )) {
        try store.exportSession(to: url)
    }

    let preservedData = try Data(contentsOf: url)
    let preservedDocument = try AnnotationSessionDocument.decode(from: preservedData)
    #expect(preservedData == existingData)
    #expect(preservedDocument.annotations == [existingAnnotation])
}

@Test func annotationSessionLimitErrorsProvideRecoveryGuidance() {
    let annotationID = UUID()
    let expectations: [(AnnotationSessionError, String)] = [
        (.fileTooLarge(byteCount: 11, maximum: 10), "split"),
        (.tooManyAnnotations(count: 11, maximum: 10), "Remove"),
        (.tooManyPoints(annotationID: annotationID, count: 11, maximum: 10), "shorter strokes"),
        (.textTooLong(annotationID: annotationID, count: 11, maximum: 10), "Shorten"),
        (.invalidStyle(annotationID: annotationID), "recreate")
    ]

    for (error, expectedPhrase) in expectations {
        #expect(error.recoverySuggestion?.contains(expectedPhrase) == true)
    }
}

@Test func annotationSessionSaveFailureMessageExplainsPreservationAndRecovery() {
    let error = AnnotationSessionError.fileTooLarge(byteCount: 11, maximum: 10)

    let message = AnnotationStore.sessionSaveFailureMessage(for: error)

    #expect(message.contains("No partial session was saved"))
    #expect(message.contains("existing file was left unchanged"))
    #expect(message.contains(error.localizedDescription))
    #expect(message.contains(error.recoverySuggestion ?? "missing recovery suggestion"))
}

@MainActor
@Test func annotationSessionStoreBoundaryStateRoundTrips() throws {
    var annotations = (0..<(AnnotationStore.maximumAnnotationCount - 2)).map { index in
        AnnotationItem(
            displayID: 1,
            kind: .line,
            points: [CGPoint(x: CGFloat(index), y: 0)],
            color: .red,
            lineWidth: AnnotationStore.maximumStrokeWidth
        )
    }
    let pointBoundaryID = UUID()
    annotations.append(
        AnnotationItem(
            id: pointBoundaryID,
            displayID: 1,
            kind: .pen,
            points: (0..<AnnotationSessionDocument.maximumPointsPerAnnotation).map {
                CGPoint(x: CGFloat($0), y: 1)
            },
            color: .green,
            lineWidth: AnnotationStore.maximumStrokeWidth
        )
    )
    let textBoundaryID = UUID()
    annotations.append(
        AnnotationItem(
            id: textBoundaryID,
            displayID: 1,
            kind: .text,
            points: [CGPoint(x: 0, y: 2)],
            color: .blue,
            lineWidth: AnnotationStore.maximumStrokeWidth,
            text: String(repeating: "a", count: AnnotationSessionDocument.maximumTextLength),
            fontSize: AnnotationStore.maximumTextFontSize,
            fontWeight: .bold
        )
    )
    let store = AnnotationStore(
        annotations: annotations,
        strokeWidth: AnnotationStore.maximumStrokeWidth,
        textFontSize: AnnotationStore.maximumTextFontSize
    )

    let data = try store.sessionData(createdAt: Date(timeIntervalSince1970: 1_777_777_777))
    let decoded = try AnnotationSessionDocument.decode(from: data)

    #expect(data.count <= Int(AnnotationSessionDocument.maximumEncodedByteCount))
    #expect(decoded.annotations.count == AnnotationStore.maximumAnnotationCount)
    #expect(decoded.annotations.first { $0.id == pointBoundaryID }?.points.count == AnnotationSessionDocument.maximumPointsPerAnnotation)
    #expect(decoded.annotations.first { $0.id == textBoundaryID }?.text.count == AnnotationSessionDocument.maximumTextLength)
    #expect(decoded.annotations.first { $0.id == textBoundaryID }?.fontSize == AnnotationStore.maximumTextFontSize)
    #expect(decoded.strokeWidth == AnnotationStore.maximumStrokeWidth)
    #expect(decoded.textFontSize == AnnotationStore.maximumTextFontSize)
}

@Test func annotationSessionRejectsInvalidAnnotationGeometry() {
    let annotationID = UUID()
    let document = AnnotationSessionDocument(
        annotations: [
            AnnotationItem(
                id: annotationID,
                displayID: 1,
                kind: .pen,
                points: [CGPoint(x: AnnotationSessionDocument.maximumCoordinateMagnitude + 1, y: 0)],
                color: .red,
                lineWidth: 3
            )
        ],
        currentColor: .red,
        strokeWidth: 3,
        textFontSize: 24,
        textFontWeight: .semibold,
        isVisible: true,
        annotationsLocked: false,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white
    )

    expectSessionError(.invalidGeometry(annotationID: annotationID)) {
        _ = try document.validated()
    }
}

@Test func annotationSessionRejectsInvalidColorAndLongText() {
    let badColorID = UUID()
    let longTextID = UUID()
    let badColorDocument = AnnotationSessionDocument(
        annotations: [
            AnnotationItem(
                id: badColorID,
                displayID: 1,
                kind: .pen,
                points: [CGPoint(x: 0, y: 0)],
                color: RGBAColor(red: 1.2, green: 0, blue: 0),
                lineWidth: 3
            )
        ],
        currentColor: .red,
        strokeWidth: 3,
        textFontSize: 24,
        textFontWeight: .semibold,
        isVisible: true,
        annotationsLocked: false,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white
    )
    let longTextDocument = AnnotationSessionDocument(
        annotations: [
            AnnotationItem(
                id: longTextID,
                displayID: 1,
                kind: .text,
                points: [CGPoint(x: 0, y: 0)],
                color: .red,
                lineWidth: 3,
                text: String(repeating: "a", count: AnnotationSessionDocument.maximumTextLength + 1)
            )
        ],
        currentColor: .red,
        strokeWidth: 3,
        textFontSize: 24,
        textFontWeight: .semibold,
        isVisible: true,
        annotationsLocked: false,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white
    )

    expectSessionError(.invalidColor(annotationID: badColorID)) {
        _ = try badColorDocument.validated()
    }
    expectSessionError(.textTooLong(
        annotationID: longTextID,
        count: AnnotationSessionDocument.maximumTextLength + 1,
        maximum: AnnotationSessionDocument.maximumTextLength
    )) {
        _ = try longTextDocument.validated()
    }
}

@Test func annotationSessionRejectsInvalidCurrentColor() {
    let document = AnnotationSessionDocument(
        annotations: [
            AnnotationItem(
                displayID: 1,
                kind: .pen,
                points: [CGPoint(x: 0, y: 0)],
                color: .red,
                lineWidth: 3
            )
        ],
        currentColor: RGBAColor(red: 0, green: -0.1, blue: 0),
        strokeWidth: 3,
        textFontSize: 24,
        textFontWeight: .semibold,
        isVisible: true,
        annotationsLocked: false,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white
    )

    expectSessionError(.invalidCurrentColor) {
        _ = try document.validated()
    }
}

@Test func annotationSessionNormalizesValidImportedStyles() throws {
    let annotationID = UUID()
    let document = AnnotationSessionDocument(
        annotations: [
            AnnotationItem(
                id: annotationID,
                displayID: 1,
                kind: .text,
                points: [CGPoint(x: 0, y: 0)],
                color: .red,
                lineWidth: 500,
                text: "Imported",
                fontSize: -5
            )
        ],
        currentColor: .red,
        strokeWidth: 500,
        textFontSize: -5,
        textFontWeight: .semibold,
        isVisible: true,
        annotationsLocked: false,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white
    )

    let validated = try document.validated()

    #expect(validated.annotations.first?.id == annotationID)
    #expect(validated.annotations.first?.lineWidth == AnnotationStore.maximumStrokeWidth)
    #expect(validated.annotations.first?.fontSize == AnnotationStore.minimumTextFontSize)
    #expect(validated.strokeWidth == AnnotationStore.maximumStrokeWidth)
    #expect(validated.textFontSize == AnnotationStore.minimumTextFontSize)
}

@Test func toolbarPresetsApplyOnlyAvailableDisplays() {
    var snapshot = PreferencesSnapshot(
        toolbarOrientation: .horizontal,
        toolbarCompactMode: true,
        toolbarOriginX: 20,
        toolbarOriginY: 40,
        toolbarOriginsByDisplayID: ["1": CGPoint(x: 20, y: 40), "2": CGPoint(x: 90, y: 120)]
    )
    snapshot.saveToolbarPreset(named: "Desk")
    snapshot.toolbarOrientation = .vertical
    snapshot.toolbarCompactMode = false
    snapshot.toolbarOrigin = CGPoint(x: 0, y: 0)
    snapshot.toolbarOriginsByDisplayID = [:]

    snapshot.applyToolbarPreset(snapshot.toolbarPresets[0], availableDisplayIDs: ["2"])

    #expect(snapshot.toolbarOrientation == .horizontal)
    #expect(snapshot.toolbarCompactMode)
    #expect(snapshot.toolbarOrigin == CGPoint(x: 20, y: 40))
    #expect(snapshot.toolbarOriginsByDisplayID == ["2": CGPoint(x: 90, y: 120)])
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

@MainActor
@Test func customTextFontSizeIsRoundedAndClamped() {
    let store = AnnotationStore(textFontSize: 24)

    store.setTextFontSize(27.6)
    #expect(store.textFontSize == 28)

    store.setTextFontSize(500)
    #expect(store.textFontSize == 160)

    store.setTextFontSize(-2)
    #expect(store.textFontSize == 8)

    store.setTextFontWeight(.bold)
    #expect(store.textFontWeight == .bold)
}

@Test func textAnnotationsAccountForMultilineBoundsAndWeight() {
    let singleLine = AnnotationItem(
        displayID: 1,
        kind: .text,
        points: [CGPoint(x: 10, y: 20)],
        color: .red,
        lineWidth: 3,
        text: "Short",
        fontSize: 24,
        fontWeight: .regular
    )
    let multiline = AnnotationItem(
        displayID: 1,
        kind: .text,
        points: [CGPoint(x: 10, y: 20)],
        color: .blue,
        lineWidth: 3,
        text: "Short\nA much longer line",
        fontSize: 24,
        fontWeight: .heavy
    )

    #expect(singleLine.fontWeight == .regular)
    #expect(multiline.fontWeight == .heavy)
    #expect(multiline.boundingRect.height > singleLine.boundingRect.height)
    #expect(multiline.boundingRect.width > singleLine.boundingRect.width)
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

@Test func shortcutTextAcceptsOnlyPortableKeyIdentities() {
    #expect(ShortcutText.normalize("control+option+f1") == "control+option+f1")
    #expect(ShortcutText.normalize("option+command+left") == "option+command+left")
    #expect(ShortcutText.normalize("option+command+left-arrow") == "option+command+left")
    #expect(ShortcutText.normalize("control+return") == "control+enter")

    #expect(ShortcutText.normalize("control+option+banana").isEmpty)
    #expect(!ShortcutText.isValid("control+option+é"))
}

@Test func shortcutKeyIdentityUsesPhysicalKeyCodesAcrossLayouts() {
    #expect(ShortcutKeyIdentity.name(forKeyCode: 35) == "p")
    #expect(ShortcutKeyIdentity.keyCodes(forName: "p") == [35])
    #expect(ShortcutKeyIdentity.name(forKeyCode: 122) == "f1")
    #expect(ShortcutKeyIdentity.keyCodes(forName: "f1") == [122])
    #expect(ShortcutKeyIdentity.name(forKeyCode: 10) == nil)
    #expect(ShortcutKeyIdentity.name(forKeyCode: 69) == nil)
    #expect(ShortcutKeyIdentity.name(forKeyCode: 51) == "delete")
    #expect(ShortcutKeyIdentity.name(forKeyCode: 117) == "forward-delete")
    #expect(ShortcutKeyIdentity.keyCodes(forName: "delete") == [51])
    #expect(ShortcutKeyIdentity.keyCodes(forName: "forward-delete") == [117])
}

@Test func forwardDeleteHasDistinctRecorderAndDispatchIdentity() {
    let modifiers: ShortcutModifiers = [.control, .option]

    #expect(PortableShortcutDescriptor.resolve(keyCode: 51, modifiers: modifiers) == "control+option+delete")
    #expect(PortableShortcutDescriptor.resolve(keyCode: 117, modifiers: modifiers) == "control+option+forward-delete")
    #expect(ShortcutRecordingOutcome.resolve(keyCode: 51, modifiers: []) == .clear)
    #expect(ShortcutRecordingOutcome.resolve(keyCode: 117, modifiers: []) == .clear)
    #expect(
        ShortcutRecordingOutcome.resolve(keyCode: 117, modifiers: modifiers) ==
            .accepted("control+option+forward-delete")
    )
    #expect(ShortcutText.display("control+option+forward-delete") == "Control+Option+Forward Delete")
}

@Test func portableShortcutDescriptorResolvesModifiersAndPhysicalKeyTogether() {
    let modifiers: ShortcutModifiers = [.control, .option, .shift]

    #expect(
        PortableShortcutDescriptor.resolve(keyCode: 35, modifiers: modifiers) ==
            "control+option+shift+p"
    )
    #expect(PortableShortcutDescriptor.resolve(keyCode: 122, modifiers: [.control, .option]) == "control+option+f1")
    #expect(PortableShortcutDescriptor.resolve(keyCode: 255, modifiers: modifiers) == nil)
}

@Test func portableShortcutContractHasExhaustiveEventAndMenuParity() throws {
    let modifiers: ShortcutModifiers = [.control, .option]

    for keyCode in ShortcutKeyIdentity.allKeyCodes {
        let name = try #require(ShortcutKeyIdentity.name(forKeyCode: keyCode))
        #expect(ShortcutKeyIdentity.allCanonicalNames.contains(name))
        #expect(ShortcutKeyIdentity.keyCodes(forName: name).contains(keyCode))

        let descriptor = try #require(
            PortableShortcutDescriptor.resolve(keyCode: keyCode, modifiers: modifiers)
        )
        #expect(ShortcutText.normalize(descriptor) == descriptor)
        #expect(ShortcutText.canDispatchGlobally(descriptor) == (name != "escape"))
        #expect(ShortcutResolver.action(for: descriptor, in: [.selectPen: descriptor]) == .selectPen)

        let recording = ShortcutRecordingOutcome.resolve(keyCode: keyCode, modifiers: modifiers)
        #expect(recording == (name == "escape" ? .cancel : .accepted(descriptor)))

        let menuEquivalent = try #require(
            PortableShortcutMenuAdapter.resolve(descriptor) { translatedKeyCode in
                String(UnicodeScalar(0xE000 + Int(translatedKeyCode))!)
            }
        )
        let expectedKeyCode = try #require(ShortcutKeyIdentity.primaryKeyCode(forName: name))
        #expect(menuEquivalent.key == String(UnicodeScalar(0xE000 + Int(expectedKeyCode))!))
        #expect(menuEquivalent.modifiers == (name == "escape" ? [] : modifiers))
    }
}

@Test func portableShortcutMenuAdapterUsesTheActiveLayoutForTheSamePhysicalKey() throws {
    let us = try #require(
        PortableShortcutMenuAdapter.resolve("control+option+p") { keyCode in
            keyCode == 35 ? "p" : nil
        }
    )
    let alternate = try #require(
        PortableShortcutMenuAdapter.resolve("control+option+p") { keyCode in
            keyCode == 35 ? "r" : nil
        }
    )

    #expect(us.key == "p")
    #expect(alternate.key == "r")
    #expect(us.modifiers == alternate.modifiers)
}

@Test func shortcutRecorderReportsUnsupportedKeysWithoutChangingTheShortcut() {
    let unsupported = ShortcutRecordingOutcome.resolve(keyCode: 69, modifiers: [.control, .option])
    let missingModifier = ShortcutRecordingOutcome.resolve(keyCode: 35, modifiers: [])

    #expect(unsupported == .rejected(.unsupportedKey))
    #expect(unsupported.feedback == "Unsupported key")
    #expect(missingModifier == .rejected(.missingModifier))
    #expect(missingModifier.feedback == "Use modifier...")
}

@Test func preferencesSnapshotNormalizesShortcutInput() {
    let snapshot = PreferencesSnapshot(shortcuts: [
        .selectPen: "Control + Option + P",
        .selectEraser: "p"
    ])

    #expect(snapshot.shortcuts[.selectPen] == "control+option+p")
    #expect(snapshot.shortcuts[.selectEraser] == "p")
    #expect(ShortcutResolver.usableShortcut(for: .selectEraser, in: snapshot.shortcuts) == nil)
    #expect(snapshot.shortcuts[.showSettings] == ShortcutAction.defaultShortcuts[.showSettings])
    #expect(Set(snapshot.shortcuts.keys) == Set(ShortcutAction.allCases))
}

@Test func preferencesSnapshotPreservesUnsupportedLegacyShortcutForRecovery() {
    let snapshot = PreferencesSnapshot(shortcuts: [
        .selectPen: "control+option+banana"
    ])

    #expect(snapshot.shortcuts[.selectPen] == "control+option+banana")
    #expect(ShortcutText.display(snapshot.shortcuts[.selectPen] ?? "") == "Unsupported: control+option+banana")
    #expect(ShortcutResolver.usableShortcut(for: .selectPen, in: snapshot.shortcuts) == nil)
}

@Test func legacyShortcutMigrationUsesActiveLayoutWithoutReinterpretingPhysicalKeys() {
    var snapshot = PreferencesSnapshot(
        shortcuts: [
            .selectPen: "control+option+p",
            .selectEraser: "control+option+r",
            .selectLine: "control+option+f1",
            .selectEllipse: "control+option+shift+!",
            .selectHighlighter: "control+option+q",
            .selectRectangle: "control+option+not-on-this-layout"
        ],
        shortcutDescriptorVersion: ShortcutDescriptorFormat.legacyLayoutDependentVersion
    )

    snapshot.migrateLegacyShortcuts { character, modifiers in
        switch character {
        case "p": 15 // The active layout produces P from the ANSI R position.
        case "r": 35 // The active layout produces R from the ANSI P position.
        case "!" where modifiers.contains(.shift): 18
        default: nil
        }
    }

    #expect(snapshot.shortcutDescriptorVersion == ShortcutDescriptorFormat.currentVersion)
    #expect(snapshot.shortcuts[.selectPen] == "control+option+r")
    #expect(snapshot.shortcuts[.selectEraser] == "control+option+p")
    #expect(snapshot.shortcuts[.selectLine] == "control+option+f1")
    #expect(snapshot.shortcuts[.selectEllipse] == "control+option+shift+1")
    #expect(snapshot.shortcuts[.selectHighlighter] == "legacy-layout:control+option+q")
    #expect(snapshot.shortcuts[.selectRectangle] == "legacy-layout:control+option+not-on-this-layout")
    #expect(
        ShortcutText.display(snapshot.shortcuts[.selectHighlighter] ?? "") ==
            "Legacy shortcut: control+option+q (record again)"
    )
    #expect(ShortcutResolver.usableShortcut(for: .selectHighlighter, in: snapshot.shortcuts) == nil)
    #expect(ShortcutResolver.usableShortcut(for: .selectRectangle, in: snapshot.shortcuts) == nil)
}

@Test func currentShortcutPreferencesPersistTheirVersionAndNeverMigrateAgain() throws {
    let snapshot = PreferencesSnapshot(shortcuts: [.selectPen: "control+option+p"])
    let encoded = try JSONEncoder().encode(snapshot)
    var decoded = try JSONDecoder().decode(PreferencesSnapshot.self, from: encoded)

    decoded.migrateLegacyShortcuts { _, _ in 15 }

    #expect(decoded.shortcutDescriptorVersion == ShortcutDescriptorFormat.currentVersion)
    #expect(decoded.shortcuts[.selectPen] == "control+option+p")
}

@Test func shortcutTextSeparatesGlobalSafeShortcutsFromLocalMenuShortcuts() {
    #expect(ShortcutText.canDispatchGlobally("option+command+a"))
    #expect(ShortcutText.canDispatchGlobally("control+option+p"))

    #expect(!ShortcutText.canDispatchGlobally("command+z"))
    #expect(!ShortcutText.canDispatchGlobally("shift+command+z"))
    #expect(!ShortcutText.canDispatchGlobally("command+k"))
    #expect(!ShortcutText.canDispatchGlobally("escape"))
}

@Test func shortcutResolverSuppressesDuplicateAssignments() {
    let shortcuts: [ShortcutAction: String] = [
        .commandPalette: "command+k",
        .showSettings: "cmd+k",
        .selectPen: "control+option+p"
    ]

    #expect(ShortcutResolver.duplicateDescriptors(in: shortcuts) == ["command+k"])
    #expect(ShortcutResolver.action(for: "command+k", in: shortcuts) == nil)
    #expect(ShortcutResolver.usableShortcut(for: .commandPalette, in: shortcuts) == nil)
    #expect(ShortcutResolver.usableShortcut(for: .showSettings, in: shortcuts) == nil)
    #expect(ShortcutResolver.action(for: "control+option+p", in: shortcuts) == .selectPen)
}

@Test func shortcutResolverBuildsConsumableGlobalActionMap() {
    var shortcuts = ShortcutAction.defaultShortcuts
    shortcuts[.selectPen] = "control+option+p"
    shortcuts[.showSettings] = "command+,"
    shortcuts[.undo] = "command+z"
    shortcuts[.selectHighlighter] = "control+option+p"

    let actionsByDescriptor = ShortcutResolver.globallyDispatchableActions(in: shortcuts)

    #expect(actionsByDescriptor["option+command+t"] == .toggleToolbarCollapsed)
    #expect(actionsByDescriptor["command+,"] == nil)
    #expect(actionsByDescriptor["command+z"] == nil)
    #expect(actionsByDescriptor["control+option+p"] == nil)
}

@Test func shortcutResolverOnlyPublishesDescriptorsTheEventTapCanProduce() {
    let actionsByDescriptor = ShortcutResolver.globallyDispatchableActions(in: [
        .selectPen: "control+option+f1",
        .selectEraser: "control+option+banana"
    ])

    #expect(actionsByDescriptor == ["control+option+f1": .selectPen])
}

@Test func globalShortcutMonitorStateDisablesDispatchWhenTapUnavailable() {
    let actionsByDescriptor = ShortcutResolver.globallyDispatchableActions(in: [
        .regionScreenshot: "option+command+r",
        .showSettings: "command+,"
    ])

    let active = GlobalShortcutMonitorState.resolved(
        actionCount: actionsByDescriptor.count,
        didStartConsumableTap: true
    )
    let unavailable = GlobalShortcutMonitorState.resolved(
        actionCount: actionsByDescriptor.count,
        didStartConsumableTap: false
    )

    #expect(actionsByDescriptor.count == 1)
    #expect(active == .consumable(actionCount: 1))
    #expect(active.allowsGlobalShortcutDispatch)
    #expect(!active.needsAttention)
    #expect(unavailable == .eventTapUnavailable(actionCount: 1))
    #expect(!unavailable.allowsGlobalShortcutDispatch)
    #expect(unavailable.needsAttention)
}

@Test func globalShortcutMonitorStateTreatsLocalOnlyShortcutsAsNoGlobalShortcuts() {
    let actionsByDescriptor = ShortcutResolver.globallyDispatchableActions(in: [
        .showSettings: "command+,",
        .commandPalette: "command+k"
    ])
    let state = GlobalShortcutMonitorState.resolved(
        actionCount: actionsByDescriptor.count,
        didStartConsumableTap: false
    )

    #expect(actionsByDescriptor.isEmpty)
    #expect(state == .noGlobalShortcuts)
    #expect(!state.allowsGlobalShortcutDispatch)
    #expect(!state.needsAttention)
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

@Test func screenshotNamerSupportsNamedExportVariants() {
    let folder = URL(fileURLWithPath: "/tmp", isDirectory: true)
    let date = Date(timeIntervalSince1970: 1_777_777_777)
    let existing = Set([
        folder.appendingPathComponent(ScreenshotNamer.fileName(date: date, nameComponent: "annotations"))
    ])

    let url = ScreenshotNamer.uniqueFileURL(in: folder, date: date, nameComponent: "annotations") { existing.contains($0) }

    #expect(ScreenshotNamer.fileName(date: date, nameComponent: "annotations").hasSuffix("-annotations.png"))
    #expect(url.lastPathComponent == ScreenshotNamer.fileName(date: date, nameComponent: "annotations", suffix: 2))
}

@Test func screenshotGeometryScalesRegionIntoPixelSpace() {
    let region = CGRect(x: 10.25, y: 20.5, width: 100.25, height: 50.25)
    let rect = ScreenshotGeometry.pixelRect(
        forRegion: region,
        pointSize: CGSize(width: 500, height: 300),
        pixelSize: CGSize(width: 1_000, height: 600)
    )

    #expect(rect == CGRect(x: 20, y: 41, width: 201, height: 101))
}

@Test func screenshotGeometryIncludesFractionalOriginAndMaximumRetinaEdges() {
    let rect = ScreenshotGeometry.pixelRect(
        forRegion: CGRect(x: 10.25, y: 20.25, width: 100.5, height: 50.5),
        pointSize: CGSize(width: 500, height: 300),
        pixelSize: CGSize(width: 1_000, height: 600)
    )

    #expect(rect == CGRect(x: 20, y: 40, width: 202, height: 102))
    #expect(Int(rect.maxX) == 222)
    #expect(Int(rect.maxY) == 142)
}

@Test func screenshotGeometryClampsRegionToPixelBounds() {
    let rect = ScreenshotGeometry.pixelRect(
        forRegion: CGRect(x: -20, y: 90, width: 80, height: 80),
        pointSize: CGSize(width: 100, height: 100),
        pixelSize: CGSize(width: 200, height: 200)
    )

    #expect(rect == CGRect(x: 0, y: 180, width: 120, height: 20))
}

@Test func screenshotGeometryReturnsZeroForInvalidInput() {
    let rect = ScreenshotGeometry.pixelRect(
        forRegion: CGRect(x: 0, y: 0, width: 10, height: 10),
        pointSize: .zero,
        pixelSize: CGSize(width: 100, height: 100)
    )

    #expect(rect == .zero)
}

@Test func screenshotGeometryMapsLowerLeftRegionToCGImageCropCoordinates() {
    let cropRect = ScreenshotGeometry.cgImageCropRect(
        forPixelRect: CGRect(x: 20, y: 41, width: 201, height: 101),
        imageSize: CGSize(width: 1_000, height: 600)
    )

    #expect(cropRect == CGRect(x: 20, y: 458, width: 201, height: 101))
}

@Test func screenshotGeometryClampsCGImageCropCoordinates() {
    let cropRect = ScreenshotGeometry.cgImageCropRect(
        forPixelRect: CGRect(x: -10, y: 190, width: 40, height: 30),
        imageSize: CGSize(width: 200, height: 200)
    )

    #expect(cropRect == CGRect(x: 0, y: 0, width: 30, height: 10))
}

@Test func screenshotGeometryMapsLocalRegionToIntegralDisplayCaptureRect() {
    let captureRect = ScreenshotGeometry.displayCaptureRect(
        forRegion: CGRect(x: 10.25, y: 20.5, width: 100.25, height: 50.25),
        pointSize: CGSize(width: 500, height: 300),
        displayBounds: CGRect(x: 1_920, y: -100, width: 500, height: 300)
    )

    #expect(captureRect == CGRect(x: 1_930, y: 129, width: 101, height: 51))
}

@Test func toolbarLayoutMetricsClampHorizontalWidthToVisibleFrame() {
    let snapshot = PreferencesSnapshot(toolbarOrientation: .horizontal)
    let size = ToolbarLayoutMetrics.preferredSize(
        for: snapshot,
        visibleFrame: CGRect(x: 0, y: 0, width: 320, height: 900),
        statusControlCount: 0
    )

    #expect(size.width == 296)
    #expect(size.height == ToolbarLayoutMetrics.horizontalPanelHeight)
}

@Test func toolbarLayoutMetricsVerticalHeightHandlesPermissionStatus() {
    let snapshot = PreferencesSnapshot(toolbarOrientation: .vertical)
    let visibleFrame = CGRect(x: 0, y: 0, width: 800, height: 2_000)
    let withoutStatus = ToolbarLayoutMetrics.preferredSize(
        for: snapshot,
        visibleFrame: visibleFrame,
        statusControlCount: 0
    )
    let withStatus = ToolbarLayoutMetrics.preferredSize(
        for: snapshot,
        visibleFrame: visibleFrame,
        statusControlCount: 1
    )

    #expect(withStatus.height == withoutStatus.height + ToolbarLayoutMetrics.buttonSize + ToolbarLayoutMetrics.gridSpacing)
    #expect(withStatus.width == ToolbarLayoutMetrics.verticalPanelWidth)
}

@Test func toolbarLayoutMetricsAccountForSelectedAnnotationAction() {
    let visibleFrame = CGRect(x: 0, y: 0, width: 1_400, height: 2_000)
    let verticalSnapshot = PreferencesSnapshot(toolbarOrientation: .vertical)
    let horizontalSnapshot = PreferencesSnapshot(toolbarOrientation: .horizontal)

    let verticalWithoutSelection = ToolbarLayoutMetrics.preferredSize(
        for: verticalSnapshot,
        visibleFrame: visibleFrame,
        statusControlCount: 0
    )
    let verticalWithSelection = ToolbarLayoutMetrics.preferredSize(
        for: verticalSnapshot,
        visibleFrame: visibleFrame,
        statusControlCount: 0,
        selectedActionButtonCount: 1
    )
    let horizontalWithoutSelection = ToolbarLayoutMetrics.preferredSize(
        for: horizontalSnapshot,
        visibleFrame: visibleFrame,
        statusControlCount: 0
    )
    let horizontalWithSelection = ToolbarLayoutMetrics.preferredSize(
        for: horizontalSnapshot,
        visibleFrame: visibleFrame,
        statusControlCount: 0,
        selectedActionButtonCount: 1
    )

    #expect(verticalWithSelection.height == verticalWithoutSelection.height + ToolbarLayoutMetrics.buttonSize + ToolbarLayoutMetrics.gridSpacing)
    #expect(horizontalWithSelection.width == horizontalWithoutSelection.width + ToolbarLayoutMetrics.buttonSize + ToolbarLayoutMetrics.gridSpacing)
}

@Test func compactToolbarLayoutIsSmallerThanNormalToolbar() {
    let visibleFrame = CGRect(x: 0, y: 0, width: 1_400, height: 1_200)
    let normal = ToolbarLayoutMetrics.preferredSize(
        for: PreferencesSnapshot(toolbarOrientation: .vertical),
        visibleFrame: visibleFrame,
        statusControlCount: 0
    )
    let compact = ToolbarLayoutMetrics.preferredSize(
        for: PreferencesSnapshot(toolbarOrientation: .vertical, toolbarCompactMode: true),
        visibleFrame: visibleFrame,
        statusControlCount: 0
    )

    #expect(compact.width == normal.width)
    #expect(compact.height < normal.height)
}

@Test func visibleToolNormalizationKeepsRecoveryControlsAvailable() {
    #expect(PreferencesSnapshot.normalizedVisibleTools([]) == [.cursor, .pen])
    #expect(PreferencesSnapshot.normalizedVisibleTools([.whiteboard]) == [.cursor, .whiteboard, .blackboard])
    #expect(PreferencesSnapshot.normalizedVisibleTools([.blackboard]) == [.cursor, .whiteboard, .blackboard])
}

private func expectSessionError(_ expected: AnnotationSessionError, operation: () throws -> Void) {
    do {
        try operation()
        Issue.record("Expected \(expected), but no error was thrown.")
    } catch let error as AnnotationSessionError {
        #expect(error == expected)
    } catch {
        Issue.record("Expected \(expected), but received \(error).")
    }
}
