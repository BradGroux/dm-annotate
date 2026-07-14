import AppKit
import DMAnnotateCore
import SwiftUI

struct ToolbarToolSelectionView: View {
    @ObservedObject var store: AnnotationStore
    @ObservedObject var preferences: PreferencesController
    @ObservedObject var runtimeState: AppRuntimeState

    var body: some View {
        ForEach(AnnotationTool.allCases.filter { preferences.snapshot.visibleTools.contains($0) }) { tool in
            Button {
                guard ToolbarToolAvailability.isEnabled(tool, isSafeMode: runtimeState.isSafeMode) else {
                    NSSound.beep()
                    return
                }
                preferences.setActiveTool(tool)
            } label: {
                ToolbarIcon(tool.systemImageName)
            }
            .buttonStyle(ToolbarIconButtonStyle(active: isActive(tool), highContrast: preferences.snapshot.highContrastToolbar))
            .disabled(!ToolbarToolAvailability.isEnabled(tool, isSafeMode: runtimeState.isSafeMode))
            .toolbarHelp(helpText(for: tool))
            .accessibilityLabel(tool.displayName)
        }
    }

    private func isActive(_ tool: AnnotationTool) -> Bool {
        switch tool {
        case .whiteboard:
            return store.whiteboardModeEnabled && !store.whiteboardBackground.isDarkBoard
        case .blackboard:
            return store.whiteboardModeEnabled && store.whiteboardBackground.isDarkBoard
        default:
            return store.activeTool == tool
        }
    }

    private func helpText(for tool: AnnotationTool) -> String {
        let availableHelp: String
        if let action = ShortcutAction.toolAction(for: tool) {
            availableHelp = tooltip(tool.displayName, action: action)
        } else {
            availableHelp = tool.displayName
        }

        return ToolbarToolAvailability.helpText(
            for: tool,
            isSafeMode: runtimeState.isSafeMode,
            availableHelp: availableHelp
        )
    }

    private func tooltip(_ label: String, action: ShortcutAction) -> String {
        let shortcut = ShortcutDescriptor.display(preferences.snapshot.shortcuts[action] ?? "")
        guard shortcut != "None" else { return label }
        return "\(label) (\(shortcut))"
    }
}
