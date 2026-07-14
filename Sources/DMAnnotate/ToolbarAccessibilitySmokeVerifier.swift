import AppKit
import ApplicationServices
import Foundation

@MainActor
enum ToolbarAccessibilitySmokeVerifier {
    struct ControlExpectation {
        let identifier: String
        let label: String
        let role: String
        let helpContains: String
        let valueContains: String?
        let isSelected: Bool?
        let isEnabled: Bool?
        let requiredAction: String?

        init(
            _ identifier: String,
            label: String,
            role: String = kAXButtonRole as String,
            helpContains: String,
            valueContains: String? = nil,
            isSelected: Bool? = nil,
            isEnabled: Bool? = nil,
            requiredAction: String? = kAXPressAction as String
        ) {
            self.identifier = identifier
            self.label = label
            self.role = role
            self.helpContains = helpContains
            self.valueContains = valueContains
            self.isSelected = isSelected
            self.isEnabled = isEnabled
            self.requiredAction = requiredAction
        }
    }

    static func verify(
        panel: NSPanel,
        rootRole: String,
        summaryContains: String,
        controls: [ControlExpectation]
    ) -> [String] {
        guard let context = liveContext(panel: panel) else {
            return ["Toolbar accessibility smoke could not isolate one current visible toolbar window and root."]
        }
        var failures: [String] = []
        verifyTextAttribute(kAXRoleAttribute, expected: rootRole, element: context.root, name: "toolbar.root role", failures: &failures)
        verifyTextAttribute(kAXTitleAttribute, expected: "Digital Meld Annotate toolbar", element: context.root, name: "toolbar.root label", failures: &failures, useAccessibleName: true)

        let rootSummary = stringAttribute(kAXValueAttribute, of: context.root) ?? ""
        let collapsedSummary = uniqueElement(withIdentifier: "toolbar.expand", under: context.root)
            .flatMap { stringAttribute(kAXValueAttribute, of: $0) } ?? ""
        let compactSummary = uniqueElement(withIdentifier: "toolbar.compact-mode", under: context.root)
            .flatMap { stringAttribute(kAXValueAttribute, of: $0) } ?? ""
        let summary = [rootSummary, compactSummary, collapsedSummary]
            .first(where: { $0.contains(summaryContains) }) ?? ""
        if summary.isEmpty {
            failures.append("Current toolbar AX summary does not contain '\(summaryContains)'.")
        }

        for expectation in controls {
            let matches = elements(withIdentifier: expectation.identifier, under: context.root).filter { element in
                guard stringAttribute(kAXRoleAttribute, of: element) == expectation.role else { return false }
                return expectation.requiredAction.map { actionNames(of: element).contains($0) } ?? true
            }
            guard matches.count == 1, let control = matches.first else {
                failures.append("Current toolbar root expected one \(expectation.identifier); found \(matches.count).")
                continue
            }
            verifyTextAttribute(kAXRoleAttribute, expected: expectation.role, element: control, name: "\(expectation.identifier) role", failures: &failures)
            verifyTextAttribute(kAXTitleAttribute, expected: expectation.label, element: control, name: "\(expectation.identifier) label", failures: &failures, useAccessibleName: true)
            let help = stringAttribute(kAXHelpAttribute, of: control) ?? ""
            if !help.contains(expectation.helpContains) {
                failures.append("\(expectation.identifier) AXHelp expected '\(expectation.helpContains)'; got '\(help)'.")
            }
            if let expected = expectation.valueContains {
                let actual = stringAttribute(kAXValueAttribute, of: control) ?? ""
                if !actual.contains(expected) {
                    failures.append("\(expectation.identifier) AXValue expected '\(expected)'; got '\(actual)'.")
                }
            }
            if let expected = expectation.isSelected,
               (boolAttribute(kAXSelectedAttribute, of: control) ?? false) != expected {
                failures.append("\(expectation.identifier) AXSelected was not \(expected).")
            }
            if let expected = expectation.isEnabled,
               boolAttribute(kAXEnabledAttribute, of: control) != expected {
                failures.append("\(expectation.identifier) AXEnabled was not \(expected).")
            }
            if let requiredAction = expectation.requiredAction,
               !actionNames(of: control).contains(requiredAction) {
                failures.append("\(expectation.identifier) does not expose \(requiredAction).")
            }
        }
        return failures
    }

