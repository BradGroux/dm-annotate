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
            makeWindow(initialSection: .general)
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func show(section: SettingsSection) {
        if window == nil {
            makeWindow(initialSection: section)
        } else {
            setRootView(initialSection: section)
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func toggle() {
        if window?.isVisible == true {
            window?.orderOut(nil)
        } else {
            show()
        }
    }

    private func makeWindow(initialSection: SettingsSection) {
        let hostingView = NSHostingView(rootView: settingsView(initialSection: initialSection))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 920, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Digital Meld Annotate Settings"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        self.window = window
    }

    private func setRootView(initialSection: SettingsSection) {
        window?.contentView = NSHostingView(rootView: settingsView(initialSection: initialSection))
    }

    private func settingsView(initialSection: SettingsSection) -> SettingsView {
        SettingsView(
            store: store,
            preferences: preferences,
            shortcutController: shortcutController,
            runtimeState: runtimeState,
            initialSection: initialSection
        )
    }
}
