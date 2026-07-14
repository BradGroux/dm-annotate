import AppKit

struct ScreenshotCaptureFeedback: Equatable, Sendable {
    enum Style: Equatable, Sendable {
        case success
        case failure
    }

    let style: Style
    let title: String
    let detail: String
    let accessibilityAnnouncement: String

    var symbolName: String {
        switch style {
        case .success:
            "checkmark.circle.fill"
        case .failure:
            "exclamationmark.triangle.fill"
        }
    }

    static let clipboardSuccess = ScreenshotCaptureFeedback(
        style: .success,
        title: "Screenshot copied",
        detail: "Ready to paste",
        accessibilityAnnouncement: "Screenshot copied. Ready to paste."
    )

    static let clipboardFailure = ScreenshotCaptureFeedback(
        style: .failure,
        title: "Couldn’t copy screenshot",
        detail: "Try again",
        accessibilityAnnouncement: "Couldn’t copy screenshot. Try again."
    )

    static let fileFailure = ScreenshotCaptureFeedback(
        style: .failure,
        title: "Couldn’t save screenshot",
        detail: "Check the save location",
        accessibilityAnnouncement: "Couldn’t save screenshot. Check the save location."
    )

    static let captureFailure = ScreenshotCaptureFeedback(
        style: .failure,
        title: "Couldn’t capture screenshot",
        detail: "Check Screen Recording access",
        accessibilityAnnouncement: "Couldn’t capture screenshot. Check Screen Recording access."
    )

    static func fileSuccess(
        _ file: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> ScreenshotCaptureFeedback {
        let destination = conciseDestination(
            file.deletingLastPathComponent(),
            homeDirectory: homeDirectory
        )
        return ScreenshotCaptureFeedback(
            style: .success,
            title: "Screenshot saved",
            detail: destination,
            accessibilityAnnouncement: "Screenshot saved to \(destination)."
        )
    }

    private static func conciseDestination(_ folder: URL, homeDirectory: URL) -> String {
        let folderPath = folder.standardizedFileURL.path
        let homePath = homeDirectory.standardizedFileURL.path

        if folderPath == homePath {
            return "~"
        }
        if folderPath.hasPrefix(homePath + "/") {
            return "~" + folderPath.dropFirst(homePath.count)
        }

        let name = folder.lastPathComponent
        return name.isEmpty ? folderPath : name
    }
}

struct ScreenshotFeedbackPlacement: Equatable, Sendable {
    let visibleFrame: CGRect

    func panelOrigin(panelSize: CGSize, inset: CGFloat) -> CGPoint {
        CGPoint(
            x: visibleFrame.maxX - panelSize.width - inset,
            y: visibleFrame.maxY - panelSize.height - inset
        )
    }
}

@MainActor
protocol ScreenshotFeedbackPresenting: AnyObject {
    func prepareForCapture()
    func present(_ feedback: ScreenshotCaptureFeedback, placement: ScreenshotFeedbackPlacement?)
}

struct ScreenshotFeedbackSession: Equatable, Sendable {
    fileprivate let generation: UInt
}

@MainActor
final class ScreenshotFeedbackCoordinator {
    private let presenter: any ScreenshotFeedbackPresenting
    private var generation: UInt = 0

    init(presenter: any ScreenshotFeedbackPresenting) {
        self.presenter = presenter
    }

    func beginSession() -> ScreenshotFeedbackSession {
        generation &+= 1
        presenter.prepareForCapture()
        return ScreenshotFeedbackSession(generation: generation)
    }

    func prepareForCapture() {
        presenter.prepareForCapture()
    }

