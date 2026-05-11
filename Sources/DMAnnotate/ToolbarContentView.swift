import AppKit
import DMAnnotateCore
import SwiftUI

struct ToolbarContentView: View {
    @ObservedObject var store: AnnotationStore
    @ObservedObject var preferences: PreferencesController
    @ObservedObject var runtimeState: AppRuntimeState
    var actions: ToolbarActions
    @State private var permissionSummary = PermissionSummary.current()

    private let buttonSize: CGFloat = 30
    private let gridSpacing: CGFloat = 6

    private var compactColumns: [GridItem] {
        [
            GridItem(.fixed(buttonSize), spacing: gridSpacing),
            GridItem(.fixed(buttonSize), spacing: gridSpacing)
        ]
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
        .onAppear(perform: refreshPermissionSummary)
    }

    private var collapsedBody: some View {
        HStack(spacing: gridSpacing) {
            collapsedDragBar
            Button {
                preferences.update { $0.toolbarCollapsed = false }
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
        if let label = runtimeState.modeLabel {
            Button {
                actions.showSettings()
            } label: {
                toolbarIcon(runtimeState.isSafeMode ? "lifepreserver" : "arrow.counterclockwise.circle")
            }
            .buttonStyle(toolbarButtonStyle(active: true))
            .toolbarHelp(tooltip(label, action: .showSettings))
            .accessibilityLabel(label)
        }

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
            preferences.update { snapshot in
                snapshot.toolbarOrientation = snapshot.toolbarOrientation == .vertical ? .horizontal : .vertical
            }
        } label: {
            toolbarIcon(preferences.snapshot.toolbarOrientation == .vertical ? "arrow.left.and.right" : "arrow.up.and.down")
        }
        .buttonStyle(toolbarButtonStyle(active: false))
        .toolbarHelp(tooltip(preferences.snapshot.toolbarOrientation == .vertical ? "Switch to horizontal toolbar" : "Switch to vertical toolbar", action: .toggleToolbarOrientation))
        .accessibilityLabel("Switch toolbar orientation")
    }

    private var collapseToggle: some View {
        Button {
            preferences.update { $0.toolbarCollapsed.toggle() }
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
        ForEach(Array(preferences.snapshot.quickColors.enumerated()), id: \.offset) { index, color in
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

        Menu {
            ForEach(Array(RGBAColor.palette.enumerated()), id: \.offset) { _, color in
                Button {
                    store.currentColor = color
                } label: {
                    Label("Color", systemImage: "circle.fill")
                        .foregroundStyle(Color(color))
                }
            }
        } label: {
            toolbarIcon("paintpalette")
        }
        .menuStyle(.borderlessButton)
        .toolbarHelp("Color palette")
        .accessibilityLabel("Color palette")
    }

    private var customColorButton: some View {
        Button {
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
        Menu {
            ForEach([CGFloat(1), CGFloat(3), CGFloat(5), CGFloat(10)], id: \.self) { width in
                Button("\(Int(width)) px") {
                    store.strokeWidth = width
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "lineweight")
                Text("\(Int(store.strokeWidth))")
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .frame(width: 66, height: buttonSize)
        }
        .menuStyle(.borderlessButton)
        .toolbarHelp("Stroke width (decrease: \(shortcutText(for: .decreaseStrokeWidth)), increase: \(shortcutText(for: .increaseStrokeWidth)))")
        .accessibilityLabel("Stroke width")
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
        iconButton("command", active: false, help: "Command palette", shortcut: .commandPalette) {
            actions.openCommandPalette()
        }
        iconButton("gearshape", active: false, help: "Settings", shortcut: .showSettings) {
            actions.showSettings()
        }
    }

    private var screenshotMenu: some View {
        Menu {
            Button(menuTitle("Use Default Destination", action: .screenshot)) {
                actions.screenshot()
            }
            Button(menuTitle("Copy PNG", action: .copyScreenshot)) {
                actions.copyScreenshot()
            }
            Button(menuTitle("Save PNG", action: .saveScreenshot)) {
                actions.saveScreenshot()
            }
            Button(menuTitle("Reveal Last Screenshot", action: .revealLastScreenshot)) {
                actions.revealLastScreenshot()
            }
        } label: {
            toolbarIcon("camera")
        }
        .menuStyle(.borderlessButton)
        .toolbarHelp(tooltip("Screenshot options", action: .screenshot))
        .accessibilityLabel("Screenshot options")
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
            .font(.system(size: 16, weight: .medium))
            .frame(width: buttonSize, height: buttonSize)
    }

    private func isActive(_ tool: AnnotationTool) -> Bool {
        if tool == .whiteboard {
            return store.whiteboardModeEnabled
        }
        return store.activeTool == tool
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

    private func menuTitle(_ label: String, action: ShortcutAction) -> String {
        "\(label)    \(shortcutText(for: action))"
    }

    private func shortcutText(for action: ShortcutAction) -> String {
        ShortcutDescriptor.display(preferences.snapshot.shortcuts[action] ?? "")
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
            .foregroundStyle(active ? Color.black : Color.primary)
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

private extension View {
    func toolbarHelp(_ text: String) -> some View {
        help(text)
            .accessibilityHint(text)
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
