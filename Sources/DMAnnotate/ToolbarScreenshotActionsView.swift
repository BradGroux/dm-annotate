import DMAnnotateCore
import SwiftUI

struct ToolbarScreenshotActionsView: View {
    @ObservedObject var store: AnnotationStore
    @ObservedObject var preferences: PreferencesController
    var actions: ToolbarActions
    @State private var isScreenshotPopoverPresented = false

    var body: some View {
        iconButton("arrow.uturn.backward", active: false, enabled: store.canUndo, help: "Undo", shortcut: .undo) {
            store.undo()
        }
        iconButton("arrow.uturn.forward", active: false, enabled: store.canRedo, help: "Redo", shortcut: .redo) {
            store.redo()
        }
        iconButton(store.annotationsLocked ? "lock.fill" : "lock.open", active: store.annotationsLocked, help: store.annotationsLocked ? "Unlock annotations" : "Lock annotations", shortcut: .toggleAnnotationLock) {
            actions.toggleAnnotationLock()
        }
        iconButton(store.isVisible ? "eye" : "eye.slash", active: false, help: "Show or hide annotations", shortcut: .toggleAnnotationVisibility) {
            store.toggleVisibility()
        }
        if store.selectedAnnotationID != nil {
            iconButton("trash.slash", active: true, help: "Delete selected annotation") {
                store.deleteSelectedAnnotation()
            }
        }
        screenshotMenu
        iconButton("crop", active: false, help: "Region screenshot", shortcut: .regionScreenshot) {
            actions.regionScreenshot()
        }
        iconButton("trash", active: false, help: "Clear all", shortcut: .clearAll) {
            store.clearAll()
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
            ToolbarIcon("camera.viewfinder")
        }
        .buttonStyle(ToolbarIconButtonStyle(active: isScreenshotPopoverPresented, highContrast: preferences.snapshot.highContrastToolbar))
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
            screenshotOption("Save Annotations PNG", systemImage: "square.on.square.dashed", action: nil) {
                actions.saveAnnotationsScreenshot()
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
        action shortcut: ShortcutAction?,
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
                if let shortcut {
                    Text(shortcutText(for: shortcut))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
            ToolbarIcon(systemName)
        }
        .buttonStyle(ToolbarIconButtonStyle(active: active, highContrast: preferences.snapshot.highContrastToolbar))
        .disabled(!enabled)
        .toolbarHelp(tooltip(help, action: shortcut))
        .accessibilityLabel(help)
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
}
