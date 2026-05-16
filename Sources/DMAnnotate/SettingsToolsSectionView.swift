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
                ForEach(AnnotationTool.allCases) { tool in
                    Toggle(tool.displayName, isOn: toolVisibilityBinding(tool))
                }
            }
        }
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
}
