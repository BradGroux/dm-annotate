import AppKit
import DMAnnotateCore
import SwiftUI

struct SettingsDiagnosticsSectionView: View {
    @ObservedObject var store: AnnotationStore
    @ObservedObject var preferences: PreferencesController
    var shortcutController: ShortcutController
    @ObservedObject var runtimeState: AppRuntimeState

    var body: some View {
        SettingsGroup("Runtime") {
            SettingsDiagnosticsRow(label: "App version", value: SettingsRuntimeInfo.appVersion)
            SettingsDiagnosticsRow(label: "macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
            SettingsDiagnosticsRow(label: "Launch mode", value: runtimeState.modeLabel ?? "Normal")
            if let launchModeDetail = SettingsRuntimeInfo.launchModeDetail(for: runtimeState) {
                SettingsDiagnosticsRow(label: "Launch note", value: launchModeDetail)
            }
            SettingsDiagnosticsRow(label: "Screen Recording", value: PermissionChecks.screenRecordingStatus().label)
            SettingsDiagnosticsRow(label: "Accessibility", value: PermissionChecks.accessibilityStatus().label)
            SettingsDiagnosticsRow(label: "Input Monitoring", value: "Check Manually")
            SettingsDiagnosticsRow(label: "Display count", value: "\(NSScreen.screens.count)")
            SettingsDiagnosticsRow(label: "Screenshot folder", value: preferences.expandedScreenshotFolderURL().path)
            SettingsDiagnosticsRow(label: "Default screenshot output", value: preferences.snapshot.screenshotOutput == .file ? "File" : "Clipboard")
            SettingsDiagnosticsRow(label: "Visible tools", value: "\(preferences.snapshot.visibleTools.count)")
            SettingsDiagnosticsRow(label: "Annotations", value: "\(store.annotations.count) / \(AnnotationStore.maximumAnnotationCount)")
            SettingsDiagnosticsRow(label: "Undo depth", value: "\(store.undoDepth) / \(AnnotationStore.maximumUndoDepth)")
            SettingsDiagnosticsRow(label: "Redo depth", value: "\(store.redoDepth)")

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
}
