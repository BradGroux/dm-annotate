import AppKit
import DMAnnotateCore

@MainActor
final class ShortcutController {
    private let preferences: PreferencesController
    private let store: AnnotationStore
    private let actions: AppActions
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var escapeQuitDeadline: Date?
    private let doubleEscapeInterval: TimeInterval = 0.85

    init(preferences: PreferencesController, store: AnnotationStore, actions: AppActions) {
        self.preferences = preferences
        self.store = store
        self.actions = actions
    }

    func start() {
        stop()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handle(event, scope: .global)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, handle(event, scope: .local) else { return event }
            return nil
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    func handle(_ event: NSEvent, scope: ShortcutEventScope = .local) -> Bool {
        if handleEmergency(event, scope: scope) {
            return true
        }

        let descriptor = ShortcutDescriptor(event: event).normalized
        guard !descriptor.isEmpty else { return false }

        let shortcuts = preferences.snapshot.shortcuts
            .mapValues(ShortcutDescriptor.normalize)
            .filter { ShortcutDescriptor.isValid($0.value) }
        guard let action = shortcuts.first(where: { $0.value == descriptor })?.key else { return false }

        perform(action)
        return true
    }

    private func handleEmergency(_ event: NSEvent, scope: ShortcutEventScope) -> Bool {
        if scope == .local, isCommandQ(event) {
            actions.quit()
            return true
        }

        guard isPlainEscape(event) else {
            expireEscapeArmIfNeeded()
            return false
        }

        guard !shouldDeferEscapeToFocusedControl else {
            return false
        }

        let now = Date()
        if let escapeQuitDeadline, now <= escapeQuitDeadline {
            actions.quit()
            return true
        }

        guard isScreenControlContext else {
            escapeQuitDeadline = nil
            return false
        }

        store.exitScreenControls()
        escapeQuitDeadline = now.addingTimeInterval(doubleEscapeInterval)
        return true
    }

    private func isCommandQ(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        return flags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "q"
    }

    private func isPlainEscape(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        return event.keyCode == 53 && flags.isEmpty
    }

    private var isScreenControlContext: Bool {
        store.isControllingScreen || NSApp.keyWindow?.level == .screenSaver
    }

    private var shouldDeferEscapeToFocusedControl: Bool {
        if NSApp.keyWindow is RegionSelectionWindow {
            return true
        }

        return NSApp.keyWindow?.firstResponder is NSTextView
    }

    private func expireEscapeArmIfNeeded() {
        guard let escapeQuitDeadline, Date() > escapeQuitDeadline else { return }
        self.escapeQuitDeadline = nil
    }

    private func perform(_ action: ShortcutAction) {
        switch action {
        case .toggleToolbarCollapsed:
            actions.toggleToolbarCollapsed()
        case .toggleToolbarOrientation:
            actions.toggleToolbarOrientation()
        case .findToolbar:
            actions.findToolbar()
        case .toggleAnnotationMode:
            store.setActiveTool(store.activeTool == .cursor ? .pen : .cursor)
        case .cursorMode:
            store.exitScreenControls()
        case .selectPen:
            store.setActiveTool(.pen)
        case .selectHighlighter:
            store.setActiveTool(.highlighter)
        case .selectEraser:
            store.setActiveTool(.eraser)
        case .selectLine:
            store.setActiveTool(.line)
        case .selectRectangle:
            store.setActiveTool(.rectangle)
        case .selectEllipse:
            store.setActiveTool(.ellipse)
        case .selectArrow:
            store.setActiveTool(.arrow)
        case .selectText:
            store.setActiveTool(.text)
        case .selectLaser:
            store.setActiveTool(.laser)
        case .toggleWhiteboard:
            store.setActiveTool(.whiteboard)
        case .toggleAnnotationLock:
            store.toggleAnnotationLock()
        case .toggleAnnotationVisibility:
            store.toggleVisibility()
        case .undo:
            store.undo()
        case .redo:
            store.redo()
        case .quickColor1:
            setQuickColor(at: 0)
        case .quickColor2:
            setQuickColor(at: 1)
        case .quickColor3:
            setQuickColor(at: 2)
        case .quickColor4:
            setQuickColor(at: 3)
        case .customColor:
            ToolbarColorPanelController.shared.show(currentColor: store.currentColor, store: store)
        case .decreaseStrokeWidth:
            store.decreaseStrokeWidth()
        case .increaseStrokeWidth:
            store.increaseStrokeWidth()
        case .clearAll:
            store.clearAll()
        case .screenshot:
            actions.screenshot()
        case .copyScreenshot:
            actions.copyScreenshot()
        case .saveScreenshot:
            actions.saveScreenshot()
        case .regionScreenshot:
            actions.regionScreenshot()
        case .revealLastScreenshot:
            actions.revealLastScreenshot()
        case .showPermissions:
            actions.showPermissions()
        case .showSettings:
            actions.showSettings()
        case .commandPalette:
            actions.showCommandPalette()
        }
    }

    private func setQuickColor(at index: Int) {
        guard preferences.snapshot.quickColors.indices.contains(index) else { return }
        store.setQuickColor(preferences.snapshot.quickColors[index])
    }
}

enum ShortcutEventScope {
    case local
    case global
}

struct ShortcutDescriptor: Equatable, Hashable {
    var normalized: String

    init(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        let key = ShortcutDescriptor.keyName(for: event)
        normalized = ShortcutDescriptor.normalize(modifiers: flags, key: key)
    }

    static func normalize(_ raw: String) -> String {
        ShortcutText.normalize(raw)
    }

    static func display(_ raw: String) -> String {
        ShortcutText.display(raw)
    }

    static func isValid(_ raw: String) -> Bool {
        ShortcutText.isValid(raw)
    }

    private static func normalize(modifiers: NSEvent.ModifierFlags, key: String) -> String {
        if key == "escape" {
            return "escape"
        }

        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("control") }
        if modifiers.contains(.option) { parts.append("option") }
        if modifiers.contains(.shift) { parts.append("shift") }
        if modifiers.contains(.command) { parts.append("command") }
        parts.append(key)
        return ShortcutText.normalize(parts.joined(separator: "+"))
    }

    private static func keyName(for event: NSEvent) -> String {
        switch event.keyCode {
        case 53:
            return "escape"
        default:
            return event.charactersIgnoringModifiers?.lowercased() ?? ""
        }
    }
}
