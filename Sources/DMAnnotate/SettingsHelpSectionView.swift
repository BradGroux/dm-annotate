import DMAnnotateCore
import SwiftUI

struct SettingsHelpSectionView: View {
    @ObservedObject var preferences: PreferencesController
    @Binding var selectedSection: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup("Toolbar Help") {
                SettingsRow("Tooltips") {
                    Toggle("Show toolbar tooltips", isOn: binding(\.toolbarTooltipsEnabled))
                }
            }

            SettingsGroup("Common Tasks") {
                SettingsRow("Shortcuts") {
                    Button("Edit Shortcuts") {
                        selectedSection = .shortcuts
                    }
                }

                SettingsRow("Permissions") {
                    Button("Review Permissions") {
                        selectedSection = .privacy
                    }
                }

                SettingsRow("Diagnostics") {
                    Button("Open Diagnostics") {
                        selectedSection = .diagnostics
                    }
                }
            }

            SettingsGroup("About") {
                SettingsDiagnosticsRow(label: "App version", value: SettingsRuntimeInfo.appVersion)
                SettingsDiagnosticsRow(label: "License", value: "MIT")
                SettingsDiagnosticsRow(label: "Repository", value: "github.com/bradgroux/dm-annotate")
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
}
