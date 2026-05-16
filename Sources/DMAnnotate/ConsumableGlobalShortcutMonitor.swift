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
        guard let key = keyName(for: keyCode) else { return "" }
        if key == "escape" {
            return "escape"
        }

        let flags = event.flags
        var parts: [String] = []
        if flags.contains(.maskControl) { parts.append("control") }
        if flags.contains(.maskAlternate) { parts.append("option") }
        if flags.contains(.maskShift) { parts.append("shift") }
        if flags.contains(.maskCommand) { parts.append("command") }
        parts.append(key)

        return ShortcutText.normalize(parts.joined(separator: "+"))
    }

    private static func keyName(for keyCode: Int64) -> String? {
        keyNamesByCode[keyCode]
    }

    private static let keyNamesByCode: [Int64: String] = [
        0: "a",
        1: "s",
        2: "d",
        3: "f",
        4: "h",
        5: "g",
        6: "z",
        7: "x",
        8: "c",
        9: "v",
        11: "b",
        12: "q",
        13: "w",
        14: "e",
        15: "r",
        16: "y",
        17: "t",
        18: "1",
        19: "2",
        20: "3",
        21: "4",
        22: "6",
        23: "5",
        24: "=",
        25: "9",
        26: "7",
        27: "-",
        28: "8",
        29: "0",
        30: "]",
        31: "o",
        32: "u",
        33: "[",
        34: "i",
        35: "p",
        36: "enter",
        37: "l",
        38: "j",
        39: "'",
        40: "k",
        41: ";",
        42: "\\",
        43: ",",
        44: "/",
        45: "n",
        46: "m",
        47: ".",
        49: "space",
        50: "`",
        51: "delete",
        53: "escape",
        76: "enter",
        117: "delete"
    ]
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
