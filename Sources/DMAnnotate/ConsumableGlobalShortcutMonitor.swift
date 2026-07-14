import AppKit
import CoreGraphics
import DMAnnotateCore

final class ConsumableGlobalShortcutMonitor: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var actionsByDescriptor: [String: ShortcutAction]
    private var passesEventsThrough = false
    private let actionHandler: @Sendable (ShortcutAction) -> Void
    private let lock = NSLock()

    init(actionsByDescriptor: [String: ShortcutAction], actionHandler: @escaping @Sendable (ShortcutAction) -> Void) {
        self.actionsByDescriptor = actionsByDescriptor
        self.actionHandler = actionHandler
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        stop()

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: consumableGlobalShortcutCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        runLoopSource = source
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    func update(actionsByDescriptor: [String: ShortcutAction]) {
        lock.lock()
        self.actionsByDescriptor = actionsByDescriptor
        lock.unlock()
    }

    func setPassesEventsThrough(_ passesEventsThrough: Bool) {
        lock.lock()
        self.passesEventsThrough = passesEventsThrough
        lock.unlock()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if shouldPassEventsThrough {
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown,
              let action = action(for: event) else {
            return Unmanaged.passUnretained(event)
        }

        actionHandler(action)
        return nil
    }

    private func action(for event: CGEvent) -> ShortcutAction? {
        let descriptor = Self.descriptor(for: event)
        guard !descriptor.isEmpty else { return nil }

        lock.lock()
        let action = actionsByDescriptor[descriptor]
        lock.unlock()
        return action
    }

    private var shouldPassEventsThrough: Bool {
        lock.lock()
        let shouldPass = passesEventsThrough
        lock.unlock()
        return shouldPass
    }

    private static func descriptor(for event: CGEvent) -> String {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        var modifiers: ShortcutModifiers = []
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        return PortableShortcutDescriptor.resolve(keyCode: keyCode, modifiers: modifiers) ?? ""
    }

}

private let consumableGlobalShortcutCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<ConsumableGlobalShortcutMonitor>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return monitor.handle(type: type, event: event)
}
