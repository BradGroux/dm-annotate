import SwiftUI

struct SettingsPrivacySectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup("Local-only") {
                Text("Digital Meld Annotate does not use accounts, analytics, telemetry, cloud sync, license activation, or normal-operation network calls.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Annotations are in-memory only and are cleared when the app exits.")
                    .foregroundStyle(.secondary)
            }

            SettingsGroup("Permissions") {
                Text("Screenshots may require Screen Recording permission. Global shortcuts use a consumable event tap and may require Accessibility or Input Monitoring permission. Check Diagnostics if global shortcuts are unavailable.")
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
}
