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
    private var lastToolbarCompactMode: Bool?
    private var lastVisibleTools: Set<AnnotationTool>?
    private var lastQuickColorCount: Int?
    private(set) var lastAppliedFrame: CGRect?
    private var suppressMovePersistenceUntil: Date?
    private var lastFindAnnouncementUptime: TimeInterval?
    private let findAccessibilityAnnouncer: any ToolbarFindAccessibilityAnnouncing
    private var stateAnnouncementCoalescer = ToolbarAccessibilityAnnouncementCoalescer()
    private var stateAnnouncementTask: Task<Void, Never>?
    private let stateAccessibilityAnnouncer: any ToolbarStateAccessibilityAnnouncing

    init(
        store: AnnotationStore,
        preferences: PreferencesController,
        runtimeState: AppRuntimeState,
        actions: ToolbarActions,
        findAccessibilityAnnouncer: any ToolbarFindAccessibilityAnnouncing = AppKitToolbarFindAccessibilityAnnouncer(),
        stateAccessibilityAnnouncer: any ToolbarStateAccessibilityAnnouncing = AppKitToolbarStateAccessibilityAnnouncer()
    ) {
        self.store = store
        self.preferences = preferences
        self.runtimeState = runtimeState
        self.actions = actions
        self.findAccessibilityAnnouncer = findAccessibilityAnnouncer
        self.stateAccessibilityAnnouncer = stateAccessibilityAnnouncer
        super.init()

        preferences.$snapshot
            .sink { [weak self] snapshot in
                self?.preferencesDidChange(snapshot)
            }
            .store(in: &cancellables)

        store.$selectedAnnotationID
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.resizeToFit()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(store.$activeTool, store.$whiteboardModeEnabled, runtimeState.$isSafeMode)
            .map { activeTool, whiteboardModeEnabled, isSafeMode in
                ToolbarAccessibilitySafetyMode.resolve(
                    activeTool: activeTool,
                    whiteboardModeEnabled: whiteboardModeEnabled,
                    isSafeMode: isSafeMode
                )
            }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleStateAnnouncement()
            }
            .store(in: &cancellables)

        store.$annotationsLocked
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleStateAnnouncement()
            }
            .store(in: &cancellables)

        store.$isVisible
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleStateAnnouncement()
            }
            .store(in: &cancellables)
    }

    deinit {
        stateAnnouncementTask?.cancel()
    }

    private func scheduleStateAnnouncement() {
        guard panel?.isVisible == true else { return }
        let currentUptime = ProcessInfo.processInfo.systemUptime
        stateAnnouncementCoalescer.schedule(
            ToolbarAccessibilityAnnouncementSnapshot(
                safetyMode: ToolbarAccessibilitySafetyMode.resolve(
                    activeTool: store.activeTool,
                    whiteboardModeEnabled: store.whiteboardModeEnabled,
                    isSafeMode: runtimeState.isSafeMode
                ),
                annotationsLocked: store.annotationsLocked,
                annotationsVisible: store.isVisible
            ),
            at: currentUptime
        )
        stateAnnouncementTask?.cancel()
        stateAnnouncementTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  let self,
                  let panel = self.panel,
                  panel.isVisible,
                  let snapshot = self.stateAnnouncementCoalescer.takeReady(
                    at: ProcessInfo.processInfo.systemUptime
                  ) else { return }
            self.stateAccessibilityAnnouncer.announce(snapshot.message, from: panel)
        }
    }

    func show() {
        prepareToolbarForPresentation()?.orderFrontRegardless()
    }

    func findToolbar() {
        guard let panel = prepareToolbarForPresentation() else { return }

        let currentUptime = ProcessInfo.processInfo.systemUptime
        let decision = ToolbarFindPresentationPolicy.decision(
            reduceMotionEnabled: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            currentUptime: currentUptime,
            lastAnnouncementUptime: lastFindAnnouncementUptime
        )

        switch decision.presentation {
        case .staticFrontmost:
            panel.orderFrontRegardless()
        }

        if decision.shouldAnnounce {
            lastFindAnnouncementUptime = currentUptime
            findAccessibilityAnnouncer.announceToolbarFound(from: panel)
        }
    }

    private func prepareToolbarForPresentation() -> NSPanel? {
        if panel == nil {
            makePanel()
        }
        resizeToFit(using: preferences.snapshot)
        return panel
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

    func toggleCompactMode() {
        var next = preferences.snapshot
        next.toolbarCompactMode.toggle()
        next.toolbarCollapsed = false
        applyToolbarLayout(next)
    }

    func resizeToFit() {
        _ = resizeToFit(using: preferences.snapshot)
    }

    func resizeToFitAndReturnSize() -> CGSize? {
        resizeToFit(using: preferences.snapshot)
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    var currentFrame: CGRect? {
        panel?.frame
    }

    var accessibilityVerificationPanel: NSPanel? {
        panel
    }

    var isFindPresentationNonAnimated: Bool {
        panel?.animationBehavior == NSWindow.AnimationBehavior.none
    }

    func temporarilyHideForCapture<T>(_ work: () -> T) -> T {
        let wasVisible = panel?.isVisible == true
        panel?.orderOut(nil)
        ToolbarTooltipController.shared.hide()
        NSApp.updateWindows()
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.03))

        let result = work()

        if wasVisible {
            panel?.orderFrontRegardless()
        }
        return result
    }

    @discardableResult
    private func resizeToFit(using snapshot: PreferencesSnapshot) -> CGSize? {
        guard panel != nil else { return nil }

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
        return size
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
        hostingView.sizingOptions = []
        let initialSize = preferredSize(for: preferences.snapshot)

        let panel = ToolbarPanel(
            contentRect: CGRect(origin: preferences.snapshot.toolbarOrigin, size: initialSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        hostingView.frame = CGRect(origin: .zero, size: initialSize)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = DMWindowLevels.toolbar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.setAccessibilityIdentifier("toolbar.window")

        self.panel = panel
        updateLastLayoutState(preferences.snapshot)
    }

    private func preferencesDidChange(_ snapshot: PreferencesSnapshot) {
        guard panel != nil else { return }

        let layoutChanged = snapshot.toolbarOrientation != lastToolbarOrientation ||
            snapshot.toolbarCollapsed != lastToolbarCollapsed ||
            snapshot.toolbarCompactMode != lastToolbarCompactMode ||
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
        lastToolbarCompactMode = snapshot.toolbarCompactMode
        lastVisibleTools = snapshot.visibleTools
        lastQuickColorCount = snapshot.paletteColors.count
    }

    private func preferredSize(for snapshot: PreferencesSnapshot) -> CGSize {
        if snapshot.toolbarCollapsed {
            return CGSize(width: 62, height: 42)
        }

        let visibleFrame = screenForToolbar(using: snapshot)?.visibleFrame ?? NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)

        return ToolbarLayoutMetrics.preferredSize(
            for: snapshot,
            visibleFrame: visibleFrame,
            statusControlCount: statusControlCount(),
            selectedActionButtonCount: selectedActionButtonCount()
        )
    }

    private func statusControlCount() -> Int {
        PermissionSummary.current().needsAttention ? 1 : 0
    }

    private func selectedActionButtonCount() -> Int {
        store.selectedAnnotationID == nil ? 0 : 1
    }

    private func clampedFrame(_ frame: CGRect, using snapshot: PreferencesSnapshot) -> CGRect {
        let targetScreen = NSScreen.screens.first { $0.visibleFrame.intersects(frame) } ?? screenForToolbar(using: snapshot) ?? NSScreen.main
        guard let screen = targetScreen else { return frame }

        let visible = screen.visibleFrame
        let maxX = max(visible.minX, visible.maxX - frame.width)
        let maxY = max(visible.minY, visible.maxY - frame.height)
        let x = min(max(frame.origin.x, visible.minX), maxX)
        let y = min(max(frame.origin.y, visible.minY), maxY)

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
        lastAppliedFrame = frame
        panel.setFrame(frame, display: display)
        panel.contentView?.setFrameSize(frame.size)
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
    var toggleToolbarCompactMode: () -> Void
    var expandToolbar: () -> Void
    var screenshot: () -> Void
    var regionScreenshot: () -> Void
    var copyScreenshot: () -> Void
    var saveScreenshot: () -> Void
    var saveAnnotationsScreenshot: () -> Void
    var revealLastScreenshot: () -> Void
    var showSettings: () -> Void
    var showPermissions: () -> Void
    var toggleAnnotationLock: () -> Void
    var findToolbar: () -> Void
    var resizeToolbar: () -> Void
}

final class ToolbarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
