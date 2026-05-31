import AppKit
import Combine
import Darwin
import DMAnnotateCore
import UniformTypeIdentifiers

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
    private var cancellables: Set<AnyCancellable> = []
    private let launchArguments: Set<String>

    init(arguments: [String] = CommandLine.arguments) {
        launchArguments = Set(arguments)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchState = isUISmokeMode
            ? LaunchState(isSafeMode: true, recoveredFromAbnormalExit: false)
            : launchRecovery.beginLaunch()
        runtimeState.configure(isSafeMode: launchState.isSafeMode, recoveredFromAbnormalExit: launchState.recoveredFromAbnormalExit)
        configureControllers()
        preferences.applyToStore()
        recoverLaunchStateIfNeeded(launchState)
        installAppMenus()
        configureStatusItem()
        observeShortcutPreferences()
        if !launchState.isSafeMode {
            overlayController.start()
        }
        toolbarWindowController.show()
        if isUISmokeMode {
            runUISmoke()
            return
        }
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

    private var isUISmokeMode: Bool {
        launchArguments.contains("--smoke-ui")
    }

    private func configureControllers() {
        let defaults = isUISmokeMode
            ? UserDefaults(suiteName: "io.digitalmeld.dm-annotate.smoke") ?? .standard
            : .standard

        preferences = PreferencesController(store: store, defaults: defaults)
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
                toggleToolbarCompactMode: { [weak self] in self?.toolbarWindowController.toggleCompactMode() },
                findToolbar: { [weak self] in self?.toolbarWindowController.findToolbar() },
                screenshot: { [weak self] in self?.screenshotController.captureFullDisplay() },
                copyScreenshot: { [weak self] in self?.screenshotController.captureFullDisplay(destination: .clipboard) },
                saveScreenshot: { [weak self] in self?.screenshotController.captureFullDisplay(destination: .file) },
                regionScreenshot: { [weak self] in self?.screenshotController.captureRegion() },
                revealLastScreenshot: { [weak self] in self?.screenshotController.revealLastScreenshot() },
                showPermissions: { [weak self] in self?.onboardingController.show() },
                showSettings: { [weak self] in self?.settingsWindowController.toggle() },
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
        onboardingController = PermissionOnboardingController(defaults: defaults)
        commandPaletteController = CommandPaletteController()
        toolbarWindowController = ToolbarWindowController(
            store: store,
            preferences: preferences,
            runtimeState: runtimeState,
            actions: ToolbarActions(
                toggleToolbarCollapsed: { [weak self] in self?.toolbarWindowController.toggleCollapsed() },
                toggleToolbarOrientation: { [weak self] in self?.toolbarWindowController.toggleOrientation() },
                toggleToolbarCompactMode: { [weak self] in self?.toolbarWindowController.toggleCompactMode() },
                expandToolbar: { [weak self] in self?.toolbarWindowController.expandToolbar() },
                screenshot: { [weak self] in self?.screenshotController.captureFullDisplay() },
                regionScreenshot: { [weak self] in self?.screenshotController.captureRegion() },
                copyScreenshot: { [weak self] in self?.screenshotController.captureFullDisplay(destination: .clipboard) },
                saveScreenshot: { [weak self] in self?.screenshotController.captureFullDisplay(destination: .file) },
                saveAnnotationsScreenshot: { [weak self] in self?.screenshotController.captureFullDisplay(destination: .file, renderMode: .annotationsOnly) },
                revealLastScreenshot: { [weak self] in self?.screenshotController.revealLastScreenshot() },
                showSettings: { [weak self] in self?.settingsWindowController.toggle() },
                showPermissions: { [weak self] in self?.onboardingController.show() },
                toggleAnnotationLock: { [weak self] in self?.store.toggleAnnotationLock() },
                findToolbar: { [weak self] in self?.toolbarWindowController.findToolbar() },
                resizeToolbar: { [weak self] in self?.toolbarWindowController.resizeToFit() }
            )
        )
        screenshotController.setCaptureChromeHider { [weak self] capture in
            guard let self else { return capture() }
            return self.toolbarWindowController.temporarilyHideForCapture(capture)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutController.stop()
        if !isUISmokeMode {
            launchRecovery.markCleanExit()
        }
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
        item.menu = AppMenuBuilder(target: self, shortcuts: preferences.snapshot.shortcuts).statusMenu()
        statusItem = item
    }

    private func installAppMenus() {
        AppMenuBuilder(target: self, shortcuts: preferences.snapshot.shortcuts).installMainMenu()
    }

    private func observeShortcutPreferences() {
        preferences.$snapshot
            .map(\.shortcuts)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.installAppMenus()
                self.statusItem?.menu = AppMenuBuilder(target: self, shortcuts: self.preferences.snapshot.shortcuts).statusMenu()
            }
            .store(in: &cancellables)
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

    @objc func toggleToolbarCompactMode() {
        toolbarWindowController.toggleCompactMode()
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

    @objc func saveAnnotationSession() {
        let panel = NSSavePanel()
        panel.title = "Save Annotation Session"
        panel.nameFieldStringValue = "Digital Meld Annotate Session.dmannotate-session"
        panel.allowedContentTypes = annotationSessionContentTypes
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try store.sessionDocument().encodedData()
            try data.write(to: url, options: .atomic)
        } catch {
            showError("Annotation session save failed: \(error.localizedDescription)")
        }
    }

    @objc func loadAnnotationSession() {
        let panel = NSOpenPanel()
        panel.title = "Load Annotation Session"
        panel.allowedContentTypes = annotationSessionContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            if let byteCount = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber {
                try AnnotationSessionDocument.validateEncodedByteCount(byteCount.uint64Value)
            }
            let data = try Data(contentsOf: url)
            let session = try AnnotationSessionDocument.decode(from: data)
                .retargetingMissingDisplays(
                    availableDisplayIDs: Set(NSScreen.screens.map(\.displayID)),
                    fallbackDisplayID: NSScreen.main?.displayID ?? NSScreen.screens.first?.displayID ?? 0
                )
            store.loadSession(session)
        } catch {
            showError("Annotation session load failed: \(error.localizedDescription)")
        }
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

    @objc func saveAnnotationsScreenshot() {
        screenshotController.captureFullDisplay(destination: .file, renderMode: .annotationsOnly)
    }

    @objc func captureRegionScreenshot() {
        screenshotController.captureRegion()
    }

    @objc func revealLastScreenshot() {
        screenshotController.revealLastScreenshot()
    }

    @objc func showSettings() {
        settingsWindowController.toggle()
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
        settingsWindowController.show(section: .help)
    }

    private func showCommandPalette() {
        commandPaletteController.toggle(commands: commandPaletteCommands())
    }

    private func runUISmoke() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.performUISmoke()
        }
    }

    private func performUISmoke() {
        var failures: [String] = []

        toolbarWindowController.show()
        settingsWindowController.show()
        onboardingController.show()
        commandPaletteController.show(commands: commandPaletteCommands())

        NSApp.updateWindows()
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.10))

        if !toolbarWindowController.isVisible {
            failures.append("Toolbar panel is not visible.")
        }
        if !settingsWindowController.isVisible {
            failures.append("Settings window is not visible.")
        }
        if !onboardingController.isVisible {
            failures.append("Permissions window is not visible.")
        }
        if !commandPaletteController.isVisible {
            failures.append("Command palette window is not visible.")
        }

        if failures.isEmpty {
            print("dm-annotate UI smoke OK")
            print("- toolbar visible")
            print("- settings visible")
            print("- permissions visible")
            print("- command palette visible")
            NSApp.terminate(nil)
            return
        }

        fputs("dm-annotate UI smoke failed:\n", stderr)
        for failure in failures {
            fputs("- \(failure)\n", stderr)
        }
        exit(EXIT_FAILURE)
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
            CommandPaletteCommand(title: "Save Annotation Session", subtitle: "Save annotations to a local file", systemImage: "square.and.arrow.down.on.square") { [weak self] in
                self?.saveAnnotationSession()
            },
            CommandPaletteCommand(title: "Load Annotation Session", subtitle: "Load annotations from a local file", systemImage: "square.and.arrow.up.on.square") { [weak self] in
                self?.loadAnnotationSession()
            },
            CommandPaletteCommand(title: "Copy Screenshot as PNG", subtitle: "Copy annotated screenshot to clipboard", systemImage: "doc.on.clipboard") { [weak self] in
                self?.screenshotController.captureFullDisplay(destination: .clipboard)
            },
            CommandPaletteCommand(title: "Save Screenshot as PNG", subtitle: "Save annotated screenshot to disk", systemImage: "square.and.arrow.down") { [weak self] in
                self?.screenshotController.captureFullDisplay(destination: .file)
            },
            CommandPaletteCommand(title: "Save Annotations as PNG", subtitle: "Export annotations over transparency", systemImage: "square.on.square.dashed") { [weak self] in
                self?.screenshotController.captureFullDisplay(destination: .file, renderMode: .annotationsOnly)
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
            CommandPaletteCommand(title: "Compact Presenter Mode", subtitle: "Switch compact toolbar layout", systemImage: "rectangle.compress.vertical") { [weak self] in
                self?.toolbarWindowController.toggleCompactMode()
            },
            CommandPaletteCommand(title: "Find Toolbar", subtitle: "Pulse the floating toolbar", systemImage: "scope") { [weak self] in
                self?.toolbarWindowController.findToolbar()
            },
            CommandPaletteCommand(title: "Settings", subtitle: "Open app settings", systemImage: "gearshape") { [weak self] in
                self?.settingsWindowController.toggle()
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
    var toggleToolbarCompactMode: () -> Void
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

private extension AppDelegate {
    var annotationSessionContentTypes: [UTType] {
        [UTType(filenameExtension: "dmannotate-session") ?? .json, .json]
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Digital Meld Annotate"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
