import AppKit
import DMAnnotateCore
import SwiftUI

struct ToolbarColorControlsView: View {
    @ObservedObject var store: AnnotationStore
    @ObservedObject var preferences: PreferencesController
    var columns: [GridItem]?
    @State private var isPalettePopoverPresented = false
    @State private var selectedPaletteIndex = 0

    private var paletteColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(ToolbarLayoutMetrics.buttonSize), spacing: ToolbarLayoutMetrics.gridSpacing),
            count: ToolbarLayoutMetrics.paletteColumnCount
        )
    }

    var body: some View {
        if let columns {
            LazyVGrid(columns: columns, spacing: ToolbarLayoutMetrics.gridSpacing) {
                controls
            }
        } else {
            controls
        }
    }

    @ViewBuilder private var controls: some View {
        ForEach(Array(preferences.snapshot.paletteColors.prefix(4).enumerated()), id: \.offset) { index, color in
            Button {
                store.currentColor = color
            } label: {
                Circle()
                    .fill(Color(color))
                    .overlay(Circle().stroke(Color.white.opacity(0.52), lineWidth: store.currentColor == color ? 3 : 1))
                    .shadow(color: Color.black.opacity(0.18), radius: 1)
                    .frame(width: 24, height: 24)
                    .frame(width: ToolbarLayoutMetrics.buttonSize, height: ToolbarLayoutMetrics.buttonSize)
            }
            .buttonStyle(.plain)
            .toolbarHelp(tooltip("Quick color \(index + 1)", action: quickColorAction(index)))
            .accessibilityLabel("Quick color \(index + 1)")
        }

        customColorButton
        paletteButton
    }

    private var paletteButton: some View {
        Button {
            ToolbarTooltipController.shared.hide()
            selectedPaletteIndex = nearestPaletteIndex(to: store.currentColor) ?? safePaletteIndex
            isPalettePopoverPresented.toggle()
        } label: {
            ToolbarIcon("paintpalette")
        }
        .buttonStyle(ToolbarIconButtonStyle(active: isPalettePopoverPresented, highContrast: preferences.snapshot.highContrastToolbar))
        .popover(isPresented: $isPalettePopoverPresented, arrowEdge: .bottom) {
            palettePopover
        }
        .toolbarHelp("Color palette")
        .accessibilityLabel("Color palette")
    }

    private var palettePopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: paletteColumns, spacing: ToolbarLayoutMetrics.gridSpacing) {
                ForEach(Array(preferences.snapshot.paletteColors.enumerated()), id: \.offset) { index, color in
                    Button {
                        ToolbarTooltipController.shared.hide()
                        selectedPaletteIndex = index
                        store.currentColor = color
                    } label: {
                        colorSwatch(color, selected: selectedPaletteIndex == index, size: 24)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .toolbarHelp("Palette color \(index + 1)")
                    .contextMenu {
                        Button("Replace Color") {
                            replacePaletteColor(at: index)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    replacePaletteColor(at: safePaletteIndex)
                } label: {
                    Label("Replace", systemImage: "eyedropper")
                }
                .disabled(preferences.snapshot.paletteColors.isEmpty)

                Button {
                    addPaletteColor()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .disabled(preferences.snapshot.paletteColors.count >= RGBAColor.maximumPaletteColorCount)

                Button {
                    removePaletteColor(at: safePaletteIndex)
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(preferences.snapshot.paletteColors.count <= 1)
                .accessibilityLabel("Remove selected palette color")
            }
            .controlSize(.small)

            HStack(spacing: 8) {
                Button {
                    saveCurrentPalette()
                } label: {
                    Label("Save", systemImage: "tray.and.arrow.down")
                }

                Menu {
                    if preferences.snapshot.savedColorPalettes.isEmpty {
                        Text("No saved palettes")
                    } else {
                        ForEach(preferences.snapshot.savedColorPalettes) { palette in
                            Button(palette.name) {
                                loadPalette(palette)
                            }
                        }
                    }
                } label: {
                    Label("Load", systemImage: "tray.and.arrow.up")
                }
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(width: 236)
        .onAppear {
            selectedPaletteIndex = nearestPaletteIndex(to: store.currentColor) ?? safePaletteIndex
        }
    }

    private var customColorButton: some View {
        Button {
            ToolbarTooltipController.shared.hide()
            ToolbarColorPanelController.shared.show(currentColor: store.currentColor, store: store)
        } label: {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(store.currentColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 1)
                .frame(width: ToolbarLayoutMetrics.buttonSize, height: ToolbarLayoutMetrics.buttonSize)
        }
        .buttonStyle(.plain)
        .toolbarHelp(tooltip("Custom color", action: .customColor))
        .accessibilityLabel("Custom color")
    }

    private func colorSwatch(_ color: RGBAColor, selected: Bool, size: CGFloat) -> some View {
        Circle()
            .fill(Color(color))
            .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: selected ? 3 : 1))
            .overlay {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(contrastColor(for: color))
                }
            }
            .shadow(color: Color.black.opacity(0.18), radius: 1)
            .frame(width: size, height: size)
    }

    private func contrastColor(for color: RGBAColor) -> Color {
        let luminance = (0.299 * color.red) + (0.587 * color.green) + (0.114 * color.blue)
        return luminance > 0.62 ? .black : .white
    }

    private var safePaletteIndex: Int {
        guard !preferences.snapshot.paletteColors.isEmpty else { return 0 }
        return min(selectedPaletteIndex, preferences.snapshot.paletteColors.index(before: preferences.snapshot.paletteColors.endIndex))
    }

    private func nearestPaletteIndex(to color: RGBAColor) -> Int? {
        preferences.snapshot.paletteColors.firstIndex(of: color)
    }

    private func replacePaletteColor(at index: Int) {
        guard preferences.snapshot.paletteColors.indices.contains(index) else { return }

        ToolbarTooltipController.shared.hide()
        selectedPaletteIndex = index
        let currentColor = preferences.snapshot.paletteColors[index]
        ToolbarColorPanelController.shared.show(currentColor: currentColor) { color in
            preferences.update { snapshot in
                snapshot.setPaletteColor(color, at: index)
            }
            store.currentColor = color
        }
    }

    private func addPaletteColor() {
        guard preferences.snapshot.paletteColors.count < RGBAColor.maximumPaletteColorCount else { return }

        ToolbarTooltipController.shared.hide()
        ToolbarColorPanelController.shared.show(currentColor: store.currentColor) { color in
            preferences.update { snapshot in
                if snapshot.appendPaletteColor(color) {
                    selectedPaletteIndex = snapshot.paletteColors.index(before: snapshot.paletteColors.endIndex)
                }
            }
            store.currentColor = color
        }
    }

    private func removePaletteColor(at index: Int) {
        preferences.update { snapshot in
            snapshot.removePaletteColor(at: index)
        }
        selectedPaletteIndex = safePaletteIndex
    }

    private func saveCurrentPalette() {
        preferences.update { snapshot in
            snapshot.saveCurrentPalette()
        }
    }

    private func loadPalette(_ palette: SavedColorPalette) {
        preferences.update { snapshot in
            snapshot.loadPalette(palette)
        }
        selectedPaletteIndex = nearestPaletteIndex(to: store.currentColor) ?? 0
    }

    private func quickColorAction(_ index: Int) -> ShortcutAction? {
        switch index {
        case 0: .quickColor1
        case 1: .quickColor2
        case 2: .quickColor3
        case 3: .quickColor4
        default: nil
        }
    }

    private func tooltip(_ label: String, action: ShortcutAction?) -> String {
        guard let action else { return label }
        let shortcut = ShortcutDescriptor.display(preferences.snapshot.shortcuts[action] ?? "")
        guard shortcut != "None" else { return label }
        return "\(label) (\(shortcut))"
    }
}
