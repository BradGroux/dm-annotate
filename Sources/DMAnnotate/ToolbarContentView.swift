import AppKit
import DMAnnotateCore
import SwiftUI

struct ToolbarContentView: View {
    @ObservedObject var store: AnnotationStore
    @ObservedObject var preferences: PreferencesController
    @ObservedObject var runtimeState: AppRuntimeState
    var actions: ToolbarActions
    @State private var permissionSummary = PermissionSummary.current()

    private var compactColumns: [GridItem] {
        [
            GridItem(.fixed(ToolbarLayoutMetrics.buttonSize), spacing: ToolbarLayoutMetrics.gridSpacing),
            GridItem(.fixed(ToolbarLayoutMetrics.buttonSize), spacing: ToolbarLayoutMetrics.gridSpacing)
        ]
    }

    var body: some View {
        Group {
            if preferences.snapshot.toolbarCollapsed {
                collapsedBody
            } else if preferences.snapshot.toolbarCompactMode {
                compactBody
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionSummary()
        }
        .onChange(of: permissionSummary.needsAttention) { _ in
            actions.resizeToolbar()
        }
        .onChange(of: preferences.snapshot.toolbarTooltipsEnabled) { isEnabled in
            if !isEnabled {
                ToolbarTooltipController.shared.hide()
            }
        }
    }

    private var collapsedBody: some View {
        HStack(spacing: ToolbarLayoutMetrics.gridSpacing) {
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
        .frame(width: ToolbarLayoutMetrics.collapsedContentSize.width, height: ToolbarLayoutMetrics.collapsedContentSize.height, alignment: .leading)
    }

    private var verticalBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: ToolbarLayoutMetrics.gridSpacing) {
                dragBar

                verticalTopControls

                sectionDivider

                LazyVGrid(columns: compactColumns, spacing: ToolbarLayoutMetrics.gridSpacing) {
                    toolButtons
                }

                sectionDivider

                ToolbarColorControlsView(store: store, preferences: preferences, columns: compactColumns)
                ToolbarStrokeTextControlsView(store: store, preferences: preferences)

                sectionDivider

                LazyVGrid(columns: compactColumns, spacing: ToolbarLayoutMetrics.gridSpacing) {
                    actionButtons
                }
            }
            .padding(.bottom, ToolbarLayoutMetrics.gridSpacing)
        }
        .frame(width: ToolbarLayoutMetrics.verticalContentWidth)
    }

    private var horizontalBody: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ToolbarLayoutMetrics.gridSpacing) {
                dragBar
                orientationToggle
                collapseToggle
                compactModeToggle
                statusControls
                verticalDivider
                toolButtons
                verticalDivider
                ToolbarColorControlsView(store: store, preferences: preferences)
                ToolbarStrokeTextControlsView(store: store, preferences: preferences)
                verticalDivider
                actionButtons
            }
        }
    }

    private var dragBar: some View {
        ZStack {
            Capsule()
                .fill(dragHandleColor)
                .frame(width: preferences.snapshot.toolbarOrientation == .vertical ? 42 : 8, height: preferences.snapshot.toolbarOrientation == .vertical ? 5 : 28)
            WindowDragHandle()
        }
        .frame(width: preferences.snapshot.toolbarOrientation == .vertical ? 62 : 16, height: preferences.snapshot.toolbarOrientation == .vertical ? 16 : ToolbarLayoutMetrics.buttonSize)
        .contentShape(Rectangle())
        .toolbarHelp("Drag toolbar")
        .accessibilityLabel("Drag toolbar")
    }

    private var compactBody: some View {
        Group {
            if preferences.snapshot.toolbarOrientation == .vertical {
                compactVerticalBody
            } else {
                compactHorizontalBody
            }
        }
    }

    private var compactVerticalBody: some View {
        VStack(spacing: ToolbarLayoutMetrics.gridSpacing) {
            dragBar
            LazyVGrid(columns: compactColumns, spacing: ToolbarLayoutMetrics.gridSpacing) {
                compactControls
            }
        }
        .frame(width: ToolbarLayoutMetrics.verticalContentWidth)
    }

    private var verticalTopControls: some View {
        VStack(spacing: ToolbarLayoutMetrics.gridSpacing) {
            HStack(spacing: ToolbarLayoutMetrics.gridSpacing) {
                orientationToggle
                collapseToggle
            }

            compactModeToggleButton(width: ToolbarLayoutMetrics.wideButtonWidth)

            if permissionSummary.needsAttention {
                LazyVGrid(columns: compactColumns, spacing: ToolbarLayoutMetrics.gridSpacing) {
                    statusControls
                }
            }
        }
    }

    private var compactHorizontalBody: some View {
        HStack(spacing: ToolbarLayoutMetrics.gridSpacing) {
            dragBar
            compactControls
        }
    }

    private var collapsedDragBar: some View {
        ZStack {
            Capsule()
                .fill(collapsedDragHandleColor)
                .frame(width: 10, height: 28)
            WindowDragHandle()
        }
        .frame(width: 14, height: ToolbarLayoutMetrics.buttonSize)
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

    private var compactModeToggle: some View {
        compactModeToggleButton()
    }

    private func compactModeToggleButton(width: CGFloat = ToolbarLayoutMetrics.buttonSize) -> some View {
        Button {
            actions.toggleToolbarCompactMode()
        } label: {
            toolbarIcon(preferences.snapshot.toolbarCompactMode ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                .frame(width: width, height: ToolbarLayoutMetrics.buttonSize)
        }
        .buttonStyle(toolbarButtonStyle(active: preferences.snapshot.toolbarCompactMode))
        .toolbarHelp(tooltip(preferences.snapshot.toolbarCompactMode ? "Expand presenter toolbar" : "Compact presenter toolbar", action: .toggleToolbarCompactMode))
        .accessibilityLabel("Compact presenter toolbar")
    }

    @ViewBuilder private var compactControls: some View {
        compactModeToggle
        statusControls
        compactCursorButton
        compactToolMenu
        compactColorMenu
        compactStrokeStepper
        compactUndoButton
        compactDeleteButton
    }

    private var compactCursorButton: some View {
        Button {
            store.exitScreenControls()
        } label: {
            toolbarIcon("cursorarrow")
        }
        .buttonStyle(toolbarButtonStyle(active: store.activeTool == .cursor && !store.whiteboardModeEnabled))
        .toolbarHelp(tooltip("Cursor mode", action: .cursorMode))
        .accessibilityLabel("Cursor mode")
    }

    private var compactToolMenu: some View {
        Menu {
            ForEach(AnnotationTool.allCases.filter { $0 != .cursor && preferences.snapshot.visibleTools.contains($0) }) { tool in
                Button {
                    store.setActiveTool(tool)
                } label: {
                    Label(tool.displayName, systemImage: tool.systemImageName)
                }
            }
        } label: {
            toolbarIcon(activeToolIcon)
        }
        .buttonStyle(toolbarButtonStyle(active: store.activeTool != .cursor || store.whiteboardModeEnabled))
        .toolbarHelp("Active tool: \(activeToolName)")
        .accessibilityLabel("Active annotation tool")
    }

    private var compactColorMenu: some View {
        Menu {
            ForEach(Array(preferences.snapshot.paletteColors.enumerated()), id: \.offset) { index, color in
                Button {
                    store.setCurrentColor(color)
                } label: {
                    Text("Color \(index + 1)")
                }
            }

            Button {
                ToolbarColorPanelController.shared.show(currentColor: store.currentColor, store: store)
            } label: {
                Label("Custom Color", systemImage: "eyedropper")
            }
        } label: {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(store.currentColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
                .frame(width: ToolbarLayoutMetrics.buttonSize, height: ToolbarLayoutMetrics.buttonSize)
        }
        .buttonStyle(.plain)
        .toolbarHelp(tooltip("Current color", action: .customColor))
        .accessibilityLabel("Current color")
    }

    private var compactStrokeStepper: some View {
        Menu {
            Button("Decrease") {
                store.decreaseStrokeWidth()
            }
            Button("Increase") {
                store.increaseStrokeWidth()
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "lineweight")
                Text("\(Int(store.strokeWidth))")
                    .font(.caption2.weight(.bold))
            }
            .frame(width: ToolbarLayoutMetrics.buttonSize, height: ToolbarLayoutMetrics.buttonSize)
        }
        .buttonStyle(toolbarButtonStyle(active: false))
        .toolbarHelp("Stroke width \(Int(store.strokeWidth)) px")
        .accessibilityLabel("Stroke width")
    }

    private var compactUndoButton: some View {
        Button {
            store.undo()
        } label: {
            toolbarIcon("arrow.uturn.backward")
        }
        .buttonStyle(toolbarButtonStyle(active: false))
        .disabled(!store.canUndo)
        .toolbarHelp(tooltip("Undo", action: .undo))
        .accessibilityLabel("Undo")
    }

    private var compactDeleteButton: some View {
        Button {
            if store.selectedAnnotationID != nil {
                store.deleteSelectedAnnotation()
            } else {
                store.clearAll()
            }
        } label: {
            toolbarIcon(store.selectedAnnotationID == nil ? "trash" : "trash.slash")
        }
        .buttonStyle(toolbarButtonStyle(active: store.selectedAnnotationID != nil))
        .toolbarHelp(store.selectedAnnotationID == nil ? tooltip("Clear all", action: .clearAll) : "Delete selected annotation")
        .accessibilityLabel(store.selectedAnnotationID == nil ? "Clear all" : "Delete selected annotation")
    }

    @ViewBuilder private var toolButtons: some View {
        ToolbarToolSelectionView(store: store, preferences: preferences, runtimeState: runtimeState)
    }

    @ViewBuilder private var actionButtons: some View {
        ToolbarScreenshotActionsView(store: store, preferences: preferences, actions: actions)
    }

    private func toolbarIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 16, weight: .medium))
            .frame(width: ToolbarLayoutMetrics.buttonSize, height: ToolbarLayoutMetrics.buttonSize)
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

    private var toolbarStrokeColor: Color {
        if preferences.snapshot.highContrastToolbar {
            return store.isControllingScreen ? .cyan : .primary.opacity(0.55)
        }
        return store.isControllingScreen ? .cyan : .white.opacity(0.18)
    }

    private var dragHandleColor: Color {
        Color.primary.opacity(preferences.snapshot.highContrastToolbar ? 0.38 : 0.30)
    }

    private var collapsedDragHandleColor: Color {
        Color.primary.opacity(preferences.snapshot.highContrastToolbar ? 0.42 : 0.32)
    }

    private func toolbarButtonStyle(active: Bool) -> ToolbarIconButtonStyle {
        ToolbarIconButtonStyle(active: active, highContrast: preferences.snapshot.highContrastToolbar)
    }

    private func refreshPermissionSummary() {
        permissionSummary = PermissionSummary.current()
    }

    private var activeToolIcon: String {
        if store.whiteboardModeEnabled {
            return store.whiteboardBackground == .black || store.whiteboardBackground == .darkGrid ? AnnotationTool.blackboard.systemImageName : AnnotationTool.whiteboard.systemImageName
        }
        return store.activeTool.systemImageName
    }

    private var activeToolName: String {
        if store.whiteboardModeEnabled {
            return store.whiteboardBackground == .black || store.whiteboardBackground == .darkGrid ? AnnotationTool.blackboard.displayName : AnnotationTool.whiteboard.displayName
        }
        return store.activeTool.displayName
    }
}
