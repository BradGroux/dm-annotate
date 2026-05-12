import AppKit
import DMAnnotateCore
import SwiftUI

struct ToolbarContentView: View {
    @ObservedObject var store: AnnotationStore
    @ObservedObject var preferences: PreferencesController
    @ObservedObject var runtimeState: AppRuntimeState
    var actions: ToolbarActions
    @State private var permissionSummary = PermissionSummary.current()
    @State private var isPalettePopoverPresented = false
    @State private var isStrokeWidthPopoverPresented = false
    @State private var isScreenshotPopoverPresented = false
    @State private var customStrokeWidthText = ""
    @State private var selectedPaletteIndex = 0

    private let buttonSize: CGFloat = 30
    private let gridSpacing: CGFloat = 6

    private var compactColumns: [GridItem] {
        [
            GridItem(.fixed(buttonSize), spacing: gridSpacing),
            GridItem(.fixed(buttonSize), spacing: gridSpacing)
        ]
    }

    private var paletteColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(30), spacing: gridSpacing), count: 5)
    }

    private var strokeWidthColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(42), spacing: gridSpacing), count: 4)
    }

    var body: some View {
        Group {
            if preferences.snapshot.toolbarCollapsed {
                collapsedBody
            } else if preferences.snapshot.toolbarOrientation == .vertical {
                verticalBody
            } else {
                horizontalBody
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(toolbarStrokeColor, lineWidth: store.isControllingScreen ? 2 : 1)
        )
        .shadow(color: store.isControllingScreen ? Color.cyan.opacity(0.45) : Color.black.opacity(0.22), radius: store.isControllingScreen ? 9 : 5)
        .accessibilityLabel("Digital Meld Annotate toolbar")
        .environment(\.toolbarTooltipsEnabled, preferences.snapshot.toolbarTooltipsEnabled)
        .onAppear(perform: refreshPermissionSummary)
        .onChange(of: preferences.snapshot.toolbarTooltipsEnabled) { isEnabled in
            if !isEnabled {
                ToolbarTooltipController.shared.hide()
            }
        }
    }

    private var collapsedBody: some View {
        HStack(spacing: gridSpacing) {
            collapsedDragBar
            Button {
                actions.expandToolbar()
            } label: {
                toolbarIcon("chevron.right")
            }
            .buttonStyle(toolbarButtonStyle(active: false))
            .toolbarHelp(tooltip("Expand toolbar", action: .toggleToolbarCollapsed))
            .accessibilityLabel("Expand toolbar")
        }
        .frame(width: 50, height: buttonSize, alignment: .leading)
    }

    private var verticalBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: gridSpacing) {
                dragBar

                LazyVGrid(columns: compactColumns, spacing: gridSpacing) {
                    orientationToggle
                    collapseToggle
                    statusControls
                }

                sectionDivider

                LazyVGrid(columns: compactColumns, spacing: gridSpacing) {
                    toolButtons
                }

                sectionDivider

                LazyVGrid(columns: compactColumns, spacing: gridSpacing) {
                    colorControls
                }
                widthMenu

                sectionDivider

                LazyVGrid(columns: compactColumns, spacing: gridSpacing) {
                    actionButtons
                }
            }
            .padding(.bottom, gridSpacing)
        }
        .frame(width: 72)
    }

    private var horizontalBody: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: gridSpacing) {
                dragBar
                orientationToggle
                collapseToggle
                statusControls
                verticalDivider
                toolButtons
                verticalDivider
                colorControls
                widthMenu
                verticalDivider
                actionButtons
            }
        }
    }

    private var dragBar: some View {
        ZStack {
            Capsule()
                .fill(preferences.snapshot.highContrastToolbar ? Color.primary.opacity(0.38) : Color.white.opacity(0.32))
                .frame(width: preferences.snapshot.toolbarOrientation == .vertical ? 42 : 8, height: preferences.snapshot.toolbarOrientation == .vertical ? 5 : 28)
            WindowDragHandle()
        }
        .frame(width: preferences.snapshot.toolbarOrientation == .vertical ? 62 : 16, height: preferences.snapshot.toolbarOrientation == .vertical ? 16 : buttonSize)
        .contentShape(Rectangle())
        .toolbarHelp("Drag toolbar")
        .accessibilityLabel("Drag toolbar")
    }

    private var collapsedDragBar: some View {
        ZStack {
            Capsule()
                .fill(preferences.snapshot.highContrastToolbar ? Color.primary.opacity(0.42) : Color.white.opacity(0.34))
                .frame(width: 10, height: 28)
            WindowDragHandle()
        }
        .frame(width: 14, height: buttonSize)
        .contentShape(Rectangle())
        .toolbarHelp("Drag toolbar")
        .accessibilityLabel("Drag toolbar")
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.14))
            .frame(height: 1)
            .padding(.vertical, 2)
            .accessibilityHidden(true)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.14))
            .frame(width: 1, height: 28)
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var statusControls: some View {
        if permissionSummary.needsAttention {
            Button {
                actions.showPermissions()
                refreshPermissionSummary()
            } label: {
                toolbarIcon("exclamationmark.triangle.fill")
            }
            .buttonStyle(toolbarButtonStyle(active: true))
            .toolbarHelp(tooltip(permissionSummary.message, action: .showPermissions))
            .accessibilityLabel("Permission warning")
        }
    }

    private var orientationToggle: some View {
        Button {
            actions.toggleToolbarOrientation()
        } label: {
            toolbarIcon(preferences.snapshot.toolbarOrientation == .vertical ? "arrow.left.and.right" : "arrow.up.and.down")
        }
        .buttonStyle(toolbarButtonStyle(active: false))
        .toolbarHelp(tooltip(preferences.snapshot.toolbarOrientation == .vertical ? "Switch to horizontal toolbar" : "Switch to vertical toolbar", action: .toggleToolbarOrientation))
        .accessibilityLabel("Switch toolbar orientation")
    }

    private var collapseToggle: some View {
        Button {
            actions.toggleToolbarCollapsed()
        } label: {
            toolbarIcon("line.3.horizontal")
        }
        .buttonStyle(toolbarButtonStyle(active: false))
        .toolbarHelp(tooltip("Collapse toolbar", action: .toggleToolbarCollapsed))
        .accessibilityLabel("Collapse toolbar")
    }

    @ViewBuilder private var toolButtons: some View {
        ForEach(AnnotationTool.allCases.filter { preferences.snapshot.visibleTools.contains($0) }) { tool in
            Button {
                guard !runtimeState.isSafeMode else {
                    NSSound.beep()
                    return
                }
                store.setActiveTool(tool)
            } label: {
                toolbarIcon(tool.systemImageName)
            }
            .buttonStyle(toolbarButtonStyle(active: isActive(tool)))
            .disabled(runtimeState.isSafeMode)
            .toolbarHelp(helpText(for: tool))
            .accessibilityLabel(tool.displayName)
        }
    }

    @ViewBuilder private var colorControls: some View {
        ForEach(Array(preferences.snapshot.paletteColors.prefix(4).enumerated()), id: \.offset) { index, color in
            Button {
                store.currentColor = color
            } label: {
                Circle()
                    .fill(Color(color))
                    .overlay(Circle().stroke(Color.white.opacity(0.52), lineWidth: store.currentColor == color ? 3 : 1))
                    .shadow(color: Color.black.opacity(0.18), radius: 1)
                    .frame(width: 24, height: 24)
                    .frame(width: buttonSize, height: buttonSize)
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
            toolbarIcon("paintpalette")
        }
        .buttonStyle(toolbarButtonStyle(active: isPalettePopoverPresented))
        .popover(isPresented: $isPalettePopoverPresented, arrowEdge: .bottom) {
            palettePopover
        }
        .toolbarHelp("Color palette")
        .accessibilityLabel("Color palette")
    }

    private var palettePopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: paletteColumns, spacing: gridSpacing) {
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
                .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(.plain)
        .toolbarHelp(tooltip("Custom color", action: .customColor))
        .accessibilityLabel("Custom color")
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
            .frame(width: 66, height: buttonSize)
        }
        .buttonStyle(toolbarButtonStyle(active: isStrokeWidthPopoverPresented))
        .popover(isPresented: $isStrokeWidthPopoverPresented, arrowEdge: .bottom) {
            strokeWidthPopover
        }
        .toolbarHelp(strokeWidthHelp)
        .accessibilityLabel("Stroke width")
    }

    private var strokeWidthPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: strokeWidthColumns, spacing: gridSpacing) {
                ForEach(AnnotationStore.supportedStrokeWidths, id: \.self) { width in
                    Button {
                        ToolbarTooltipController.shared.hide()
                        store.setStrokeWidth(width)
                        customStrokeWidthText = formattedStrokeWidth(width)
                    } label: {
                        Text("\(Int(width))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(store.strokeWidth == width ? Color.white : Color.primary)
                            .frame(width: 42, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(store.strokeWidth == width ? Color.accentColor : Color.primary.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                    .toolbarHelp("\(Int(width)) px")
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

    @ViewBuilder private var actionButtons: some View {
        iconButton(store.annotationsLocked ? "lock.fill" : "lock.open", active: store.annotationsLocked, help: store.annotationsLocked ? "Unlock annotations" : "Lock annotations", shortcut: .toggleAnnotationLock) {
            actions.toggleAnnotationLock()
        }
        iconButton("arrow.uturn.backward", active: false, enabled: store.canUndo, help: "Undo", shortcut: .undo) {
            store.undo()
        }
        iconButton("arrow.uturn.forward", active: false, enabled: store.canRedo, help: "Redo", shortcut: .redo) {
            store.redo()
        }
        iconButton(store.isVisible ? "eye" : "eye.slash", active: false, help: "Show or hide annotations", shortcut: .toggleAnnotationVisibility) {
            store.toggleVisibility()
        }
        iconButton("trash", active: false, help: "Clear all", shortcut: .clearAll) {
            store.clearAll()
        }
        screenshotMenu
        iconButton("crop", active: false, help: "Region screenshot", shortcut: .regionScreenshot) {
            actions.regionScreenshot()
        }
        iconButton("gearshape", active: false, help: "Settings", shortcut: .showSettings) {
            actions.showSettings()
        }
    }

    private var screenshotMenu: some View {
        Button {
            ToolbarTooltipController.shared.hide()
            isScreenshotPopoverPresented.toggle()
        } label: {
            toolbarIcon("camera.viewfinder")
        }
        .buttonStyle(toolbarButtonStyle(active: isScreenshotPopoverPresented))
        .popover(isPresented: $isScreenshotPopoverPresented, arrowEdge: .trailing) {
            screenshotOptionsPopover
        }
        .toolbarHelp(tooltip("Screenshot options", action: .screenshot))
        .accessibilityLabel("Screenshot options")
    }

    private var screenshotOptionsPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            screenshotOption("Default Destination", systemImage: "camera.viewfinder", action: .screenshot) {
                actions.screenshot()
            }
            screenshotOption("Copy PNG", systemImage: "doc.on.clipboard", action: .copyScreenshot) {
                actions.copyScreenshot()
            }
            screenshotOption("Save PNG", systemImage: "square.and.arrow.down", action: .saveScreenshot) {
                actions.saveScreenshot()
            }
            screenshotOption("Reveal Last", systemImage: "folder", action: .revealLastScreenshot) {
                actions.revealLastScreenshot()
            }
        }
        .padding(8)
        .frame(width: 226)
    }

    private func screenshotOption(
        _ label: String,
        systemImage: String,
        action shortcut: ShortcutAction,
        perform: @escaping () -> Void
    ) -> some View {
        Button {
            ToolbarTooltipController.shared.hide()
            isScreenshotPopoverPresented = false
            perform()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 20)
                Text(label)
                Spacer()
                Text(shortcutText(for: shortcut))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func iconButton(
        _ systemName: String,
        active: Bool,
        enabled: Bool = true,
        help: String,
        shortcut: ShortcutAction? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            toolbarIcon(systemName)
        }
        .buttonStyle(toolbarButtonStyle(active: active))
        .disabled(!enabled)
        .toolbarHelp(tooltip(help, action: shortcut))
        .accessibilityLabel(help)
    }

    private func toolbarIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 16, weight: .medium))
            .frame(width: buttonSize, height: buttonSize)
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

    private func formattedStrokeWidth(_ width: CGFloat) -> String {
        "\(Int(AnnotationStore.normalizedStrokeWidth(width)))"
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
        let shortcut = shortcutText(for: action)
        guard shortcut != "None" else { return label }
        return "\(label) (\(shortcut))"
    }

    private func shortcutText(for action: ShortcutAction) -> String {
        ShortcutDescriptor.display(preferences.snapshot.shortcuts[action] ?? "")
    }

    private var strokeWidthHelp: String {
        let decrease = shortcutText(for: .decreaseStrokeWidth)
        let increase = shortcutText(for: .increaseStrokeWidth)
        return "Stroke width \(formattedStrokeWidth(store.strokeWidth)) px (decrease: \(decrease), increase: \(increase))"
    }

    private var toolbarStrokeColor: Color {
        if preferences.snapshot.highContrastToolbar {
            return store.isControllingScreen ? .cyan : .primary.opacity(0.55)
        }
        return store.isControllingScreen ? .cyan : .white.opacity(0.18)
    }

    private func toolbarButtonStyle(active: Bool) -> ToolbarIconButtonStyle {
        ToolbarIconButtonStyle(active: active, highContrast: preferences.snapshot.highContrastToolbar)
    }

    private func refreshPermissionSummary() {
        permissionSummary = PermissionSummary.current()
    }
}

struct ToolbarIconButtonStyle: ButtonStyle {
    var active: Bool
    var highContrast: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(active ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fillColor(isPressed: configuration.isPressed))
            )
    }

    private func fillColor(isPressed: Bool) -> Color {
        if active {
            return .accentColor
        }
        if highContrast {
            return Color.primary.opacity(isPressed ? 0.24 : 0.14)
        }
        return Color.white.opacity(isPressed ? 0.14 : 0.07)
    }
}

