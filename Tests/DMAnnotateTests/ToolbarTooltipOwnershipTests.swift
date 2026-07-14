import Foundation
import Testing
@testable import DMAnnotate

@Test func adjacentToolbarHoverExitCannotDismissTheCurrentTooltip() {
    let firstControl = UUID()
    let adjacentControl = UUID()
    var ownership = ToolbarTooltipOwnership()

    ownership.claim(firstControl)
    ownership.claim(adjacentControl)
    let didReleaseFirstControl = ownership.release(firstControl)

    #expect(!didReleaseFirstControl)
    #expect(ownership.activeOwner == adjacentControl)
}

@Test func currentToolbarControlCanDismissItsTooltip() {
    let control = UUID()
    var ownership = ToolbarTooltipOwnership()

    ownership.claim(control)
    let didReleaseControl = ownership.release(control)

    #expect(didReleaseControl)
    #expect(ownership.activeOwner == nil)
}

@Test func disablingToolbarTooltipsClearsCurrentOwnership() {
    var ownership = ToolbarTooltipOwnership()

    ownership.claim(UUID())
    ownership.releaseAll()

    #expect(ownership.activeOwner == nil)
}
