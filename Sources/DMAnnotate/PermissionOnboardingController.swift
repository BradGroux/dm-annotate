import AppKit
import SwiftUI

@MainActor
final class PermissionOnboardingController {
    private var window: NSWindow?
    private let defaults: UserDefaults
    private let didShowKey = "dmAnnotate.didShowPermissionOnboarding"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func showIfNeeded() {
        guard !defaults.bool(forKey: didShowKey) else { return }
        show()
        defaults.set(true, forKey: didShowKey)
    }

    func show() {
        if window == nil {
            makeWindow()
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() {
        let root = PermissionOnboardingView {
            self.window?.close()
        }
        let hostingView = NSHostingView(rootView: root)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Digital Meld Annotate Permissions"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        self.window = window
    }
}
