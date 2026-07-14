import AppKit
import SwiftUI

@MainActor
final class CommandPaletteController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var model: CommandPaletteInteractionModel?
    private weak var previousKeyWindow: NSWindow?
    private var previousApplication: NSRunningApplication?

    func show(commands: [CommandPaletteCommand]) {
        if panel?.isVisible != true {
            captureFocusOrigin()
        }

        if let model {
            model.replaceCommands(commands)
        } else {
            let model = CommandPaletteInteractionModel(commands: commands)
            self.model = model
            makePanel(model: model)
        }

        model?.requestSearchFocus()
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func toggle(commands: [CommandPaletteCommand]) {
        if panel?.isVisible == true {
            dismiss()
        } else {
            show(commands: commands)
        }
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func windowWillClose(_ notification: Notification) {
        restoreFocusOrigin()
    }

    private func makePanel(model: CommandPaletteInteractionModel) {
        let view = CommandPaletteView(model: model) { [weak self] in
            self?.dismiss()
        }
        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        panel.title = "Digital Meld Annotate Commands"
        panel.contentView = NSHostingView(rootView: view)
        panel.animationBehavior = .none
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        self.panel = panel
    }

    private func dismiss() {
        panel?.orderOut(nil)
        restoreFocusOrigin()
    }

    private func captureFocusOrigin() {
        previousKeyWindow = NSApp.keyWindow === panel ? nil : NSApp.keyWindow
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        previousApplication = frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
            ? nil
            : frontmostApplication
    }

    private func restoreFocusOrigin() {
        switch CommandPaletteAppKitSeams.restorationDestination(
            previousWindowVisible: previousKeyWindow?.isVisible == true,
            previousApplicationAvailable: previousApplication != nil
        ) {
        case .window:
            previousKeyWindow?.makeKeyAndOrderFront(nil)
        case .application:
            previousApplication?.activate(options: [.activateIgnoringOtherApps])
        case .none:
            break
        }
        previousKeyWindow = nil
        previousApplication = nil
    }
}
