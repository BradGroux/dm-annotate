import AppKit
import DMAnnotateCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AnnotationStore
    @ObservedObject var preferences: PreferencesController
    var shortcutController: ShortcutController
    @ObservedObject var runtimeState: AppRuntimeState

    @State private var selectedSection: SettingsSection = .general

    init(
        store: AnnotationStore,
        preferences: PreferencesController,
        shortcutController: ShortcutController,
        runtimeState: AppRuntimeState,
        initialSection: SettingsSection = .general
    ) {
        self.store = store
        self.preferences = preferences
        self.shortcutController = shortcutController
        self.runtimeState = runtimeState
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            contentPane
        }
        .frame(minWidth: 900, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

            ForEach(SettingsSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedSection == section ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selectedSection == section ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(12)
        .frame(width: 190)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    private var contentPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedSection.title)
                        .font(.system(size: 28, weight: .semibold))
                    Text(selectedSection.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                selectedContent
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 30)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var selectedContent: some View {
        switch selectedSection {
        case .general:
            generalSection
        case .tools:
            toolsSection
        case .colors:
            colorsSection
        case .shortcuts:
            shortcutsSection
        case .help:
            helpSection
        case .privacy:
            privacySection
        case .diagnostics:
            diagnosticsSection
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("Appearance") {
                settingsRow("Theme") {
                    Picker("", selection: binding(\.theme)) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue.capitalized).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
            }

            settingsGroup("Toolbar") {
                settingsRow("Orientation") {
                    Picker("", selection: binding(\.toolbarOrientation)) {
                        ForEach(ToolbarOrientation.allCases) { orientation in
                            Text(orientation.rawValue.capitalized).tag(orientation)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }

                settingsRow("Behavior") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Collapse toolbar", isOn: binding(\.toolbarCollapsed))
                        Toggle("High contrast toolbar", isOn: binding(\.highContrastToolbar))
                        Toggle("Show toolbar tooltips", isOn: binding(\.toolbarTooltipsEnabled))
                    }
                }
            }

            settingsGroup("Screenshots") {
                settingsRow("Output") {
                    Picker("", selection: binding(\.screenshotOutput)) {
                        ForEach(ScreenshotOutput.allCases) { output in
                            Text(output == .file ? "Save PNG file" : "Copy to clipboard").tag(output)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                }

                settingsRow("Options") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Ask before saving screenshot files", isOn: binding(\.confirmScreenshotFilename))
                        Toggle("Reveal screenshots in Finder after saving", isOn: binding(\.revealScreenshotAfterSave))
                    }
                }

                settingsRow("Folder") {
                    HStack(spacing: 10) {
                        TextField("Screenshot folder", text: binding(\.screenshotFolder))
                        Button("Choose...") {
                            chooseScreenshotFolder()
                        }
                    }
                }
            }

            settingsGroup("Whiteboard") {
                settingsRow("Background") {
                    Picker("", selection: binding(\.whiteboardBackground)) {
                        ForEach(WhiteboardBackground.allCases) { background in
                            Text(label(for: background)).tag(background)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
            }
        }
    }

    private var toolsSection: some View {
        settingsGroup("Visible Toolbar Tools") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), alignment: .leading)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(AnnotationTool.allCases) { tool in
                    Toggle(tool.displayName, isOn: toolVisibilityBinding(tool))
                }
            }
        }
    }

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("Default") {
                settingsRow("Default color") {
                    ColorPicker(
                        "",
                        selection: colorBinding(
                            get: { preferences.snapshot.defaultColor },
                            set: { next in
                                preferences.update { $0.defaultColor = next }
                                store.currentColor = next
                            }
                        )
                    )
                    .labelsHidden()
                }
            }

            settingsGroup("Toolbar Palette") {
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(220), alignment: .leading),
                        GridItem(.fixed(220), alignment: .leading)
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(Array(preferences.snapshot.paletteColors.enumerated()), id: \.offset) { index, _ in
                        ColorPicker(
                            "Color \(index + 1)",
                            selection: colorBinding(
                                get: { preferences.snapshot.paletteColors[index] },
                                set: { next in
                                    preferences.update { snapshot in
                                        snapshot.setPaletteColor(next, at: index)
                                    }
                                }
                            )
                        )
                    }
                }

                HStack(spacing: 10) {
                    Button("Save Palette") {
                        preferences.update { $0.saveCurrentPalette() }
                    }

                    Menu("Load Palette") {
                        if preferences.snapshot.savedColorPalettes.isEmpty {
                            Text("No saved palettes")
                        } else {
                            ForEach(preferences.snapshot.savedColorPalettes) { palette in
                                Button(palette.name) {
                                    preferences.update { $0.loadPalette(palette) }
                                }
                            }
                        }
                    }
                }

                Text("Command+1 through Command+4 use the first four palette colors.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var shortcutsSection: some View {
        let duplicates = preferences.duplicateShortcuts()

        return settingsGroup("Keyboard Shortcuts") {
            Text("Click a field, press a new key combination, or clear it to disable the action.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ShortcutAction.allCases) { action in
                    HStack(spacing: 12) {
                        Text(action.displayName)
                            .frame(width: 220, alignment: .leading)
                            .foregroundStyle(.secondary)

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
            }

            HStack {
                Button("Reset Shortcuts") {
                    preferences.update { $0.shortcuts = ShortcutAction.defaultShortcuts }
                }
                Button("Test Current Shortcuts") {
                    shortcutController.stop()
                    shortcutController.start()
                }
            }
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("Local-only") {
                Text("Digital Meld Annotate does not use accounts, analytics, telemetry, cloud sync, license activation, or normal-operation network calls.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Annotations are in-memory only and are cleared when the app exits.")
                    .foregroundStyle(.secondary)
            }

            settingsGroup("Permissions") {
                Text("Screenshots may require Screen Recording permission. Global shortcuts may require Accessibility or Input Monitoring permission.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button("Screen Recording") {
                        SystemSettings.open(.screenRecording)
                    }
                    Button("Accessibility") {
                        SystemSettings.open(.accessibility)
                    }
                    Button("Input Monitoring") {
                        SystemSettings.open(.inputMonitoring)
                    }
                }
            }
        }
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("Toolbar Help") {
                settingsRow("Tooltips") {
                    Toggle("Show toolbar tooltips", isOn: binding(\.toolbarTooltipsEnabled))
                }
            }

            settingsGroup("Common Tasks") {
                settingsRow("Shortcuts") {
                    Button("Edit Shortcuts") {
                        selectedSection = .shortcuts
                    }
                }

                settingsRow("Permissions") {
                    Button("Review Permissions") {
                        selectedSection = .privacy
                    }
                }

                settingsRow("Diagnostics") {
                    Button("Open Diagnostics") {
                        selectedSection = .diagnostics
                    }
                }
            }

            settingsGroup("About") {
                diagnosticsRow("App version", appVersion)
                diagnosticsRow("License", "MIT")
                diagnosticsRow("Repository", "github.com/bradgroux/dm-annotate")
            }
        }
    }

    private var diagnosticsSection: some View {
        settingsGroup("Runtime") {
            diagnosticsRow("App version", appVersion)
            diagnosticsRow("macOS", ProcessInfo.processInfo.operatingSystemVersionString)
            diagnosticsRow("Launch mode", runtimeState.modeLabel ?? "Normal")
            if let launchModeDetail {
                diagnosticsRow("Launch note", launchModeDetail)
            }
            diagnosticsRow("Screen Recording", PermissionChecks.screenRecordingStatus().label)
            diagnosticsRow("Accessibility", PermissionChecks.accessibilityStatus().label)
            diagnosticsRow("Input Monitoring", "Check Manually")
            diagnosticsRow("Display count", "\(NSScreen.screens.count)")
            diagnosticsRow("Screenshot folder", preferences.expandedScreenshotFolderURL().path)
            diagnosticsRow("Default screenshot output", preferences.snapshot.screenshotOutput == .file ? "File" : "Clipboard")
            diagnosticsRow("Visible tools", "\(preferences.snapshot.visibleTools.count)")

            HStack(spacing: 10) {
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
        }
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .frame(width: 140, alignment: .trailing)
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
        HStack(alignment: .top, spacing: 16) {
            Text(label)
                .frame(width: 150, alignment: .trailing)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
            Spacer(minLength: 0)
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

    private var launchModeDetail: String? {
        if runtimeState.isSafeMode {
            return "Overlays and global shortcuts are disabled because Shift was held during launch."
        }
        if runtimeState.recoveredFromAbnormalExit {
            return "The previous run did not exit cleanly, so the app started in cursor mode and expanded the toolbar."
        }
        return nil
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case tools
    case colors
    case shortcuts
    case help
    case privacy
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .tools: "Tools"
        case .colors: "Colors"
        case .shortcuts: "Shortcuts"
        case .help: "Help"
        case .privacy: "Privacy"
        case .diagnostics: "Diagnostics"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "Core behavior, screenshots, and whiteboard defaults."
        case .tools: "Choose which annotation tools appear in the toolbar."
        case .colors: "Manage the default color, toolbar palette, and saved palettes."
        case .shortcuts: "Customize or disable keyboard shortcuts."
        case .help: "Find tooltip, shortcut, permission, and version details."
        case .privacy: "Review local-only behavior and macOS permissions."
        case .diagnostics: "Inspect runtime state and recover local integrations."
        }
    }

    var systemImage: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .tools: "pencil.and.outline"
        case .colors: "paintpalette"
        case .shortcuts: "keyboard"
        case .help: "questionmark.circle"
        case .privacy: "lock.shield"
        case .diagnostics: "stethoscope"
        }
    }
}