    func present(
        _ feedback: ScreenshotCaptureFeedback,
        for session: ScreenshotFeedbackSession,
        placement: ScreenshotFeedbackPlacement?
    ) {
        guard session.generation == generation else { return }
        presenter.present(feedback, placement: placement)
    }
}

@MainActor
protocol ScreenshotAccessibilityAnnouncing: AnyObject {
    func announce(_ message: String, from element: Any)
}

@MainActor
final class AppKitScreenshotAccessibilityAnnouncer: ScreenshotAccessibilityAnnouncing {
    func announce(_ message: String, from element: Any) {
        NSAccessibility.post(
            element: element,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }
}

@MainActor
final class ScreenshotFeedbackPresenter: ScreenshotFeedbackPresenting {
    private enum Metrics {
        static let panelSize = CGSize(width: 284, height: 72)
        static let screenInset: CGFloat = 20
        static let contentInset: CGFloat = 14
        static let iconSize: CGFloat = 22
        static let duration: TimeInterval = 2.4
    }

    private let panel: NSPanel
    private let iconView: NSImageView
    private let titleLabel: NSTextField
    private let detailLabel: NSTextField
    private let accessibilityAnnouncer: any ScreenshotAccessibilityAnnouncing
    private var dismissalTimer: Timer?

    init(
        accessibilityAnnouncer: any ScreenshotAccessibilityAnnouncing = AppKitScreenshotAccessibilityAnnouncer()
    ) {
        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: Metrics.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        iconView = NSImageView()
        titleLabel = NSTextField(labelWithString: "")
        detailLabel = NSTextField(labelWithString: "")
        self.accessibilityAnnouncer = accessibilityAnnouncer
        configurePanel()
    }

    func prepareForCapture() {
        dismissalTimer?.invalidate()
        dismissalTimer = nil
        panel.orderOut(nil)
    }

    func present(_ feedback: ScreenshotCaptureFeedback, placement: ScreenshotFeedbackPlacement?) {
        dismissalTimer?.invalidate()

        iconView.image = NSImage(
            systemSymbolName: feedback.symbolName,
            accessibilityDescription: nil
        )
        iconView.contentTintColor = feedback.style == .success ? .systemGreen : .systemOrange
        titleLabel.stringValue = feedback.title
        detailLabel.stringValue = feedback.detail

        positionPanel(placement)
        panel.orderFrontRegardless()
        accessibilityAnnouncer.announce(feedback.accessibilityAnnouncement, from: panel)

        dismissalTimer = Timer.scheduledTimer(withTimeInterval: Metrics.duration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.panel.orderOut(nil)
                self?.dismissalTimer = nil
            }
        }
    }

    var isVisible: Bool { panel.isVisible }
    var isCaptureExcluded: Bool { panel.sharingType == .none }
    var isNonAnimated: Bool { panel.animationBehavior == .none }
    var ignoresPointerInput: Bool { panel.ignoresMouseEvents }
    var isNonactivating: Bool { panel.styleMask.contains(.nonactivatingPanel) }
    var frameOrigin: CGPoint { panel.frame.origin }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.sharingType = .none

        let effectView = NSVisualEffectView(frame: CGRect(origin: .zero, size: Metrics.panelSize))
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        detailLabel.font = .systemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingMiddle

        let labels = NSStackView(views: [titleLabel, detailLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        labels.translatesAutoresizingMaskIntoConstraints = false

        effectView.addSubview(iconView)
        effectView.addSubview(labels)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: Metrics.contentInset),
            iconView.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: Metrics.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: Metrics.iconSize),
            labels.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            labels.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -Metrics.contentInset),
            labels.centerYAnchor.constraint(equalTo: effectView.centerYAnchor)
        ])
        panel.contentView = effectView
    }

    private func positionPanel(_ placement: ScreenshotFeedbackPlacement?) {
        let resolvedPlacement = placement ?? (NSScreen.screenContainingMouse ?? NSScreen.main).map {
            ScreenshotFeedbackPlacement(visibleFrame: $0.visibleFrame)
        }
        guard let resolvedPlacement else { return }
        panel.setFrameOrigin(
            resolvedPlacement.panelOrigin(panelSize: Metrics.panelSize, inset: Metrics.screenInset)
        )
    }
}
