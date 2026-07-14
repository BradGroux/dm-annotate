import AppKit
import Testing
@testable import DMAnnotate

@Test func clipboardFeedbackDistinguishesSuccessAndFailure() {
    let success = ScreenshotCaptureFeedback.clipboardSuccess
    let failure = ScreenshotCaptureFeedback.clipboardFailure

    #expect(success.style == .success)
    #expect(success.title == "Screenshot copied")
    #expect(success.detail == "Ready to paste")
    #expect(success.accessibilityAnnouncement == "Screenshot copied. Ready to paste.")

    #expect(failure.style == .failure)
    #expect(failure.title == "Couldn’t copy screenshot")
    #expect(failure.detail == "Try again")
    #expect(failure.accessibilityAnnouncement == "Couldn’t copy screenshot. Try again.")
}

@Test func fileFeedbackIncludesAConciseHomeRelativeDestination() {
    let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
    let file = home.appendingPathComponent("Desktop/DM Annotate 2026-07-14.png")

    let feedback = ScreenshotCaptureFeedback.fileSuccess(file, homeDirectory: home)

    #expect(feedback.style == .success)
    #expect(feedback.title == "Screenshot saved")
    #expect(feedback.detail == "~/Desktop")
    #expect(feedback.accessibilityAnnouncement == "Screenshot saved to ~/Desktop.")
}

@Test func fileFeedbackUsesTheFolderNameOutsideTheHomeDirectory() {
    let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
    let file = URL(fileURLWithPath: "/Volumes/Exports/DM Annotate.png")

    let feedback = ScreenshotCaptureFeedback.fileSuccess(file, homeDirectory: home)

    #expect(feedback.detail == "Exports")
    #expect(feedback.accessibilityAnnouncement == "Screenshot saved to Exports.")
}

@Test func saveAndCaptureFailuresProvideDistinctRecoveryGuidance() {
    let saveFailure = ScreenshotCaptureFeedback.fileFailure
    let captureFailure = ScreenshotCaptureFeedback.captureFailure

    #expect(saveFailure.style == .failure)
    #expect(saveFailure.title == "Couldn’t save screenshot")
    #expect(saveFailure.detail == "Check the save location")
    #expect(captureFailure.title == "Couldn’t capture screenshot")
    #expect(captureFailure.detail == "Check Screen Recording access")
}

@MainActor
@Test func feedbackPanelIsCaptureExcludedAndNonAnimated() {
    let announcer = TestScreenshotAccessibilityAnnouncer()
    let presenter = ScreenshotFeedbackPresenter(accessibilityAnnouncer: announcer)

    #expect(presenter.isCaptureExcluded)
    #expect(presenter.isNonAnimated)
    #expect(presenter.ignoresPointerInput)
    #expect(presenter.isNonactivating)

    presenter.present(.clipboardSuccess, placement: nil)
    #expect(announcer.messages == ["Screenshot copied. Ready to paste."])
    presenter.prepareForCapture()
}

@MainActor
@Test func feedbackCoordinatorSuppressesOutOfOrderAndPreSelectionOutcomes() {
    let presenter = TestScreenshotFeedbackPresenter()
    let coordinator = ScreenshotFeedbackCoordinator(presenter: presenter)
    let placement = ScreenshotFeedbackPlacement(visibleFrame: CGRect(x: 100, y: 200, width: 900, height: 700))
    let priorCapture = coordinator.beginSession()
    let regionSelection = coordinator.beginSession()
    #expect(presenter.prepareCount == 2)

    coordinator.present(.clipboardSuccess, for: priorCapture, placement: placement)
    #expect(presenter.presentations.isEmpty)

    coordinator.present(.fileSuccess(URL(fileURLWithPath: "/tmp/capture.png")), for: regionSelection, placement: placement)
    #expect(presenter.presentations.map(\.feedback.title) == ["Screenshot saved"])
    #expect(presenter.presentations.first?.placement == placement)
}

@MainActor
@Test func feedbackPlacementUsesTheCaptureFrameDeterministically() {
    let announcer = TestScreenshotAccessibilityAnnouncer()
    let presenter = ScreenshotFeedbackPresenter(accessibilityAnnouncer: announcer)
    let placement = ScreenshotFeedbackPlacement(visibleFrame: CGRect(x: 1200, y: 100, width: 1000, height: 800))

    presenter.present(.clipboardSuccess, placement: placement)

    #expect(presenter.frameOrigin == CGPoint(x: 1896, y: 808))
    presenter.prepareForCapture()
}

@MainActor
private final class TestScreenshotAccessibilityAnnouncer: ScreenshotAccessibilityAnnouncing {
    private(set) var messages: [String] = []

    func announce(_ message: String, from element: Any) {
        messages.append(message)
    }
}

@MainActor
private final class TestScreenshotFeedbackPresenter: ScreenshotFeedbackPresenting {
    struct Presentation {
        let feedback: ScreenshotCaptureFeedback
        let placement: ScreenshotFeedbackPlacement?
    }

    private(set) var prepareCount = 0
    private(set) var presentations: [Presentation] = []

    func prepareForCapture() {
        prepareCount += 1
    }

    func present(_ feedback: ScreenshotCaptureFeedback, placement: ScreenshotFeedbackPlacement?) {
        presentations.append(Presentation(feedback: feedback, placement: placement))
    }
}