    static func performPress(
        panel: NSPanel,
        identifier: String
    ) -> [String] {
        guard let context = liveContext(panel: panel) else {
            return ["Toolbar accessibility smoke lost its current visible toolbar root before AXPress."]
        }
        let matches = elements(withIdentifier: identifier, under: context.root).filter {
            stringAttribute(kAXRoleAttribute, of: $0) == kAXButtonRole as String &&
                actionNames(of: $0).contains(kAXPressAction as String)
        }
        guard matches.count == 1, let control = matches.first else {
            return ["Current toolbar root does not expose exactly one AXPress-capable \(identifier)."]
        }
        let result = AXUIElementPerformAction(control, kAXPressAction as CFString)
        guard result == .success else {
            return ["Toolbar AX control \(identifier) rejected AXPress (error \(result.rawValue))."]
        }
        settle()
        return []
    }

    private struct LiveContext {
        let window: AXUIElement
        let root: AXUIElement
    }

    private static func liveContext(panel: NSPanel) -> LiveContext? {
        guard panel.isVisible else { return nil }
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        let windows: [AXUIElement] = attribute(kAXWindowsAttribute, of: application) ?? []
        let matchingWindows = windows.filter {
            stringAttribute(kAXIdentifierAttribute, of: $0) == "toolbar.window" &&
                boolAttribute(kAXMinimizedAttribute, of: $0) != true
        }
        guard matchingWindows.count == 1, let window = matchingWindows.first else { return nil }
        let roots = elements(withIdentifier: "toolbar.root", under: window)
        guard roots.count == 1, let root = roots.first else { return nil }
        return LiveContext(window: window, root: root)
    }

    private static func uniqueElement(withIdentifier identifier: String, under root: AXUIElement) -> AXUIElement? {
        let matches = elements(withIdentifier: identifier, under: root)
        return matches.count == 1 ? matches[0] : nil
    }

    private static func descendants(of root: AXUIElement) -> [AXUIElement] {
        var queue = [root]
        var visited = 0
        var seen: [AXUIElement] = []
        var output: [AXUIElement] = []
        while !queue.isEmpty, visited < 2_000 {
            let next = queue.removeFirst()
            visited += 1
            if seen.contains(where: { CFEqual($0, next) }) { continue }
            seen.append(next)
            output.append(next)
            let children: [AXUIElement] = attribute(kAXChildrenAttribute, of: next) ?? []
            queue.append(contentsOf: children)
        }
        return output
    }

    private static func elements(withIdentifier identifier: String, under root: AXUIElement) -> [AXUIElement] {
        descendants(of: root).filter { stringAttribute(kAXIdentifierAttribute, of: $0) == identifier }
    }

    private static func verifyTextAttribute(
        _ attributeName: String,
        expected: String,
        element: AXUIElement,
        name: String,
        failures: inout [String],
        useAccessibleName: Bool = false
    ) {
        let actual = useAccessibleName ? accessibleName(of: element) : stringAttribute(attributeName, of: element)
        if actual != expected { failures.append("\(name) expected '\(expected)'; got '\(actual ?? "missing")'.") }
    }

    private static func accessibleName(of element: AXUIElement) -> String? {
        stringAttribute(kAXTitleAttribute, of: element) ?? stringAttribute(kAXDescriptionAttribute, of: element)
    }

    private static func actionNames(of element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return names as? [String] ?? []
    }

    private static func stringAttribute(_ name: String, of element: AXUIElement) -> String? { attribute(name, of: element) }
    private static func boolAttribute(_ name: String, of element: AXUIElement) -> Bool? { attribute(name, of: element) }

    private static func attribute<Value>(_ name: String, of element: AXUIElement) -> Value? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? Value
    }

    private static func settle() {
        NSApp.updateWindows()
        let deadline = Date().addingTimeInterval(0.25)
        repeat { RunLoop.current.run(mode: .default, before: deadline) } while Date() < deadline
    }
}
