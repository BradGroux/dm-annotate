import DMAnnotateCore
import SwiftUI

struct SettingsShortcutsSectionView: View {
    @ObservedObject var preferences: PreferencesController
    var shortcutController: ShortcutController
    @ObservedObject var runtimeState: AppRuntimeState

    var body: some View {
        let duplicates = preferences.duplicateShortcuts()

        SettingsGroup("Keyboard Shortcuts") {
            Text("Click a field, press a new key combination, or clear it to disable the action.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ShortcutAction.allCases) { action in
                    let normalized = ShortcutDescriptor.normalize(preferences.snapshot.shortcuts[action] ?? "")

                    HStack(spacing: 12) {
                        Text(action.displayName)
                            .frame(width: 220, alignment: .leading)
                            .foregroundStyle(.secondary)

                        ShortcutRecorderField(
                            shortcut: shortcutBinding(action),
                            isDuplicate: duplicates.contains(normalized)
                        )
                        .frame(height: 30)

                        if duplicates.contains(normalized) {
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
                Button(ShortcutRecoveryPresentation.actionLabel) {
                    shortcutController.restart()
                }
                .accessibilityLabel(ShortcutRecoveryPresentation.actionLabel)
                .disabled(!ShortcutRecoveryPresentation.isEnabled(isSafeMode: runtimeState.isSafeMode))
                .help(ShortcutRecoveryPresentation.actionHelp(isSafeMode: runtimeState.isSafeMode))
            }
        }
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
}
