import AppKit
import DMAnnotateCore
import SwiftUI

struct ToolbarStrokeTextControlsView: View {
    @ObservedObject var store: AnnotationStore
    @ObservedObject var preferences: PreferencesController
    @State private var isStrokeWidthPopoverPresented = false
    @State private var isTextStylePopoverPresented = false
    @State private var customStrokeWidthText = ""
    @State private var customTextFontSizeText = ""
    @Environment(\.toolbarAccessibilityState) private var accessibilityState

    private var valueColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(ToolbarLayoutMetrics.valueButtonWidth), spacing: ToolbarLayoutMetrics.gridSpacing),
            count: ToolbarLayoutMetrics.valueGridColumnCount
        )
    }

    private var paletteColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(ToolbarLayoutMetrics.buttonSize), spacing: ToolbarLayoutMetrics.gridSpacing),
            count: ToolbarLayoutMetrics.paletteColumnCount
        )
    }

    var body: some View {
        widthMenu
        textStyleMenu
    }

    private var widthMenu: some View {
        Button {
            ToolbarTooltipController.shared.hide()
            customStrokeWidthText = formattedStrokeWidth(store.strokeWidth)
            isStrokeWidthPopoverPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "lineweight")
                Text(formattedStrokeWidth(store.strokeWidth))
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .frame(width: ToolbarLayoutMetrics.menuControlWidth, height: ToolbarLayoutMetrics.buttonSize)
        }
        .buttonStyle(ToolbarIconButtonStyle(active: isStrokeWidthPopoverPresented, highContrast: preferences.snapshot.highContrastToolbar))
        .popover(isPresented: $isStrokeWidthPopoverPresented, arrowEdge: .bottom) {
            strokeWidthPopover
        }
        .toolbarHelp(strokeWidthHelp)
        .toolbarAccessibility(accessibilityState.control(
            label: "Stroke width",
            value: accessibilityState.strokeWidthValue,
            hint: "Choose or enter a stroke width",
            identifier: "toolbar.stroke-width"
        ))
    }

    private var strokeWidthPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: valueColumns, spacing: ToolbarLayoutMetrics.gridSpacing) {
                ForEach(AnnotationStore.supportedStrokeWidths, id: \.self) { width in
                    Button {
                        ToolbarTooltipController.shared.hide()
                        store.setStrokeWidth(width)
                        customStrokeWidthText = formattedStrokeWidth(width)
                    } label: {
                        Text("\(Int(width))")
                            .font(.caption.weight(.semibold))
                            .frame(width: ToolbarLayoutMetrics.valueButtonWidth, height: 28)
                            .adaptiveSelectedControl(
                                selected: store.strokeWidth == width,
                                unselectedBackground: Color.primary.opacity(0.08),
                                cornerRadius: 6
                            )
                    }
                    .buttonStyle(.plain)
                    .toolbarHelp("\(Int(width)) px")
                    .toolbarAccessibility(accessibilityState.control(
                        label: "\(Int(width)) pixel stroke width",
                        value: store.strokeWidth == width ? "Selected" : "Available",
                        hint: "Use this stroke width",
                        identifier: "toolbar.stroke-width.\(Int(width))",
                        isSelected: store.strokeWidth == width
                    ))
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("Custom", text: $customStrokeWidthText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 76)
                    .onSubmit(applyCustomStrokeWidth)

                Text("px")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Set") {
                    applyCustomStrokeWidth()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(10)
        .frame(width: 210)
        .onAppear {
            customStrokeWidthText = formattedStrokeWidth(store.strokeWidth)
        }
    }

    private var textStyleMenu: some View {
        Button {
            ToolbarTooltipController.shared.hide()
            customTextFontSizeText = formattedTextFontSize(store.textFontSize)
            isTextStylePopoverPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "textformat.size")
                Text(formattedTextFontSize(store.textFontSize))
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .frame(width: ToolbarLayoutMetrics.menuControlWidth, height: ToolbarLayoutMetrics.buttonSize)
        }
        .buttonStyle(ToolbarIconButtonStyle(active: isTextStylePopoverPresented, highContrast: preferences.snapshot.highContrastToolbar))
        .popover(isPresented: $isTextStylePopoverPresented, arrowEdge: .bottom) {
            textStylePopover
        }
        .toolbarHelp("Text style: \(formattedTextFontSize(store.textFontSize)) px, \(store.textFontWeight.displayName)")
        .toolbarAccessibility(accessibilityState.control(
            label: "Text style",
            value: accessibilityState.textStyleValue,
            hint: "Choose the text size, weight, and color",
            identifier: "toolbar.text-style"
        ))
    }

    private var textStylePopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Size")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: valueColumns, spacing: ToolbarLayoutMetrics.gridSpacing) {
                    ForEach(AnnotationStore.supportedTextFontSizes, id: \.self) { size in
                        Button {
                            ToolbarTooltipController.shared.hide()
                            store.setTextFontSize(size)
                            customTextFontSizeText = formattedTextFontSize(size)
                        } label: {
                            Text("\(Int(size))")
                                .font(.caption.weight(.semibold))
                                .frame(width: ToolbarLayoutMetrics.valueButtonWidth, height: 28)
                                .adaptiveSelectedControl(
                                    selected: store.textFontSize == size,
                                    unselectedBackground: Color.primary.opacity(0.08),
                                    cornerRadius: 6
                                )
                        }
                        .buttonStyle(.plain)
                        .toolbarHelp("\(Int(size)) px text")
                        .toolbarAccessibility(accessibilityState.control(
                            label: "\(Int(size)) pixel text size",
                            value: store.textFontSize == size ? "Selected" : "Available",
                            hint: "Use this text size",
                            identifier: "toolbar.text-size.\(Int(size))",
                            isSelected: store.textFontSize == size
                        ))
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Custom", text: $customTextFontSizeText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 76)
                    .onSubmit(applyCustomTextFontSize)

                Text("px")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Set") {
                    applyCustomTextFontSize()
                }
                .keyboardShortcut(.defaultAction)
            }

            Divider()

            Picker("Weight", selection: textFontWeightBinding) {
                ForEach(TextFontWeight.allCases) { weight in
                    Text(weight.displayName).tag(weight)
                }
            }
            .pickerStyle(.menu)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: paletteColumns, spacing: ToolbarLayoutMetrics.gridSpacing) {
                    ForEach(Array(preferences.snapshot.paletteColors.enumerated()), id: \.offset) { index, color in
                        Button {
                            ToolbarTooltipController.shared.hide()
                            store.setCurrentColor(color)
                        } label: {
                            colorSwatch(color, selected: store.currentColor == color, size: 24)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .toolbarHelp("Text color \(index + 1)")
                        .toolbarAccessibility(accessibilityState.control(
                            label: "Text color \(index + 1)",
                            value: store.currentColor == color ? "Selected, \(colorName(color))" : colorName(color),
                            hint: "Use this text color",
                            identifier: "toolbar.text-color.\(index + 1)",
                            isSelected: store.currentColor == color
                        ))
                    }
                }

                Button {
                    ToolbarTooltipController.shared.hide()
                    ToolbarColorPanelController.shared.show(currentColor: store.currentColor, store: store)
                } label: {
                    Label("Custom color", systemImage: "eyedropper")
                }
                .controlSize(.small)
            }
        }
        .padding(10)
        .frame(width: 236)
        .onAppear {
            customTextFontSizeText = formattedTextFontSize(store.textFontSize)
        }
    }

    private func applyCustomStrokeWidth() {
        let normalizedInput = customStrokeWidthText
            .lowercased()
            .replacingOccurrences(of: "px", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value = Double(normalizedInput) else {
            NSSound.beep()
            return
        }

        let width = AnnotationStore.normalizedStrokeWidth(CGFloat(value))
        store.setStrokeWidth(width)
        customStrokeWidthText = formattedStrokeWidth(width)
        isStrokeWidthPopoverPresented = false
    }

    private func applyCustomTextFontSize() {
        let normalizedInput = customTextFontSizeText
            .lowercased()
            .replacingOccurrences(of: "px", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value = Double(normalizedInput) else {
            NSSound.beep()
            return
        }

        let size = AnnotationStore.normalizedTextFontSize(CGFloat(value))
        store.setTextFontSize(size)
        customTextFontSizeText = formattedTextFontSize(size)
        isTextStylePopoverPresented = false
    }

    private func formattedStrokeWidth(_ width: CGFloat) -> String {
        "\(Int(AnnotationStore.normalizedStrokeWidth(width)))"
    }

    private func formattedTextFontSize(_ size: CGFloat) -> String {
        "\(Int(AnnotationStore.normalizedTextFontSize(size)))"
    }

    private var textFontWeightBinding: Binding<TextFontWeight> {
        Binding(
            get: { store.textFontWeight },
            set: { store.setTextFontWeight($0) }
        )
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

    private func colorName(_ color: RGBAColor) -> String {
        accessibilityState.colorValue(for: color)
    }

    private var strokeWidthHelp: String {
        let decrease = shortcutText(for: .decreaseStrokeWidth)
        let increase = shortcutText(for: .increaseStrokeWidth)
        return "Stroke width \(formattedStrokeWidth(store.strokeWidth)) px (decrease: \(decrease), increase: \(increase))"
    }

    private func shortcutText(for action: ShortcutAction) -> String {
        ShortcutDescriptor.display(preferences.snapshot.shortcuts[action] ?? "")
    }
}
