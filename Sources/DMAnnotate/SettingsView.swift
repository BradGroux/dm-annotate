import AppKit
import DMAnnotateCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AnnotationStore
    @ObservedObject var preferences: PreferencesController
    var shortcutController: ShortcutController
    @ObservedObject var runtimeState: AppRuntimeState

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "slider.horizontal.3")
                }
            toolsTab
                .tabItem {
                    Label("Tools", systemImage: "pencil.and.outline")
                }
            colorsTab
                .tabItem {
                    Label("Colors", systemImage: "paintpalette")
                }
            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
            privacyTab
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }
            diagnosticsTab
                .tabItem {
                    Label("Diagnostics", systemImage: "stethoscope")
                }
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 560)
    }

    private var generalTab: some View {
        Form {
            Picker("Theme", selection: binding(\.theme)) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.rawValue.capitalized).tag(theme)
                }
            }

            Picker("Toolbar orientation", selection: binding(\.toolbarOrientation)) {
                ForEach(ToolbarOrientation.allCases) { orientation in
                    Text(orientation.rawValue.capitalized).tag(orientation)
                }
            }

            Toggle("Collapse toolbar", isOn: binding(\.toolbarCollapsed))
            Toggle("High contrast toolbar", isOn: binding(\.highContrastToolbar))

            Picker("Screenshot output", selection: binding(\.screenshotOutput)) {
                ForEach(ScreenshotOutput.allCases) { output in
                    Text(output == .file ? "Save PNG file" : "Copy to clipboard").tag(output)
                }
            }
            Toggle("Ask before saving screenshot files", isOn: binding(\.confirmScreenshotFilename))
            Toggle("Reveal screenshots in Finder after saving", isOn: binding(\.revealScreenshotAfterSave))

            HStack {
                TextField("Screenshot folder", text: binding(\.screenshotFolder))
                Button("Choose...") {
                    chooseScreenshotFolder()
                }
            }

            Picker("Whiteboard background", selection: binding(\.whiteboardBackground)) {
                ForEach(WhiteboardBackground.allCases) { background in
                    Text(label(for: background)).tag(background)
                }
            }
        }
        .padding()
    }

    private var toolsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Visible Toolbar Tools")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), alignment: .leading)], alignment: .leading, spacing: 12) {
                ForEach(AnnotationTool.allCases) { tool in
                    Toggle(tool.displayName, isOn: toolVisibilityBinding(tool))
                }
            }

            Spacer()
        }
        .padding()
    }

    private var diagnosticsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Diagnostics")
                .font(.headline)

            diagnosticsRow("App version", appVersion)
            diagnosticsRow("macOS", ProcessInfo.processInfo.operatingSystemVersionString)
            diagnosticsRow("Launch mode", runtimeState.modeLabel ?? "Normal")
            diagnosticsRow("Screen Recording", PermissionChecks.screenRecordingStatus().label)
            diagnosticsRow("Accessibility", PermissionChecks.accessibilityStatus().label)
            diagnosticsRow("Input Monitoring", "Check Manually")
            diagnosticsRow("Display count", "\(NSScreen.screens.count)")
            diagnosticsRow("Screenshot folder", preferences.expandedScreenshotFolderURL().path)
            diagnosticsRow("Default screenshot output", preferences.snapshot.screenshotOutput == .file ? "File" : "Clipboard")
            diagnosticsRow("Visible tools", "\(preferences.snapshot.visibleTools.count)")

            HStack {
                Button("Open Permissions") {
                    SystemSettings.open(.screenRecording)
                }
                Button("Reveal Screenshot Folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([preferences.expandedScreenshotFolderURL()])
                }
                Button("Restart Shortcuts") {
                    shortcutController.stop()
                    shortcutController.start()
                }
                .disabled(runtimeState.isSafeMode)
                .help(runtimeState.isSafeMode ? "Shortcuts are disabled in Safe Mode." : "Restart local and global shortcut monitors.")
            }

            Spacer()
        }
        .padding()
    }

    private var colorsTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            ColorPicker(
                "Default color",
                selection: colorBinding(
                    get: { preferences.snapshot.defaultColor },
                    set: { next in
                        preferences.update { $0.defaultColor = next }
                        store.currentColor = next
                    }
                )
            )

            Text("Quick Colors")
                .font(.headline)

            ForEach(0..<4, id: \.self) { index in
                ColorPicker(
                    "Quick color \(index + 1)",
                    selection: colorBinding(
                        get: { preferences.snapshot.quickColors[index] },
                        set: { next in
                            preferences.update { snapshot in
                                snapshot.quickColors[index] = next
                            }
                        }
                    )
                )
            }

            Text("The toolbar palette includes 32 built-in colors. Quick colors are mapped to Command+1 through Command+4 by default.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    private var shortcutsTab: some View {
        let duplicates = preferences.duplicateShortcuts()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Click a shortcut field, press the new key combination, or clear the field to disable that action.")
                .foregroundStyle(.secondary)

            ForEach(ShortcutAction.allCases) { action in
                HStack {
                    Text(action.displayName)
                        .frame(width: 220, alignment: .leading)
                    ShortcutRecorderField(
                        shortcut: shortcutBinding(action),
                        isDuplicate: duplicates.contains(ShortcutDescriptor.normalize(preferences.snapshot.shortcuts[action] ?? ""))
                    )
                    .frame(height: 30)
                    if duplicates.contains(ShortcutDescriptor.normalize(preferences.snapshot.shortcuts[action] ?? "")) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .help("Duplicate shortcut")
                    }
                    Button {
                        preferences.update { snapshot in
                            snapshot.shortcuts[action] = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear shortcut")
                }
            }

            HStack {
                Button("Reset Shortcuts") {
                    preferences.update { $0.shortcuts = ShortcutAction.defaultShortcuts }
                }
                Spacer()
                Button("Test Current Shortcuts") {
                    shortcutController.stop()
                    shortcutController.start()
                }
            }

            Spacer()
        }
        .padding()
    }

    private var privacyTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Local-only by design")
                .font(.headline)

            Text("Digital Meld Annotate does not use accounts, analytics, telemetry, cloud sync, license activation, or normal-operation network calls.")
            Text("Screenshots may require macOS Screen Recording permission. Global shortcuts may require Accessibility or Input Monitoring permission.")
            Text("Annotations are in-memory only and are cleared when the app exits.")

            HStack {
                Button("Open Screen Recording Settings") {
                    SystemSettings.open(.screenRecording)
                }
                Button("Open Accessibility Settings") {
                    SystemSettings.open(.accessibility)
                }
                Button("Open Input Monitoring Settings") {
                    SystemSettings.open(.inputMonitoring)
                }
            }

            Spacer()
        }
        .padding()
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<PreferencesSnapshot, Value>) -> Binding<Value> {
        Binding(
            get: { preferences.snapshot[keyPath: keyPath] },
            set: { next in
                preferences.update { $0[keyPath: keyPath] = next }
            }
        )
    }

    private func toolVisibilityBinding(_ tool: AnnotationTool) -> Binding<Bool> {
        Binding(
            get: { preferences.snapshot.visibleTools.contains(tool) },
            set: { isVisible in
                preferences.update { snapshot in
                    if isVisible {
                        snapshot.visibleTools.insert(tool)
                    } else {
                        snapshot.visibleTools.remove(tool)
                    }
                }
            }
        )
    }

    private func colorBinding(get: @escaping () -> RGBAColor, set: @escaping (RGBAColor) -> Void) -> Binding<Color> {
        Binding(
            get: { Color(get()) },
            set: { set(RGBAColor($0)) }
        )
    }

    private func shortcutBinding(_ action: ShortcutAction) -> Binding<String> {
        Binding(
            get: { preferences.snapshot.shortcuts[action] ?? "" },
            set: { next in
                preferences.update { snapshot in
                    snapshot.shortcuts[action] = ShortcutDescriptor.normalize(next)
                }
            }
        )
    }

    private func chooseScreenshotFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            preferences.update { $0.screenshotFolder = url.path }
        }
    }

    private func label(for background: WhiteboardBackground) -> String {
        switch background {
        case .white: "White"
        case .black: "Black"
        case .lightGrid: "Light Grid"
        case .darkGrid: "Dark Grid"
        }
    }

    private func diagnosticsRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .frame(width: 180, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case (.some(let version), .some(let build)):
            return "\(version) (\(build))"
        case (.some(let version), .none):
            return version
        default:
            return "Development"
        }
    }
}
