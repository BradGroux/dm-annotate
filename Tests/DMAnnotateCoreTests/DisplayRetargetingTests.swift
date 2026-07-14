import CoreGraphics
import Foundation
import Testing
@testable import DMAnnotateCore

private let sourceDisplay = AnnotationDisplayGeometry(
    displayID: 99,
    globalBounds: CGRect(x: -1_000, y: 0, width: 1_000, height: 800),
    globalUsableBounds: CGRect(x: -1_000, y: 0, width: 1_000, height: 800),
    scale: 2
)

private let fallbackDisplay = AnnotationDisplayGeometry(
    displayID: 1,
    globalBounds: CGRect(x: 0, y: 0, width: 500, height: 400),
    globalUsableBounds: CGRect(x: 0, y: 0, width: 500, height: 400),
    scale: 1
)

@Test func negativeGlobalOriginsBecomeOverlayLocalUsableBounds() {
    let display = AnnotationDisplayGeometry(
        displayID: 5,
        globalBounds: CGRect(x: -1_000, y: -200, width: 1_000, height: 800),
        globalUsableBounds: CGRect(x: -980, y: -176, width: 960, height: 740),
        scale: 2
    )

    #expect(display.usableBounds == CGRect(x: 20, y: 24, width: 960, height: 740))
}

@Test func availableDisplayAnnotationsRemainByteForByteUnchanged() {
    let annotation = AnnotationItem(
        displayID: 1,
        kind: .pen,
        points: [CGPoint(x: 20, y: 30), CGPoint(x: 200, y: 160)],
        color: .red,
        lineWidth: 12
    )
    let rearranged = AnnotationDisplayGeometry(
        displayID: 1,
        globalBounds: CGRect(x: -2_560, y: -300, width: 2_560, height: 1_440),
        globalUsableBounds: CGRect(x: -2_560, y: -276, width: 2_560, height: 1_390),
        scale: 2
    )

    let result = AnnotationDisplayRetargeter.retarget(
        [annotation],
        sourceDisplays: [fallbackDisplay],
        destinationDisplays: [rearranged],
        fallbackDisplayID: 1
    )

    #expect(result == [annotation])
}

@Test func missingLargeDisplayMapsPaintedIntentIntoSmallerMixedScaleFallback() {
    let annotation = AnnotationItem(
        displayID: 99,
        kind: .rectangle,
        points: [CGPoint(x: 800, y: 600), CGPoint(x: 900, y: 700)],
        color: .blue,
        lineWidth: 0
    )

    let result = AnnotationDisplayRetargeter.retarget(
        [annotation],
        sourceDisplays: [sourceDisplay],
        destinationDisplays: [fallbackDisplay],
        fallbackDisplayID: 1
    )

    #expect(result[0].displayID == 1)
    #expect(result[0].points == [CGPoint(x: 375, y: 275), CGPoint(x: 475, y: 375)])
    #expect(result[0].boundingRect.intersects(fallbackDisplay.usableBounds))
    #expect(fallbackDisplay.usableBounds.contains(result[0].boundingRect))
}

@Test func oversizedPaintedGeometryIsCenteredAndStillIntersectsDestination() {
    let annotation = AnnotationItem(
        displayID: 99,
        kind: .highlighter,
        points: [CGPoint(x: 0, y: 0), CGPoint(x: 1_000, y: 1_000)],
        color: .yellow,
        lineWidth: 64
    )
    let tiny = AnnotationDisplayGeometry(
        displayID: 7,
        globalBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
        globalUsableBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
        scale: 2
    )

    let result = AnnotationDisplayRetargeter.retarget(
        [annotation],
        sourceDisplays: [sourceDisplay],
        destinationDisplays: [tiny],
        fallbackDisplayID: 7
    )[0]

    #expect(result.boundingRect.midX == 50)
    #expect(result.boundingRect.midY == 50)
    #expect(result.boundingRect.intersects(tiny.usableBounds))
}

@Test func oversizedRetargetDoesNotCreateCoordinatesThatCannotBeSavedAgain() {
    let limit = AnnotationSessionDocument.maximumCoordinateMagnitude
    let annotation = AnnotationItem(
        displayID: 99,
        kind: .rectangle,
        points: [CGPoint(x: -limit, y: -limit), CGPoint(x: limit, y: limit)],
        color: .red,
        lineWidth: 64
    )

    let result = AnnotationDisplayRetargeter.retarget(
        [annotation],
        sourceDisplays: [],
        destinationDisplays: [fallbackDisplay],
        fallbackDisplayID: 1
    )[0]

    #expect(result.points.allSatisfy { abs($0.x) <= limit && abs($0.y) <= limit })
    #expect(result.boundingRect.intersects(fallbackDisplay.usableBounds))
}

@Test func missingSourceGeometryCentersPaintedBoundsInFallback() {
    let annotation = AnnotationItem(
        displayID: 99,
        kind: .arrow,
        points: [CGPoint(x: 2_800, y: 1_400), CGPoint(x: 3_500, y: 1_900)],
        color: .green,
        lineWidth: 8
    )

    let result = AnnotationDisplayRetargeter.retarget(
        [annotation],
        sourceDisplays: [],
        destinationDisplays: [fallbackDisplay],
        fallbackDisplayID: 1
    )[0]

    #expect(result.displayID == 1)
    #expect(result.boundingRect.midX == fallbackDisplay.usableBounds.midX)
    #expect(result.boundingRect.midY == fallbackDisplay.usableBounds.midY)
    #expect(result.boundingRect.intersects(fallbackDisplay.usableBounds))
}

