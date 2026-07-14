import AppKit
import Foundation

struct ToolbarFindPresentationDecision: Equatable {
    enum StaticReason: Equatable {
        case reduceMotion
        case highFrequencyInvocation
    }

    enum Presentation: Equatable {
        case staticFrontmost(reason: StaticReason)
    }

    var presentation: Presentation
    var shouldAnnounce: Bool
}

enum ToolbarFindPresentationPolicy {
    static let announcementCooldown: TimeInterval = 1

    static func decision(
        reduceMotionEnabled: Bool,
        currentUptime: TimeInterval,
        lastAnnouncementUptime: TimeInterval?
    ) -> ToolbarFindPresentationDecision {
        let reason: ToolbarFindPresentationDecision.StaticReason = reduceMotionEnabled
            ? .reduceMotion
            : .highFrequencyInvocation
        let shouldAnnounce = lastAnnouncementUptime.map {
            currentUptime - $0 >= announcementCooldown
        } ?? true

        return ToolbarFindPresentationDecision(
            presentation: .staticFrontmost(reason: reason),
            shouldAnnounce: shouldAnnounce
        )
    }
}

@MainActor
protocol ToolbarFindAccessibilityAnnouncing: AnyObject {
    func announceToolbarFound(from element: Any)
}

@MainActor
final class AppKitToolbarFindAccessibilityAnnouncer: ToolbarFindAccessibilityAnnouncing {
    func announceToolbarFound(from element: Any) {
        NSAccessibility.post(
            element: element,
            notification: .announcementRequested,
            userInfo: [
                .announcement: "Toolbar is visible.",
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }
}
