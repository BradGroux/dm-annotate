import AppKit
import Combine

@MainActor
final class ShortcutActivationRecovery {
    private var cancellable: AnyCancellable?

    init(
        notificationCenter: NotificationCenter = .default,
        restart: @escaping () -> Void
    ) {
        cancellable = notificationCenter.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { _ in restart() }
    }
}
