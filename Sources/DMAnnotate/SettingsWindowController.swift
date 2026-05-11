import AppKit
import DMAnnotateCore
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let store: AnnotationStore
    private let preferences: PreferencesController
    private let shortcutController: ShortcutController
    private let runtimeState: AppRuntimeState
    private var window: NSWindow?

    init(store: AnnotationStore, preferences: PreferencesController, shortcutController: ShortcutController, runtimeState: AppRuntimeState) {
        self.store = store
        self.preferences = preferences
        self.shortcutController = shortcutController
        self.runtimeState = runtimeState
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
        let root = SettingsView(store: store, preferences: preferences, shortcutController: shortcutController, runtimeState: runtimeState)
        let hostingView = NSHostingView(rootView: root)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 760, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Digital Meld Annotate Settings"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        self.window = window
    }
}
