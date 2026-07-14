import Testing
@testable import DMAnnotate

@Test func normalFindToolbarInvocationUsesStaticFrontmostFeedback() {
    let decision = ToolbarFindPresentationPolicy.decision(
        reduceMotionEnabled: false,
        currentUptime: 10,
        lastAnnouncementUptime: nil
    )

    #expect(
        decision.presentation == .staticFrontmost(reason: .highFrequencyInvocation)
    )
    #expect(decision.shouldAnnounce)
}

@Test func reduceMotionFindToolbarInvocationNeverUsesPositionalMovement() {
    let decision = ToolbarFindPresentationPolicy.decision(
        reduceMotionEnabled: true,
        currentUptime: 10,
        lastAnnouncementUptime: nil
    )

    #expect(decision.presentation == .staticFrontmost(reason: .reduceMotion))
    #expect(decision.shouldAnnounce)
}

@Test func rapidFindToolbarReinvocationBoundsAccessibilityAnnouncements() {
    let rapidDecision = ToolbarFindPresentationPolicy.decision(
        reduceMotionEnabled: false,
        currentUptime: 10.25,
        lastAnnouncementUptime: 10
    )
    let laterDecision = ToolbarFindPresentationPolicy.decision(
        reduceMotionEnabled: false,
        currentUptime: 11,
        lastAnnouncementUptime: 10
    )

    #expect(
        rapidDecision.presentation == .staticFrontmost(reason: .highFrequencyInvocation)
    )
    #expect(!rapidDecision.shouldAnnounce)
    #expect(laterDecision.shouldAnnounce)
}