@Test func noDestinationsLeaveAnnotationsUnchanged() {
    let annotation = AnnotationItem(
        displayID: 99,
        kind: .text,
        points: [CGPoint(x: 2_800, y: 1_400)],
        color: .red,
        lineWidth: 3,
        text: "Keep me"
    )

    #expect(AnnotationDisplayRetargeter.retarget(
        [annotation],
        sourceDisplays: [sourceDisplay],
        destinationDisplays: [],
        fallbackDisplayID: nil
    ) == [annotation])
}

@Test func disconnectedAnnotationStaysOnFallbackAfterOriginalDisplayReconnects() {
    let annotation = AnnotationItem(
        displayID: 99,
        kind: .line,
        points: [CGPoint(x: 100, y: 100), CGPoint(x: 200, y: 200)],
        color: .red,
        lineWidth: 3
    )
    let disconnected = AnnotationDisplayRetargeter.retarget(
        [annotation],
        sourceDisplays: [sourceDisplay],
        destinationDisplays: [fallbackDisplay],
        fallbackDisplayID: 1
    )

    let reconnected = AnnotationDisplayRetargeter.retarget(
        disconnected,
        sourceDisplays: [fallbackDisplay],
        destinationDisplays: [fallbackDisplay, sourceDisplay],
        fallbackDisplayID: 1
    )

    #expect(reconnected == disconnected)
    #expect(reconnected[0].displayID == 1)
}

@Test func unavailableFallbackChoosesLowestAvailableDisplayIDDeterministically() {
    let annotation = AnnotationItem(
        displayID: 99,
        kind: .line,
        points: [CGPoint(x: 10, y: 10), CGPoint(x: 20, y: 20)],
        color: .red,
        lineWidth: 3
    )
    let display7 = AnnotationDisplayGeometry(
        displayID: 7,
        globalBounds: CGRect(x: 500, y: 0, width: 500, height: 400),
        globalUsableBounds: CGRect(x: 500, y: 0, width: 500, height: 400),
        scale: 1
    )

    let result = AnnotationDisplayRetargeter.retarget(
        [annotation],
        sourceDisplays: [sourceDisplay],
        destinationDisplays: [display7, fallbackDisplay],
        fallbackDisplayID: 404
    )

    #expect(result[0].displayID == 1)
}

@Test func sessionRetargetingUsesPersistedDisplayGeometry() {
    let annotation = AnnotationItem(
        displayID: 99,
        kind: .rectangle,
        points: [CGPoint(x: 800, y: 600), CGPoint(x: 900, y: 700)],
        color: .blue,
        lineWidth: 0
    )
    let session = AnnotationSessionDocument(
        annotations: [annotation],
        currentColor: .red,
        strokeWidth: 3,
        textFontSize: 24,
        textFontWeight: .semibold,
        isVisible: true,
        annotationsLocked: false,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white,
        displayGeometry: [sourceDisplay]
    )

    let result = session.retargetingMissingDisplays(
        to: [fallbackDisplay],
        fallbackDisplayID: 1
    )

    #expect(result.annotations[0].points == [CGPoint(x: 375, y: 275), CGPoint(x: 475, y: 375)])
    #expect(result.displayGeometry == [fallbackDisplay])
}

@Test func sessionRoundTripPreservesDisplayGeometryForLaterRetargeting() throws {
    let session = AnnotationSessionDocument(
        annotations: [],
        currentColor: .red,
        strokeWidth: 3,
        textFontSize: 24,
        textFontWeight: .semibold,
        isVisible: true,
        annotationsLocked: false,
        whiteboardModeEnabled: false,
        whiteboardBackground: .white,
        displayGeometry: [sourceDisplay]
    )

    let decoded = try AnnotationSessionDocument.decode(from: session.encodedData())

    #expect(decoded.displayGeometry == [sourceDisplay])
}

@MainActor
@Test func liveStoreRetargetLeavesNoAnnotationsOnUnrenderedDisplays() {
    let missing = AnnotationItem(
        displayID: 99,
        kind: .rectangle,
        points: [CGPoint(x: 800, y: 600), CGPoint(x: 900, y: 700)],
        color: .blue,
        lineWidth: 0
    )
    let available = AnnotationItem(
        displayID: 1,
        kind: .pen,
        points: [CGPoint(x: 10, y: 10), CGPoint(x: 20, y: 20)],
        color: .red,
        lineWidth: 3
    )
    let store = AnnotationStore()
    store.add(missing)
    store.add(available)

    let didRetarget = store.retargetAnnotations(
        from: [sourceDisplay],
        to: [fallbackDisplay],
        fallbackDisplayID: 1
    )

    #expect(didRetarget)
    #expect(Set(store.annotations.map(\.displayID)) == [1])
    #expect(store.annotation(id: available.id) == available)
    #expect(!store.canUndo)
    #expect(!store.canRedo)
}