private struct ToolbarTooltipModifier: ViewModifier {
    @Environment(\.toolbarTooltipsEnabled) private var tooltipsEnabled

    let text: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if tooltipsEnabled {
            content
                .help(text)
                .accessibilityHint(text)
                .onHover { isHovering in
                    if isHovering {
                        ToolbarTooltipController.shared.show(text, near: NSEvent.mouseLocation)
                    } else {
                        ToolbarTooltipController.shared.hide()
                    }
                }
        } else {
            content
                .accessibilityHint(text)
                .onHover { isHovering in
                    if !isHovering {
                        ToolbarTooltipController.shared.hide()
                    }
                }
        }
    }
}

private struct ToolbarTooltipsEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

private extension EnvironmentValues {
    var toolbarTooltipsEnabled: Bool {
        get { self[ToolbarTooltipsEnabledKey.self] }
        set { self[ToolbarTooltipsEnabledKey.self] = newValue }
    }
}

private extension View {
    func toolbarHelp(_ text: String) -> some View {
        modifier(ToolbarTooltipModifier(text: text))
    }
}

extension Color {
    init(_ color: RGBAColor) {
        self.init(
            red: color.red,
            green: color.green,
            blue: color.blue,
            opacity: color.alpha
        )
    }
}

extension RGBAColor {
    init(_ color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            alpha: Double(nsColor.alphaComponent)
        )
    }
}
