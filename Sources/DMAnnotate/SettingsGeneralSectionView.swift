import AppKit
import DMAnnotateCore
import SwiftUI

struct SettingsGeneralSectionView: View {
    @ObservedObject var store: AnnotationStore
    @ObservedObject var preferences: PreferencesController
    @State private var presetName = "Toolbar Preset"

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup("Appearance") {
                SettingsRow("Theme") {
                    Picker("", selection: binding(\.theme)) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue.capitalized).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
            }

            SettingsGroup("Toolbar") {
                SettingsRow("Orientation") {
                    Picker("", selection: binding(\.toolbarOrientation)) {
                        ForEach(ToolbarOrientation.allCases) { orientation in
                            Text(orientation.rawValue.capitalized).tag(orientation)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }

                SettingsRow("Behavior") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Collapse toolbar", isOn: binding(\.toolbarCollapsed))
                        Toggle("Compact presenter mode", isOn: binding(\.toolbarCompactMode))
                        Toggle("High contrast toolbar", isOn: binding(\.highContrastToolbar))
                        Toggle("Show toolbar tooltips", isOn: binding(\.toolbarTooltipsEnabled))
                    }
                }

                SettingsRow("Presets") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            TextField("Preset name", text: $presetName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 220)
                            Button {
                                saveToolbarPreset()
                            } label: {
                                Label("Save", systemImage: "tray.and.arrow.down")
                            }
                        }

                        if preferences.snapshot.toolbarPresets.isEmpty {
                            Text("No toolbar presets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(preferences.snapshot.toolbarPresets) { preset in
                                    HStack(spacing: 8) {
                                        Text(preset.name)
                                            .lineLimit(1)
                                            .frame(width: 190, alignment: .leading)
                                        Button {
                                            applyToolbarPreset(preset)
                                        } label: {
                                            Label("Apply", systemImage: "arrow.down.left.and.arrow.up.right")
                                        }
                                        Button {
                                            preferences.update { $0.deleteToolbarPreset(id: preset.id) }
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .accessibilityLabel("Delete toolbar preset")
                                    }
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
            }

            SettingsGroup("Screenshots") {
                SettingsRow("Output") {
                    Picker("", selection: binding(\.screenshotOutput)) {
                        ForEach(ScreenshotOutput.allCases) { output in
                            Text(output == .file ? "Save PNG file" : "Copy to clipboard").tag(output)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                }

                SettingsRow("Options") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Ask before saving screenshot files", isOn: binding(\.confirmScreenshotFilename))
                        Toggle("Reveal screenshots in Finder after saving", isOn: binding(\.revealScreenshotAfterSave))
                    }
                }

                SettingsRow("Folder") {
                    HStack(spacing: 10) {
                        TextField("Screenshot folder", text: binding(\.screenshotFolder))
                        Button("Choose...") {
                            chooseScreenshotFolder()
                        }
                    }
                }
            }

            SettingsGroup("Whiteboard") {
                SettingsRow("Background") {
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

    private func binding<Value>(_ keyPath: WritableKeyPath<PreferencesSnapshot, Value>) -> Binding<Value> {
        Binding(
            get: { preferences.snapshot[keyPath: keyPath] },
            set: { next in
                preferences.update { $0[keyPath: keyPath] = next }
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

    private func saveToolbarPreset() {
        let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        preferences.update { snapshot in
            snapshot.saveToolbarPreset(named: name.isEmpty ? "Toolbar Preset \(snapshot.toolbarPresets.count + 1)" : name)
        }
        presetName = "Toolbar Preset \(preferences.snapshot.toolbarPresets.count + 1)"
    }

    private func applyToolbarPreset(_ preset: ToolbarPreset) {
        let displays = Set(NSScreen.screens.map { "\($0.displayID)" })
        preferences.update { snapshot in
            snapshot.applyToolbarPreset(preset, availableDisplayIDs: displays)
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
}
