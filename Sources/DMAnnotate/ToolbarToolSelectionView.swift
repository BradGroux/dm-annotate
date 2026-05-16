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
                guard !runtimeState.isSafeMode else {
                    NSSound.beep()
                    return
                }
                store.setActiveTool(tool)
            } label: {
                ToolbarIcon(tool.systemImageName)
            }
            .buttonStyle(ToolbarIconButtonStyle(active: isActive(tool), highContrast: preferences.snapshot.highContrastToolbar))
            .disabled(runtimeState.isSafeMode)
            .toolbarHelp(helpText(for: tool))
            .accessibilityLabel(tool.displayName)
        }
    }

    private func isActive(_ tool: AnnotationTool) -> Bool {
        switch tool {
        case .whiteboard:
            return store.whiteboardModeEnabled && [.white, .lightGrid].contains(store.whiteboardBackground)
        case .blackboard:
            return store.whiteboardModeEnabled && [.black, .darkGrid].contains(store.whiteboardBackground)
        default:
            return store.activeTool == tool
        }
    }

    private func helpText(for tool: AnnotationTool) -> String {
        guard let action = ShortcutAction.toolAction(for: tool) else {
            return tool.displayName
        }

        return tooltip(tool.displayName, action: action)
    }

    private func tooltip(_ label: String, action: ShortcutAction) -> String {
        let shortcut = ShortcutDescriptor.display(preferences.snapshot.shortcuts[action] ?? "")
        guard shortcut != "None" else { return label }
        return "\(label) (\(shortcut))"
    }
}
