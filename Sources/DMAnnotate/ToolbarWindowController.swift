import AppKit
import Combine
import DMAnnotateCore
import SwiftUI

@MainActor
final class ToolbarWindowController: NSObject, NSWindowDelegate {
    private let store: AnnotationStore
    private let preferences: PreferencesController
    private let runtimeState: AppRuntimeState
    private let actions: ToolbarActions
    private var panel: NSPanel?
    private var cancellables: Set<AnyCancellable> = []
    private var lastToolbarOrientation: ToolbarOrientation?
    private var lastToolbarCollapsed: Bool?

    init(store: AnnotationStore, preferences: PreferencesController, runtimeState: AppRuntimeState, actions: ToolbarActions) {
        self.store = store
        self.preferences = preferences
        self.runtimeState = runtimeState
        self.actions = actions
        super.init()

        preferences.$snapshot
            .sink { [weak self] snapshot in
                self?.preferencesDidChange(snapshot)
            }
            .store(in: &cancellables)
    }

    func show() {
        if panel == nil {
            makePanel()
        }
        resizeToFit()
        panel?.orderFrontRegardless()
    }

    func findToolbar() {
        show()
        guard let panel else { return }

        let originalFrame = panel.frame
        let shifted = originalFrame.offsetBy(dx: 14, dy: 0)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.10
            panel.animator().setFrame(shifted, display: true)
        } completionHandler: {
            Task { @MainActor in
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.10
                    panel.animator().setFrame(originalFrame, display: true)
                }
            }
        }
    }

    func toggleCollapsed() {
        preferences.update { snapshot in
            snapshot.toolbarCollapsed.toggle()
        }
        show()
    }

    func toggleOrientation() {
        preferences.update { snapshot in
            snapshot.toolbarOrientation = snapshot.toolbarOrientation == .vertical ? .horizontal : .vertical
        }
        show()
    }

    func resizeToFit() {
        guard let panel else { return }

        let size = preferredSize()
        let screen = screenForToolbar()
        let origin = toolbarOrigin(for: screen)
        let frame = clampedFrame(CGRect(origin: origin, size: size))
        panel.setFrame(frame, display: true)

        if frame.origin != origin {
            saveToolbarOrigin(frame.origin, screen: screen)
        }
    }

    func centerOnMainScreen() {
        guard let panel else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else { return }
        let frame = CGRect(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.midY - panel.frame.height / 2,
            width: panel.frame.width,
            height: panel.frame.height
        )
        panel.setFrame(clampedFrame(frame), display: true)
        saveToolbarOrigin(panel.frame.origin, screen: screen)
    }

    private func makePanel() {
        let root = ToolbarContentView(store: store, preferences: preferences, runtimeState: runtimeState, actions: actions)
        let hostingView = NSHostingView(rootView: root)

        let panel = ToolbarPanel(
            contentRect: CGRect(origin: preferences.snapshot.toolbarOrigin, size: preferredSize()),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.isReleasedWhenClosed = false

        self.panel = panel
        lastToolbarOrientation = preferences.snapshot.toolbarOrientation
        lastToolbarCollapsed = preferences.snapshot.toolbarCollapsed
    }

    private func preferencesDidChange(_ snapshot: PreferencesSnapshot) {
        guard panel != nil else { return }

        let layoutChanged = snapshot.toolbarOrientation != lastToolbarOrientation ||
            snapshot.toolbarCollapsed != lastToolbarCollapsed

        lastToolbarOrientation = snapshot.toolbarOrientation
        lastToolbarCollapsed = snapshot.toolbarCollapsed

        if layoutChanged {
            resizeToFit()
        }
    }

    private func preferredSize() -> CGSize {
        if preferences.snapshot.toolbarCollapsed {
            return CGSize(width: 62, height: 42)
        }

        let visibleFrame = screenForToolbar()?.visibleFrame ?? NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)

        switch preferences.snapshot.toolbarOrientation {
        case .vertical:
            let availableHeight = max(420, visibleFrame.height - 48)
            let preferredHeight = min(min(max(visibleFrame.height * 0.86, 680), 820), availableHeight)
            return CGSize(width: 86, height: preferredHeight)
        case .horizontal:
            return CGSize(width: min(max(visibleFrame.width - 120, 700), 980), height: 48)
        }
    }

    private func clampedFrame(_ frame: CGRect) -> CGRect {
        let targetScreen = NSScreen.screens.first { $0.visibleFrame.intersects(frame) } ?? screenForToolbar() ?? NSScreen.main
        guard let screen = targetScreen else { return frame }

        let visible = screen.visibleFrame
        let x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
        let y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)

        return CGRect(origin: CGPoint(x: x, y: y), size: frame.size)
    }

    private func screenForToolbar() -> NSScreen? {
        if let panelScreen = panel?.screen {
            return panelScreen
        }

        let origin = preferences.snapshot.toolbarOrigin
        return NSScreen.screens.first { $0.visibleFrame.contains(origin) } ?? NSScreen.main
    }

    private func toolbarOrigin(for screen: NSScreen?) -> CGPoint {
        guard let screen else { return preferences.snapshot.toolbarOrigin }
        let key = "\(screen.displayID)"
        return preferences.snapshot.toolbarOriginsByDisplayID[key] ?? preferences.snapshot.toolbarOrigin
    }

    private func saveToolbarOrigin(_ origin: CGPoint, screen: NSScreen?) {
        preferences.update { snapshot in
            snapshot.toolbarOrigin = origin
            if let screen {
                snapshot.toolbarOriginsByDisplayID["\(screen.displayID)"] = origin
            }
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel else { return }
        saveToolbarOrigin(panel.frame.origin, screen: panel.screen)
    }
}

struct ToolbarActions {
    var screenshot: () -> Void
    var regionScreenshot: () -> Void
    var copyScreenshot: () -> Void
    var saveScreenshot: () -> Void
    var revealLastScreenshot: () -> Void
    var showSettings: () -> Void
    var showPermissions: () -> Void
    var openCommandPalette: () -> Void
    var toggleAnnotationLock: () -> Void
    var findToolbar: () -> Void
}

final class ToolbarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
