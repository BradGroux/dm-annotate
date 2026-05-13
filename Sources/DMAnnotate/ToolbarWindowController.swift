import AppKit
import Combine
import DMAnnotateCore
import SwiftUI

@MainActor
final class ToolbarWindowController: NSObject, NSWindowDelegate {
    private static let actionButtonCount = 8

    private let store: AnnotationStore
    private let preferences: PreferencesController
    private let runtimeState: AppRuntimeState
    private let actions: ToolbarActions
    private var panel: NSPanel?
    private var cancellables: Set<AnyCancellable> = []
    private var lastToolbarOrientation: ToolbarOrientation?
    private var lastToolbarCollapsed: Bool?
    private var lastVisibleTools: Set<AnnotationTool>?
    private var lastQuickColorCount: Int?
    private var suppressMovePersistenceUntil: Date?

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
        resizeToFit(using: preferences.snapshot)
        panel?.orderFrontRegardless()
    }

    func findToolbar() {
        show()
        guard let panel else { return }

        let originalFrame = panel.frame
        let shifted = originalFrame.offsetBy(dx: 14, dy: 0)
        suppressMovePersistence(for: 0.35)

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
        var next = preferences.snapshot
        next.toolbarCollapsed.toggle()
        applyToolbarLayout(next)
    }

    func expandToolbar() {
        var next = preferences.snapshot
        next.toolbarCollapsed = false
        applyToolbarLayout(next)
    }

    func toggleOrientation() {
        var next = preferences.snapshot
        next.toolbarOrientation = next.toolbarOrientation == .vertical ? .horizontal : .vertical
        next.toolbarCollapsed = false
        applyToolbarLayout(next)
    }

    func resizeToFit() {
        resizeToFit(using: preferences.snapshot)
    }

    private func resizeToFit(using snapshot: PreferencesSnapshot) {
        guard panel != nil else { return }

        let size = preferredSize(for: snapshot)
        let screen = screenForToolbar(using: snapshot)
        let origin = toolbarOrigin(for: screen, using: snapshot)
        let frame = clampedFrame(CGRect(origin: origin, size: size), using: snapshot)
        setPanelFrame(frame)

        if frame.origin != origin {
            DispatchQueue.main.async { [weak self] in
                self?.saveToolbarOrigin(frame.origin, screen: screen)
            }
        }
    }

    private func applyToolbarLayout(_ snapshot: PreferencesSnapshot) {
        if panel == nil {
            makePanel()
        }

        updateLastLayoutState(snapshot)
        resizeToFit(using: snapshot)
        preferences.update { current in
            current = snapshot
        }
        panel?.orderFrontRegardless()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.resizeToFit(using: self.preferences.snapshot)
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
        setPanelFrame(clampedFrame(frame, using: preferences.snapshot))
        saveToolbarOrigin(panel.frame.origin, screen: screen)
    }

    private func makePanel() {
        let root = ToolbarContentView(store: store, preferences: preferences, runtimeState: runtimeState, actions: actions)
        let hostingView = NSHostingView(rootView: root)

        let panel = ToolbarPanel(
            contentRect: CGRect(origin: preferences.snapshot.toolbarOrigin, size: preferredSize(for: preferences.snapshot)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = DMWindowLevels.toolbar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.isReleasedWhenClosed = false

        self.panel = panel
        updateLastLayoutState(preferences.snapshot)
    }

    private func preferencesDidChange(_ snapshot: PreferencesSnapshot) {
        guard panel != nil else { return }

        let layoutChanged = snapshot.toolbarOrientation != lastToolbarOrientation ||
            snapshot.toolbarCollapsed != lastToolbarCollapsed ||
            snapshot.visibleTools != lastVisibleTools ||
            snapshot.paletteColors.count != lastQuickColorCount

        updateLastLayoutState(snapshot)

        if layoutChanged {
            resizeToFit(using: snapshot)
        }
    }

    private func updateLastLayoutState(_ snapshot: PreferencesSnapshot) {
        lastToolbarOrientation = snapshot.toolbarOrientation
        lastToolbarCollapsed = snapshot.toolbarCollapsed
        lastVisibleTools = snapshot.visibleTools
        lastQuickColorCount = snapshot.paletteColors.count
    }

    private func preferredSize(for snapshot: PreferencesSnapshot) -> CGSize {
        if snapshot.toolbarCollapsed {
            return CGSize(width: 62, height: 42)
        }

        let visibleFrame = screenForToolbar(using: snapshot)?.visibleFrame ?? NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)

        switch snapshot.toolbarOrientation {
        case .vertical:
            let availableHeight = max(42, visibleFrame.height - 24)
            return CGSize(width: 86, height: min(estimatedVerticalToolbarHeight(for: snapshot), availableHeight))
        case .horizontal:
            let availableWidth = max(700, visibleFrame.width - 24)
            return CGSize(width: min(estimatedHorizontalToolbarWidth(for: snapshot), availableWidth), height: 48)
        }
    }

    private func estimatedVerticalToolbarHeight(for snapshot: PreferencesSnapshot) -> CGFloat {
        let outerPadding: CGFloat = 12
        let contentBottomPadding: CGFloat = 6
        let stackSpacing: CGFloat = 6
        let dragHandleHeight: CGFloat = 16
        let dividerHeight: CGFloat = 5
        let menuControlHeight: CGFloat = 30
        let childCount = 10
        let menuControlCount = 2
        let topControls = 2 + statusControlCount()
        let toolControls = snapshot.visibleTools.count
        let colorControls = min(snapshot.paletteColors.count, 4) + 2

        return outerPadding +
            dragHandleHeight +
            gridHeight(itemCount: topControls, columns: 2) +
            dividerHeight +
            gridHeight(itemCount: toolControls, columns: 2) +
            dividerHeight +
            gridHeight(itemCount: colorControls, columns: 2) +
            CGFloat(menuControlCount) * menuControlHeight +
            dividerHeight +
            gridHeight(itemCount: Self.actionButtonCount, columns: 2) +
            CGFloat(childCount - 1) * stackSpacing +
            contentBottomPadding
    }

    private func estimatedHorizontalToolbarWidth(for snapshot: PreferencesSnapshot) -> CGFloat {
        let buttonWidth: CGFloat = 30
        let spacing: CGFloat = 6
        let outerPadding: CGFloat = 12
        let dragHandleWidth: CGFloat = 16
        let dividerWidth: CGFloat = 5
        let menuControlWidth: CGFloat = 66
        let menuControlCount = 2
        let fixedButtons = 2
        let statusButtons = statusControlCount()
        let toolButtons = snapshot.visibleTools.count
        let colorButtons = min(snapshot.paletteColors.count, 4) + 2
        let actionButtons = Self.actionButtonCount
        let buttonCount = fixedButtons + statusButtons + toolButtons + colorButtons + actionButtons
        let elementCount = 1 + buttonCount + 3 + menuControlCount

        return outerPadding +
            dragHandleWidth +
            CGFloat(buttonCount) * buttonWidth +
            CGFloat(3) * dividerWidth +
            CGFloat(menuControlCount) * menuControlWidth +
            CGFloat(max(elementCount - 1, 0)) * spacing
    }

    private func gridHeight(itemCount: Int, columns: Int) -> CGFloat {
        let rowCount = max(1, Int(ceil(Double(itemCount) / Double(columns))))
        let buttonHeight: CGFloat = 30
        let rowSpacing: CGFloat = 6
        return CGFloat(rowCount) * buttonHeight + CGFloat(max(rowCount - 1, 0)) * rowSpacing
    }

    private func statusControlCount() -> Int {
        PermissionSummary.current().needsAttention ? 1 : 0
    }

    private func clampedFrame(_ frame: CGRect, using snapshot: PreferencesSnapshot) -> CGRect {
        let targetScreen = NSScreen.screens.first { $0.visibleFrame.intersects(frame) } ?? screenForToolbar(using: snapshot) ?? NSScreen.main
        guard let screen = targetScreen else { return frame }

        let visible = screen.visibleFrame
        let x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
        let y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)

        return CGRect(origin: CGPoint(x: x, y: y), size: frame.size)
    }

    private func screenForToolbar(using snapshot: PreferencesSnapshot) -> NSScreen? {
        if let panelScreen = panel?.screen {
            return panelScreen
        }

        let origin = snapshot.toolbarOrigin
        return NSScreen.screens.first { $0.visibleFrame.contains(origin) } ?? NSScreen.main
    }

    private func toolbarOrigin(for screen: NSScreen?, using snapshot: PreferencesSnapshot) -> CGPoint {
        guard let screen else { return snapshot.toolbarOrigin }
        let key = "\(screen.displayID)"
        return snapshot.toolbarOriginsByDisplayID[key] ?? snapshot.toolbarOrigin
    }

    private func saveToolbarOrigin(_ origin: CGPoint, screen: NSScreen?) {
        let key = screen.map { "\($0.displayID)" }
        if preferences.snapshot.toolbarOrigin == origin,
           key.map({ preferences.snapshot.toolbarOriginsByDisplayID[$0] == origin }) ?? true {
            return
        }

        preferences.update { snapshot in
            snapshot.toolbarOrigin = origin
            if let key {
                snapshot.toolbarOriginsByDisplayID[key] = origin
            }
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel else { return }
        guard !isMovePersistenceSuppressed else { return }
        saveToolbarOrigin(panel.frame.origin, screen: panel.screen)
    }

    private func setPanelFrame(_ frame: CGRect, display: Bool = true, suppressMoveFor interval: TimeInterval = 0.12) {
        guard let panel else { return }

        suppressMovePersistence(for: interval)
        panel.setFrame(frame, display: display)
    }

    private func suppressMovePersistence(for interval: TimeInterval) {
        suppressMovePersistenceUntil = Date().addingTimeInterval(interval)
    }

    private var isMovePersistenceSuppressed: Bool {
        guard let suppressMovePersistenceUntil else { return false }
        if Date() < suppressMovePersistenceUntil {
            return true
        }

        self.suppressMovePersistenceUntil = nil
        return false
    }
}

struct ToolbarActions {
    var toggleToolbarCollapsed: () -> Void
    var toggleToolbarOrientation: () -> Void
    var expandToolbar: () -> Void
    var screenshot: () -> Void
    var regionScreenshot: () -> Void
    var copyScreenshot: () -> Void
    var saveScreenshot: () -> Void
    var revealLastScreenshot: () -> Void
    var showSettings: () -> Void
    var showPermissions: () -> Void
    var toggleAnnotationLock: () -> Void
    var findToolbar: () -> Void
}

final class ToolbarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
