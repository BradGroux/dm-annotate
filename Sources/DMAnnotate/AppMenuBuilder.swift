import AppKit
import DMAnnotateCore

private let appDisplayName = "Digital Meld Annotate"
private let appMenuName = "Annotate"

@MainActor
@objc protocol AppMenuActionHandling: AnyObject {
    func showToolbar()
    func findToolbar()
    func toggleToolbarCollapsed()
    func toggleToolbarOrientation()
    func openCommandPalette()
    func toggleAnnotationMode()
    func cursorMode()
    func toggleAnnotationLock()
    func toggleAnnotationVisibility()
    func clearAll()
    func captureScreenshot()
    func copyScreenshot()
    func saveScreenshot()
    func saveAnnotationsScreenshot()
    func captureRegionScreenshot()
    func revealLastScreenshot()
    func showPermissions()
    func showSettings()
    func quit()
    func selectTool(_ sender: NSMenuItem)
    func undo()
    func redo()
    func showAbout()
    func showHelp()
}

@MainActor
struct AppMenuBuilder {
    weak var target: AppMenuActionHandling?
    var shortcuts: [ShortcutAction: String] = ShortcutAction.defaultShortcuts

    func installMainMenu() {
        let mainMenu = NSMenu(title: "Main Menu")

        mainMenu.addItem(menuRoot(appMenuName, submenu: appMenu()))
        mainMenu.addItem(menuRoot("File", submenu: fileMenu()))
        mainMenu.addItem(menuRoot("Edit", submenu: editMenu()))
        mainMenu.addItem(menuRoot("View", submenu: viewMenu()))
        mainMenu.addItem(menuRoot("Tools", submenu: toolsMenu()))
        mainMenu.addItem(menuRoot("Window", submenu: windowMenu()))
        mainMenu.addItem(menuRoot("Help", submenu: helpMenu()))

        NSApp.mainMenu = mainMenu
    }

