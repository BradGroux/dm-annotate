import AppKit
import ApplicationServices
import DMAnnotateCore

private final class SettingsAXNotificationRecorder {
    var notifications: [String] = []
}

private let settingsAXObserverCallback: AXObserverCallback = { _, _, notification, context in
    guard let context else { return }
    let recorder = Unmanaged<SettingsAXNotificationRecorder>.fromOpaque(context).takeUnretainedValue()
    recorder.notifications.append(notification as String)
}

@MainActor
enum SettingsAccessibilitySmokeVerifier {
    static func verify(window: NSWindow, preferences: PreferencesController) -> [String] {
        var failures: [String] = []
        let originalShortcut = preferences.snapshot.shortcuts[.commandPalette] ?? ""
        defer {
            preferences.update { $0.shortcuts[.commandPalette] = originalShortcut }
            settle()
        }

        preferences.update { $0.shortcuts[.commandPalette] = "command+k" }
        window.autorecalculatesKeyViewLoop = true
        window.recalculateKeyViewLoop()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settle()

        guard let recorderView = descendantViews(of: window.contentView).compactMap({ $0 as? RecordingShortcutField }).first(where: {
            $0.actionIdentifier == ShortcutAction.commandPalette.rawValue
        }) else {
            failures.append("Settings accessibility smoke did not render the Command Palette shortcut recorder.")
            return failures
        }

        verifyKeyViewLoop(recorderView, in: window, failures: &failures)

        let applicationElement = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        guard let settingsWindowElement = settingsWindowElement(in: applicationElement) else {
            failures.append("Settings accessibility smoke could not find the Settings window in the live AX tree.")
            return failures
        }
        guard let recorderElement = element(
            withIdentifier: "settings.shortcut.\(ShortcutAction.commandPalette.rawValue)",
            under: settingsWindowElement
        ) else {
            failures.append("Settings accessibility smoke did not expose the Command Palette recorder by AX identifier.")
            return failures
        }
        guard let selectedSidebarElement = element(
            withIdentifier: "settings.section.shortcuts",
            under: settingsWindowElement
        ) else {
            failures.append("Settings accessibility smoke did not expose the selected Shortcuts sidebar item by AX identifier.")
            return failures
        }

        verifyRecorderElement(recorderElement, failures: &failures)
        verifySelectedSidebarElement(selectedSidebarElement, failures: &failures)
        verifyKeyboardAndNotifications(
            recorderView: recorderView,
            recorderElement: recorderElement,
            window: window,
            failures: &failures
        )

        return failures
    }

    private static func verifyKeyViewLoop(
        _ recorderView: RecordingShortcutField,
        in window: NSWindow,
        failures: inout [String]
    ) {
        guard window.makeFirstResponder(recorderView) else {
            failures.append("Settings accessibility smoke could not focus the shortcut recorder through the Settings window.")
            return
        }

        window.selectNextKeyView(nil)
        guard let nextResponder = window.firstResponder, nextResponder !== recorderView else {
            failures.append("Settings shortcut recorder is omitted from the automatic forward key-view loop.")
            return
        }

        window.selectPreviousKeyView(nil)
        if window.firstResponder !== recorderView {
            failures.append("Settings shortcut recorder is omitted from the automatic reverse key-view loop.")
        }
    }

    private static func verifyRecorderElement(_ element: AXUIElement, failures: inout [String]) {
        if stringAttribute(kAXRoleAttribute, of: element) != kAXButtonRole as String {
            failures.append("Settings shortcut recorder AX role is not AXButton.")
        }
        if accessibleName(of: element) != "Command Palette shortcut" {
            failures.append("Settings shortcut recorder AX accessible name does not own the Command Palette action.")
        }
        if stringAttribute(kAXValueAttribute, of: element) != "Command+K" {
            failures.append("Settings shortcut recorder AX value does not expose its assigned shortcut.")
        }
        let actions = actionNames(of: element)
        if !actions.contains(kAXPressAction as String) {
            failures.append("Settings shortcut recorder does not expose the AXPress action.")
        }
    }

    private static func verifySelectedSidebarElement(_ element: AXUIElement, failures: inout [String]) {
        if stringAttribute(kAXRoleAttribute, of: element) != kAXButtonRole as String {
            failures.append("Selected Settings sidebar item AX role is not AXButton.")
        }
        if stringAttribute(kAXValueAttribute, of: element) != "Selected" {
            failures.append("Selected Settings sidebar item does not expose its selected AX value.")
        }
        if boolAttribute(kAXSelectedAttribute, of: element) != true {
            failures.append("Selected Settings sidebar item does not expose AXSelected=true.")
        }
        if !actionNames(of: element).contains(kAXPressAction as String) {
            failures.append("Selected Settings sidebar item does not expose the AXPress action.")
        }
    }

