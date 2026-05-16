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

                LazyVGrid(columns: compactColumns, spacing: ToolbarLayoutMetrics.gridSpacing) {
                    orientationToggle
                    collapseToggle
                    statusControls
                }

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
}