    func statusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(menuItem("Show Toolbar", action: #selector(AppMenuActionHandling.showToolbar), key: ""))
        menu.addItem(menuItem("Collapse/Expand Toolbar", action: #selector(AppMenuActionHandling.toggleToolbarCollapsed), shortcut: .toggleToolbarCollapsed))
        menu.addItem(menuItem("Switch Horizontal/Vertical", action: #selector(AppMenuActionHandling.toggleToolbarOrientation), shortcut: .toggleToolbarOrientation))
        menu.addItem(menuItem("Find Toolbar", action: #selector(AppMenuActionHandling.findToolbar), shortcut: .findToolbar))
        menu.addItem(.separator())
        menu.addItem(menuItem("Command Palette", action: #selector(AppMenuActionHandling.openCommandPalette), shortcut: .commandPalette))
        menu.addItem(.separator())
        menu.addItem(menuItem("Toggle Annotation Mode", action: #selector(AppMenuActionHandling.toggleAnnotationMode), shortcut: .toggleAnnotationMode))
        menu.addItem(menuItem("Cursor Mode", action: #selector(AppMenuActionHandling.cursorMode), shortcut: .cursorMode))
        menu.addItem(menuItem("Lock/Unlock Annotations", action: #selector(AppMenuActionHandling.toggleAnnotationLock), shortcut: .toggleAnnotationLock))
        menu.addItem(menuItem("Show/Hide Annotations", action: #selector(AppMenuActionHandling.toggleAnnotationVisibility), shortcut: .toggleAnnotationVisibility))
        menu.addItem(menuItem("Clear All", action: #selector(AppMenuActionHandling.clearAll), shortcut: .clearAll))
        menu.addItem(.separator())
        menu.addItem(menuItem("Screenshot", action: #selector(AppMenuActionHandling.captureScreenshot), shortcut: .screenshot))
        menu.addItem(menuItem("Copy Screenshot as PNG", action: #selector(AppMenuActionHandling.copyScreenshot), shortcut: .copyScreenshot))
        menu.addItem(menuItem("Save Screenshot as PNG", action: #selector(AppMenuActionHandling.saveScreenshot), shortcut: .saveScreenshot))
        menu.addItem(menuItem("Save Annotations as PNG", action: #selector(AppMenuActionHandling.saveAnnotationsScreenshot), key: ""))
        menu.addItem(menuItem("Region Screenshot", action: #selector(AppMenuActionHandling.captureRegionScreenshot), shortcut: .regionScreenshot))
        menu.addItem(menuItem("Reveal Last Screenshot", action: #selector(AppMenuActionHandling.revealLastScreenshot), shortcut: .revealLastScreenshot))
        menu.addItem(.separator())
        menu.addItem(menuItem("Permissions...", action: #selector(AppMenuActionHandling.showPermissions), shortcut: .showPermissions))
        menu.addItem(menuItem("Settings...", action: #selector(AppMenuActionHandling.showSettings), shortcut: .showSettings))
        menu.addItem(menuItem("Quit \(appDisplayName)", action: #selector(AppMenuActionHandling.quit), key: "q"))
        return menu
    }

    private func menuRoot(_ title: String, submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.title = title
        item.submenu = submenu
        return item
    }

    private func appMenu() -> NSMenu {
        let menu = NSMenu(title: appMenuName)
        menu.addItem(menuItem("About \(appDisplayName)", action: #selector(AppMenuActionHandling.showAbout), key: ""))
        menu.addItem(.separator())
        menu.addItem(menuItem("Permissions...", action: #selector(AppMenuActionHandling.showPermissions), shortcut: .showPermissions))
        menu.addItem(menuItem("Settings...", action: #selector(AppMenuActionHandling.showSettings), shortcut: .showSettings))
        menu.addItem(.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        menu.addItem(servicesItem)

        menu.addItem(.separator())
        menu.addItem(appTargetItem("Hide \(appDisplayName)", action: #selector(NSApplication.hide(_:)), key: "h"))
        let hideOthersItem = appTargetItem("Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), key: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(hideOthersItem)
        menu.addItem(appTargetItem("Show All", action: #selector(NSApplication.unhideAllApplications(_:)), key: ""))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit \(appDisplayName)", action: #selector(AppMenuActionHandling.quit), key: "q"))
        return menu
    }

    private func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(menuItem("Screenshot", action: #selector(AppMenuActionHandling.captureScreenshot), shortcut: .screenshot))
        menu.addItem(menuItem("Region Screenshot", action: #selector(AppMenuActionHandling.captureRegionScreenshot), shortcut: .regionScreenshot))
        menu.addItem(menuItem("Copy Screenshot as PNG", action: #selector(AppMenuActionHandling.copyScreenshot), shortcut: .copyScreenshot))
        menu.addItem(menuItem("Save Screenshot as PNG", action: #selector(AppMenuActionHandling.saveScreenshot), shortcut: .saveScreenshot))
        menu.addItem(menuItem("Save Annotations as PNG", action: #selector(AppMenuActionHandling.saveAnnotationsScreenshot), key: ""))
        menu.addItem(menuItem("Reveal Last Screenshot", action: #selector(AppMenuActionHandling.revealLastScreenshot), shortcut: .revealLastScreenshot))
        return menu
    }

    private func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(menuItem("Undo", action: #selector(AppMenuActionHandling.undo), key: "z"))
        menu.addItem(menuItem("Redo", action: #selector(AppMenuActionHandling.redo), key: "z", modifiers: [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        return menu
    }

    private func viewMenu() -> NSMenu {
        let menu = NSMenu(title: "View")
        menu.addItem(menuItem("Show Toolbar", action: #selector(AppMenuActionHandling.showToolbar), key: ""))
        menu.addItem(menuItem("Collapse/Expand Toolbar", action: #selector(AppMenuActionHandling.toggleToolbarCollapsed), shortcut: .toggleToolbarCollapsed))
        menu.addItem(menuItem("Switch Horizontal/Vertical", action: #selector(AppMenuActionHandling.toggleToolbarOrientation), shortcut: .toggleToolbarOrientation))
        menu.addItem(menuItem("Find Toolbar", action: #selector(AppMenuActionHandling.findToolbar), shortcut: .findToolbar))
        menu.addItem(.separator())
        menu.addItem(menuItem("Show/Hide Annotations", action: #selector(AppMenuActionHandling.toggleAnnotationVisibility), shortcut: .toggleAnnotationVisibility))
        return menu
    }

    private func toolsMenu() -> NSMenu {
        let menu = NSMenu(title: "Tools")
        menu.addItem(menuItem("Command Palette", action: #selector(AppMenuActionHandling.openCommandPalette), shortcut: .commandPalette))
        menu.addItem(.separator())
        menu.addItem(menuItem("Toggle Annotation Mode", action: #selector(AppMenuActionHandling.toggleAnnotationMode), shortcut: .toggleAnnotationMode))
        menu.addItem(menuItem("Cursor Mode", action: #selector(AppMenuActionHandling.cursorMode), shortcut: .cursorMode))
        menu.addItem(menuItem("Lock/Unlock Annotations", action: #selector(AppMenuActionHandling.toggleAnnotationLock), shortcut: .toggleAnnotationLock))
        menu.addItem(.separator())

        for tool in AnnotationTool.allCases {
            menu.addItem(toolMenuItem(tool))
        }

        menu.addItem(.separator())
        menu.addItem(menuItem("Clear All", action: #selector(AppMenuActionHandling.clearAll), shortcut: .clearAll))
        return menu
    }

    private func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(appTargetItem("Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), key: ""))
        NSApp.windowsMenu = menu
        return menu
    }

    private func helpMenu() -> NSMenu {
        let menu = NSMenu(title: "Help")
        menu.addItem(menuItem("\(appDisplayName) Help", action: #selector(AppMenuActionHandling.showHelp), key: "?"))
        NSApp.helpMenu = menu
        return menu
    }

    private func menuItem(
        _ title: String,
        action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    private func menuItem(_ title: String, action: Selector, shortcut: ShortcutAction) -> NSMenuItem {
        guard let keyEquivalent = keyEquivalent(for: shortcut) else {
            return menuItem(title, action: action, key: "", modifiers: [])
        }

        return menuItem(title, action: action, key: keyEquivalent.key, modifiers: keyEquivalent.modifiers)
    }

    private func appTargetItem(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = NSApp
        return item
    }

    private func toolMenuItem(_ tool: AnnotationTool) -> NSMenuItem {
        let item: NSMenuItem
        if let action = ShortcutAction.toolAction(for: tool),
           let keyEquivalent = keyEquivalent(for: action) {
            item = menuItem(tool.displayName, action: #selector(AppMenuActionHandling.selectTool(_:)), key: keyEquivalent.key, modifiers: keyEquivalent.modifiers)
        } else {
            item = menuItem(tool.displayName, action: #selector(AppMenuActionHandling.selectTool(_:)), key: "", modifiers: [])
        }
        item.representedObject = tool.rawValue
        return item
    }

    private func keyEquivalent(for action: ShortcutAction) -> (key: String, modifiers: NSEvent.ModifierFlags)? {
        guard let normalized = ShortcutResolver.usableShortcut(for: action, in: shortcuts) else { return nil }

        let parts = normalized.split(separator: "+").map(String.init)
        guard let key = parts.last else { return nil }

        var modifiers: NSEvent.ModifierFlags = []
        for modifier in parts.dropLast() {
            switch modifier {
            case "control": modifiers.insert(.control)
            case "option": modifiers.insert(.option)
            case "shift": modifiers.insert(.shift)
            case "command": modifiers.insert(.command)
            default: break
            }
        }

        switch key {
        case "escape":
            return ("\u{1b}", [])
        case "space":
            return (" ", modifiers)
        case "enter":
            return ("\r", modifiers)
        case "delete":
            return ("\u{8}", modifiers)
        default:
            return (key, modifiers)
        }
    }
}
