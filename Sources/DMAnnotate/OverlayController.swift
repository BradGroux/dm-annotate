import AppKit
import Combine
import DMAnnotateCore

@MainActor
final class OverlayController {
    private let store: AnnotationStore
    private var windows: [OverlayWindow] = []
    private var displayGeometry: [AnnotationDisplayGeometry] = []
    private var cancellables: Set<AnyCancellable> = []

    init(store: AnnotationStore) {
        self.store = store
    }

    func start() {
        rebuildWindows(for: NSScreen.screens)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        store.annotationInvalidations
            .sink { [weak self] invalidation in
                Task { @MainActor in
                    self?.apply(invalidation)
                }
            }
            .store(in: &cancellables)

        store.$activeTool
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateInteractivity()
                    self?.overlayViews.forEach { $0.syncInteractionState() }
                }
            }
            .store(in: &cancellables)

        let fullRedrawSignals: [AnyPublisher<Void, Never>] = [
            store.$isVisible.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            store.$whiteboardModeEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            store.$whiteboardBackground.dropFirst().map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(fullRedrawSignals)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    func temporarilyHideForCapture<T>(_ work: () -> T) -> T {
        windows.forEach { $0.orderOut(nil) }
        NSApp.updateWindows()
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.03))
        let result = work()
        windows.forEach { $0.orderFrontRegardless() }
        return result
    }

    func refresh() {
        windows.forEach { $0.contentView?.needsDisplay = true }
    }

    private func rebuildWindows(for screens: [NSScreen]) {
        windows.forEach { $0.close() }
        displayGeometry = screens.map(\.annotationDisplayGeometry)
        windows = screens.map { screen in
            let displayID = screen.displayID
            let window = OverlayWindow(frame: screen.frame)
            window.contentView = OverlayView(frame: CGRect(origin: .zero, size: screen.frame.size), store: store, displayID: displayID)
            window.orderFrontRegardless()
            return window
        }
        updateInteractivity()
    }

    private func updateInteractivity() {
        let capturesMouse = store.activeTool != .cursor
        windows.forEach { window in
            window.ignoresMouseEvents = !capturesMouse
            window.acceptsMouseMovedEvents = capturesMouse
        }
    }

    private var overlayViews: [OverlayView] {
        windows.compactMap { $0.contentView as? OverlayView }
    }

    private func apply(_ invalidation: AnnotationInvalidation) {
        overlayViews.forEach { $0.apply(invalidation) }
    }

    @objc private func screenParametersChanged() {
        let screens = NSScreen.screens
        let nextDisplayGeometry = screens.map(\.annotationDisplayGeometry)
        store.retargetAnnotations(
            from: displayGeometry,
            to: nextDisplayGeometry,
            fallbackDisplayID: NSScreen.main?.displayID ?? screens.first?.displayID
        )
        rebuildWindows(for: screens)
    }
}

final class OverlayWindow: NSPanel {
    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = DMWindowLevels.annotationOverlay
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

extension NSScreen {
    var displayID: UInt32 {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
    }

    var annotationDisplayGeometry: AnnotationDisplayGeometry {
        AnnotationDisplayGeometry(
            displayID: displayID,
            globalBounds: frame,
            globalUsableBounds: visibleFrame,
            scale: backingScaleFactor
        )
    }
}