    private static func verifyKeyboardAndNotifications(
        recorderView: RecordingShortcutField,
        recorderElement: AXUIElement,
        window: NSWindow,
        failures: inout [String]
    ) {
        let notificationRecorder = SettingsAXNotificationRecorder()
        var observer: AXObserver?
        let observerError = AXObserverCreate(
            ProcessInfo.processInfo.processIdentifier,
            settingsAXObserverCallback,
            &observer
        )
        guard observerError == .success, let observer else {
            failures.append("Settings accessibility smoke could not create an AX value-change observer (error \(observerError.rawValue)).")
            return
        }

        let runLoopSource = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        let context = Unmanaged.passUnretained(notificationRecorder).toOpaque()
        let notificationError = AXObserverAddNotification(
            observer,
            recorderElement,
            kAXValueChangedNotification as CFString,
            context
        )
        defer {
            AXObserverRemoveNotification(observer, recorderElement, kAXValueChangedNotification as CFString)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        }
        guard notificationError == .success else {
            failures.append("Settings accessibility smoke could not observe AXValueChanged (error \(notificationError.rawValue)).")
            return
        }

        guard window.makeFirstResponder(recorderView),
              sendKey(keyCode: 49, characters: " ", to: window) else {
            failures.append("Settings accessibility smoke could not dispatch Space to the shortcut recorder.")
            return
        }
        settle(duration: 0.25)
        if stringAttribute(kAXValueAttribute, of: recorderElement) != "Recording. Press a shortcut now." {
            failures.append("Space did not expose the recorder's live recording AX value.")
        }
        if !notificationRecorder.notifications.contains(kAXValueChangedNotification as String) {
            failures.append("Shortcut recording did not publish AXValueChanged.")
        }

        guard sendKey(keyCode: 51, characters: "\u{7f}", to: window) else {
            failures.append("Settings accessibility smoke could not dispatch Delete to the shortcut recorder.")
            return
        }
        settle()
        if stringAttribute(kAXValueAttribute, of: recorderElement) != "Not assigned" {
            failures.append("Delete did not expose the recorder's live unassigned AX value.")
        }

        recorderView.shortcut = "command+k"
        guard window.makeFirstResponder(recorderView),
              sendKey(keyCode: 36, characters: "\r", to: window) else {
            failures.append("Settings accessibility smoke could not dispatch Return to the shortcut recorder.")
            return
        }
        settle()
        if stringAttribute(kAXValueAttribute, of: recorderElement) != "Recording. Press a shortcut now." {
            failures.append("Return did not expose the recorder's live recording AX value.")
        }

        _ = sendKey(keyCode: 53, characters: "\u{1b}", to: window)
        settle()
    }

    private static func sendKey(keyCode: UInt16, characters: String, to window: NSWindow) -> Bool {
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        ) else {
            return false
        }
        window.sendEvent(event)
        return true
    }

    private static func settingsWindowElement(in application: AXUIElement) -> AXUIElement? {
        let windows: [AXUIElement] = attribute(kAXWindowsAttribute, of: application) ?? []
        return windows.first { stringAttribute(kAXTitleAttribute, of: $0) == "Digital Meld Annotate Settings" }
    }

    private static func element(withIdentifier identifier: String, under root: AXUIElement) -> AXUIElement? {
        var queue = [root]
        var visited = 0
        while !queue.isEmpty, visited < 2_000 {
            let next = queue.removeFirst()
            visited += 1
            if stringAttribute(kAXIdentifierAttribute, of: next) == identifier {
                return next
            }
            let children: [AXUIElement] = attribute(kAXChildrenAttribute, of: next) ?? []
            queue.append(contentsOf: children)
        }
        return nil
    }

    private static func actionNames(of element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return names as? [String] ?? []
    }

    private static func accessibleName(of element: AXUIElement) -> String? {
        stringAttribute(kAXTitleAttribute, of: element)
            ?? stringAttribute(kAXDescriptionAttribute, of: element)
    }

    private static func stringAttribute(_ name: String, of element: AXUIElement) -> String? {
        attribute(name, of: element)
    }

    private static func boolAttribute(_ name: String, of element: AXUIElement) -> Bool? {
        attribute(name, of: element)
    }

    private static func attribute<Value>(_ name: String, of element: AXUIElement) -> Value? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? Value
    }

    private static func descendantViews(of root: NSView?) -> [NSView] {
        guard let root else { return [] }
        return [root] + root.subviews.flatMap { descendantViews(of: $0) }
    }

    private static func settle(duration: TimeInterval = 0.08) {
        NSApp.updateWindows()
        let deadline = Date().addingTimeInterval(duration)
        repeat {
            RunLoop.current.run(mode: .default, before: deadline)
        } while Date() < deadline
    }
}
