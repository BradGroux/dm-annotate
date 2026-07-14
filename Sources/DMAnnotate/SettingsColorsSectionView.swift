import DMAnnotateCore
import SwiftUI

struct SettingsColorsSectionView: View {
    @ObservedObject var store: AnnotationStore
    @ObservedObject var preferences: PreferencesController

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup("Default") {
                SettingsRow("Default color") {
                    ColorPicker(
                        "Default annotation color",
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

            SettingsGroup("Toolbar Palette") {
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
                            "Toolbar palette color \(index + 1)",
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
                    .accessibilityLabel("Save toolbar color palette")

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
                    .accessibilityLabel("Load toolbar color palette")
                }

                Text("Command+1 through Command+4 use the first four palette colors.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func colorBinding(get: @escaping () -> RGBAColor, set: @escaping (RGBAColor) -> Void) -> Binding<Color> {
        Binding(
            get: { Color(get()) },
            set: { set(RGBAColor($0)) }
        )
    }
}
