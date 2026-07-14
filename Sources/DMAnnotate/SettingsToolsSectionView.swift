import DMAnnotateCore
import SwiftUI

struct SettingsToolsSectionView: View {
    @ObservedObject var preferences: PreferencesController

    var body: some View {
        SettingsGroup("Visible Toolbar Tools") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), alignment: .leading)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(AnnotationTool.allCases.filter { $0 != .whiteboard && $0 != .blackboard }) { tool in
                    Toggle(tool.displayName, isOn: toolVisibilityBinding(tool))
                        .accessibilityIdentifier("settings.tools.\(tool.rawValue)")
                }

                Toggle("Whiteboard and blackboard", isOn: boardVisibilityBinding)
                    .accessibilityLabel("Show Whiteboard and Blackboard tools")
                    .accessibilityHint("Shows or hides both board background controls in the toolbar")
                    .accessibilityIdentifier("settings.tools.boardPair")
            }
        }
    }

    private var boardVisibilityBinding: Binding<Bool> {
        Binding(
            get: { preferences.snapshot.boardToolsVisible },
            set: { isVisible in
                preferences.update { $0.setBoardToolsVisible(isVisible) }
            }
        )
    }

    private func toolVisibilityBinding(_ tool: AnnotationTool) -> Binding<Bool> {
        Binding(
            get: { preferences.snapshot.visibleTools.contains(tool) },
            set: { isVisible in
                preferences.update { $0.setToolVisible(tool, isVisible: isVisible) }
            }
        )
    }
}
