import AppKit
import DMAnnotateCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, AppMenuActionHandling {
    private let store = AnnotationStore()
    private let runtimeState = AppRuntimeState()
    private let launchRecovery = LaunchRecoveryController()
    private var preferences: PreferencesController!
    private var overlayController: OverlayController!
    private var screenshotController: ScreenshotController!
    private var shortcutController: ShortcutController!
    private var toolbarWindowController: ToolbarWindowController!
    private var settingsWindowController: SettingsWindowController!
    private var onboardingController: PermissionOnboardingController!
    private var commandPaletteController: CommandPaletteController!
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchState = launchRecovery.beginLaunch()
        runtimeState.configure(isSafeMode: launchState.isSafeMode, recoveredFromAbnormalExit: launchState.recoveredFromAbnormalExit)
        configureControllers()
        preferences.applyToStore()
        recoverLaunchStateIfNeeded(launchState)
        AppMenuBuilder(target: self).installMainMenu()
        configureStatusItem()
        if !launchState.isSafeMode {
            overlayController.start()
        }
        toolbarWindowController.show()
        if launchState.isSafeMode || launchState.recoveredFromAbnormalExit {
            toolbarWindowController.centerOnMainScreen()
        }
        if !launchState.isSafeMode {
            shortcutController.start()
            onboardingController.showIfNeeded()
        } else {
            showSafeModeNotice()
        }
    }

    private func configureControllers() {
        preferences = PreferencesController(store: store)
        overlayController = OverlayController(store: store)
        screenshotController = ScreenshotController(
            store: store,
            preferences: preferences,
            overlayController: overlayController
        )
        shortcutController = ShortcutController(
            preferences: preferences,
            store: store,
            actions: AppActions(
                toggleToolbarCollapsed: { [weak self] in self?.toolbarWindowController.toggleCollapsed() },
                toggleToolbarOrientation: { [weak self] in self?.toolbarWindowController.toggleOrientation() },
                findToolbar: { [weak self] in self?.toolbarWindowController.findToolbar() },
                screenshot: { [weak self] in self?.screenshotController.captureFullDisplay() },
                copyScreenshot: { [weak self] in self?.screenshotController.captureFullDisplay(destination: .clipboard) },
                saveScreenshot: { [weak self] in self?.screenshotController.captureFullDisplay(destination: .file) },
                regionScreenshot: { [weak self] in self?.screenshotController.captureRegion() },
                revealLastScreenshot: { [weak self] in self?.screenshotController.revealLastScreenshot() },
                showPermissions: { [weak self] in self?.onboardingController.show() },
                showSettings: { [weak self] in self?.settingsWindowController.show() },
                showCommandPalette: { [weak self] in self?.showCommandPalette() },
                quit: { NSApp.terminate(nil) }
            )
        )
        settingsWindowController = SettingsWindowController(
            store: store,
            preferences: preferences,
            shortcutController: shortcutController,
            runtimeState: runtimeState
        )
        onboardingController = PermissionOnboardingController()
        commandPaletteController = CommandPaletteController()
        toolbarWindowController = ToolbarWindowController(
            store: store,
            preferences: preferences,
            runtimeState: runtimeState,
            actions: ToolbarActions(
                screenshot: { [weak self] in self?.screenshotController.captureFullDisplay() },
                regionScreenshot: { [weak self] in self?.screenshotController.captureRegion() },
                copyScreenshot: { [weak self] in self?.screenshotController.captureFullDisplay(destination: .clipboard) },
                saveScreenshot: { [weak self] in self?.screenshotController.captureFullDisplay(destination: .file) },
                revealLastScreenshot: { [weak self] in self?.screenshotController.revealLastScreenshot() },
                showSettings: { [weak self] in self?.settingsWindowController.show() },
                showPermissions: { [weak self] in self?.onboardingController.show() },
                openCommandPalette: { [weak self] in self?.showCommandPalette() },
                toggleAnnotationLock: { [weak self] in self?.store.toggleAnnotationLock() },
                findToolbar: { [weak self] in self?.toolbarWindowController.findToolbar() }
            )
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutController.stop()
        launchRecovery.markCleanExit()
    }

    private func recoverLaunchStateIfNeeded(_ launchState: LaunchState) {
        guard launchState.isSafeMode || launchState.recoveredFromAbnormalExit else { return }
        store.exitScreenControls()
        preferences.update { snapshot in
            snapshot.toolbarCollapsed = false
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "pencil.and.outline", accessibilityDescription: "Digital Meld Annotate")
        item.button?.toolTip = "Digital Meld Annotate"
        item.menu = AppMenuBuilder(target: self).statusMenu()
        statusItem = item
    }

    @objc func showToolbar() {
        NSApp.activate(ignoringOtherApps: true)
        toolbarWindowController.show()
    }

    @objc func findToolbar() {
        toolbarWindowController.findToolbar()
    }

    @objc func toggleToolbarCollapsed() {
        toolbarWindowController.toggleCollapsed()
    }

    @objc func toggleToolbarOrientation() {
        toolbarWindowController.toggleOrientation()
    }

    @objc func toggleAnnotationMode() {
        guard !runtimeState.isSafeMode else { return }
        store.setActiveTool(store.activeTool == .cursor ? .pen : .cursor)
    }

    @objc func cursorMode() {
        store.exitScreenControls()
    }

    @objc func toggleAnnotationVisibility() {
        store.toggleVisibility()
    }

    @objc func toggleAnnotationLock() {
        store.toggleAnnotationLock()
    }

    @objc func clearAll() {
        store.clearAll()
    }

    @objc func captureScreenshot() {
        screenshotController.captureFullDisplay()
    }

    @objc func copyScreenshot() {
        screenshotController.captureFullDisplay(destination: .clipboard)
    }

    @objc func saveScreenshot() {
        screenshotController.captureFullDisplay(destination: .file)
    }

    @objc func captureRegionScreenshot() {
        screenshotController.captureRegion()
    }

    @objc func revealLastScreenshot() {
        screenshotController.revealLastScreenshot()
    }

    @objc func showSettings() {
        settingsWindowController.show()
    }

    @objc func showPermissions() {
        onboardingController.show()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    @objc func openCommandPalette() {
        showCommandPalette()
    }

    @objc func selectTool(_ sender: NSMenuItem) {
        guard !runtimeState.isSafeMode,
              let rawValue = sender.representedObject as? String,
              let tool = AnnotationTool(rawValue: rawValue) else { return }

        store.setActiveTool(tool)
    }

    @objc func undo() {
        store.undo()
    }

    @objc func redo() {
        store.redo()
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Digital Meld Annotate",
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development",
            .credits: NSAttributedString(string: "Copyright 2026 Digital Meld. MIT licensed.")
        ])
    }

    @objc func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Digital Meld Annotate"
        alert.informativeText = "Use the floating toolbar, menu bar, or Command+K to switch tools, capture screenshots, and manage permissions."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showCommandPalette() {
        commandPaletteController.show(commands: commandPaletteCommands())
    }

    private func commandPaletteCommands() -> [CommandPaletteCommand] {
        var commands: [CommandPaletteCommand] = [
            CommandPaletteCommand(title: "Cursor Mode", subtitle: "Pass clicks through to apps", systemImage: "cursorarrow") { [weak self] in
                self?.store.exitScreenControls()
            },
            CommandPaletteCommand(title: store.annotationsLocked ? "Unlock Annotations" : "Lock Annotations", subtitle: "Prevent accidental annotation edits", systemImage: store.annotationsLocked ? "lock.open" : "lock") { [weak self] in
                self?.store.toggleAnnotationLock()
            },
            CommandPaletteCommand(title: "Toggle Annotation Visibility", subtitle: "Show or hide all annotations", systemImage: store.isVisible ? "eye.slash" : "eye") { [weak self] in
                self?.store.toggleVisibility()
            },
            CommandPaletteCommand(title: "Undo", subtitle: "Undo the last annotation action", systemImage: "arrow.uturn.backward") { [weak self] in
                self?.store.undo()
            },
            CommandPaletteCommand(title: "Redo", subtitle: "Redo the last annotation action", systemImage: "arrow.uturn.forward") { [weak self] in
                self?.store.redo()
            },
            CommandPaletteCommand(title: "Clear All", subtitle: "Remove all annotations", systemImage: "trash") { [weak self] in
                self?.store.clearAll()
            },
            CommandPaletteCommand(title: "Copy Screenshot as PNG", subtitle: "Copy annotated screenshot to clipboard", systemImage: "doc.on.clipboard") { [weak self] in
                self?.screenshotController.captureFullDisplay(destination: .clipboard)
            },
            CommandPaletteCommand(title: "Save Screenshot as PNG", subtitle: "Save annotated screenshot to disk", systemImage: "square.and.arrow.down") { [weak self] in
                self?.screenshotController.captureFullDisplay(destination: .file)
            },
            CommandPaletteCommand(title: "Region Screenshot", subtitle: "Drag a capture region", systemImage: "crop") { [weak self] in
                self?.screenshotController.captureRegion()
            },
            CommandPaletteCommand(title: "Reveal Last Screenshot", subtitle: "Open the last saved screenshot in Finder", systemImage: "folder") { [weak self] in
                self?.screenshotController.revealLastScreenshot()
            },
            CommandPaletteCommand(title: "Flip Toolbar Orientation", subtitle: "Switch horizontal or vertical toolbar", systemImage: "arrow.up.arrow.down") { [weak self] in
                self?.toolbarWindowController.toggleOrientation()
            },
            CommandPaletteCommand(title: "Find Toolbar", subtitle: "Pulse the floating toolbar", systemImage: "scope") { [weak self] in
                self?.toolbarWindowController.findToolbar()
            },
            CommandPaletteCommand(title: "Settings", subtitle: "Open app settings", systemImage: "gearshape") { [weak self] in
                self?.settingsWindowController.show()
            },
            CommandPaletteCommand(title: "Permissions", subtitle: "Open permission onboarding", systemImage: "lock.shield") { [weak self] in
                self?.onboardingController.show()
            },
            CommandPaletteCommand(title: "Quit", subtitle: "Quit Digital Meld Annotate", systemImage: "power") {
                NSApp.terminate(nil)
            }
        ]

        if !runtimeState.isSafeMode {
            commands.insert(contentsOf: AnnotationTool.allCases.filter { $0 != .cursor }.map { tool in
                CommandPaletteCommand(title: tool.displayName, subtitle: "Switch active annotation tool", systemImage: tool.systemImageName) { [weak self] in
                    self?.store.setActiveTool(tool)
                }
            }, at: 1)
        }

        return commands
    }

    private func showSafeModeNotice() {
        let alert = NSAlert()
        alert.messageText = "Digital Meld Annotate Safe Mode"
        alert.informativeText = "Overlays and global shortcuts are disabled because Shift was held during launch. Adjust settings, then quit and reopen normally."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct AppActions {
    var toggleToolbarCollapsed: () -> Void
    var toggleToolbarOrientation: () -> Void
    var findToolbar: () -> Void
    var screenshot: () -> Void
    var copyScreenshot: () -> Void
    var saveScreenshot: () -> Void
    var regionScreenshot: () -> Void
    var revealLastScreenshot: () -> Void
    var showPermissions: () -> Void
    var showSettings: () -> Void
    var showCommandPalette: () -> Void
    var quit: () -> Void
}
