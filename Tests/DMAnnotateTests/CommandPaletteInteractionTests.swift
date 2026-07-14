import Foundation
import AppKit
import Testing
@testable import DMAnnotate

@MainActor
private func paletteCommand(
    id: UUID,
    title: String,
    subtitle: String = "Action",
    action: @escaping @MainActor () -> Void = {}
) -> CommandPaletteCommand {
    CommandPaletteCommand(
        id: id,
        title: title,
        subtitle: subtitle,
        systemImage: "command",
        action: action
    )
}

@MainActor
@Test func commandPaletteStartsWithSearchReadyAndFirstResultSelected() {
    let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let model = CommandPaletteInteractionModel(commands: [
        paletteCommand(id: firstID, title: "Cursor Mode"),
        paletteCommand(id: UUID(), title: "Clear All")
    ])

    #expect(model.query.isEmpty)
    #expect(model.selectedCommandID == firstID)
    #expect(model.resultAnnouncement == "2 commands. Cursor Mode selected, result 1 of 2.")
}

@MainActor
@Test func commandPaletteFilteringKeepsAValidSelectionAndExplainsEmptyResults() {
    let cursorID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let clearID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let model = CommandPaletteInteractionModel(commands: [
        paletteCommand(id: cursorID, title: "Cursor Mode", subtitle: "Pass clicks through"),
        paletteCommand(id: clearID, title: "Clear All", subtitle: "Remove annotations")
    ])

    model.moveSelection(.next)
    model.updateQuery("clear")
    #expect(model.filteredCommands.map(\.id) == [clearID])
    #expect(model.selectedCommandID == clearID)
    #expect(model.resultAnnouncement == "1 command. Clear All selected, result 1 of 1.")

    model.updateQuery("no match")
    #expect(model.filteredCommands.isEmpty)
    #expect(model.selectedCommandID == nil)
    #expect(model.resultAnnouncement == "No matching commands.")
}

@MainActor
@Test func commandPaletteArrowNavigationClampsAndReturnDismissesBeforeAction() {
    let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    var events: [String] = []
    let model = CommandPaletteInteractionModel(commands: [
        paletteCommand(id: firstID, title: "Cursor Mode"),
        paletteCommand(id: secondID, title: "Clear All") { events.append("action") }
    ])

    model.moveSelection(.previous)
    #expect(model.selectedCommandID == firstID)
    model.moveSelection(.next)
    model.moveSelection(.next)
    #expect(model.selectedCommandID == secondID)

    #expect(model.performSelected(onDismiss: { events.append("dismiss") }))
    #expect(events == ["dismiss", "action"])
}

@MainActor
@Test func commandPaletteCannotExecuteAnEmptyResultSet() {
    var performed = false
    let model = CommandPaletteInteractionModel(commands: [
        paletteCommand(id: UUID(), title: "Cursor Mode") { performed = true }
    ])

    model.updateQuery("missing")

    #expect(!model.performSelected(onDismiss: {}))
    #expect(!performed)
}

@MainActor
@Test func commandPaletteCancelDismissesWithoutPerformingAndReopenResetsSearch() {
    let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    var events: [String] = []
    let model = CommandPaletteInteractionModel(commands: [
        paletteCommand(id: firstID, title: "Cursor Mode") { events.append("action") }
    ])

    model.updateQuery("cursor")
    #expect(model.handleKeyboardCommand(.cancel, onDismiss: { events.append("dismiss") }))
    #expect(events == ["dismiss"])

    let previousFocusRequest = model.focusRequest
    model.replaceCommands([paletteCommand(id: firstID, title: "Cursor Mode")])
    model.requestSearchFocus()
    #expect(model.query.isEmpty)
    #expect(model.selectedCommandID == firstID)
    #expect(model.focusRequest == previousFocusRequest + 1)
}

@MainActor
@Test func appKitFocusRequestRemainsPendingUntilFirstResponderAcquisitionSucceeds() {
    let searchField = NSSearchField()
    var canFocus = false
    var attempts = 0
    let coordinator = CommandPaletteSearchFocusCoordinator { candidate in
        #expect(candidate === searchField)
        attempts += 1
        return canFocus
    }

    coordinator.request(7, for: searchField)
    #expect(!coordinator.attempt())
    #expect(coordinator.fulfilledRequest == -1)

    canFocus = true
    #expect(coordinator.attempt())
    #expect(coordinator.fulfilledRequest == 7)
    #expect(attempts == 2)
}

@MainActor
@Test func appKitKeyboardSelectorsRouteToPaletteCommands() {
    #expect(CommandPaletteAppKitSeams.keyboardCommand(for: #selector(NSResponder.moveUp(_:))) == .movePrevious)
    #expect(CommandPaletteAppKitSeams.keyboardCommand(for: #selector(NSResponder.moveDown(_:))) == .moveNext)
    #expect(CommandPaletteAppKitSeams.keyboardCommand(for: #selector(NSResponder.insertNewline(_:))) == .perform)
    #expect(CommandPaletteAppKitSeams.keyboardCommand(for: #selector(NSResponder.cancelOperation(_:))) == .cancel)
    #expect(CommandPaletteAppKitSeams.keyboardCommand(for: #selector(NSResponder.deleteBackward(_:))) == nil)
}

@MainActor
@Test func appKitAccessibilityAnnouncementAndEmptyStateAreDeterministic() {
    let searchField = NSSearchField()
    var postedMessage: String?
    let announcer = CommandPaletteAccessibilityAnnouncer { candidate, message in
        #expect(candidate === searchField)
        postedMessage = message
    }

    announcer.announce("2 commands. Cursor Mode selected, result 1 of 2.", from: searchField)

    #expect(postedMessage == "2 commands. Cursor Mode selected, result 1 of 2.")
    #expect(CommandPaletteAppKitSeams.emptyStateAccessibilityLabel == "No matching commands. Try a different command or action name.")
}

@Test func appKitSelectionScrollingAndFocusRestorationChooseTheExpectedTargets() {
    let selectedID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    #expect(CommandPaletteAppKitSeams.scrollTarget(for: selectedID) == selectedID)
    #expect(CommandPaletteAppKitSeams.scrollTarget(for: nil) == nil)
    #expect(CommandPaletteAppKitSeams.restorationDestination(previousWindowVisible: true, previousApplicationAvailable: true) == .window)
    #expect(CommandPaletteAppKitSeams.restorationDestination(previousWindowVisible: false, previousApplicationAvailable: true) == .application)
    #expect(CommandPaletteAppKitSeams.restorationDestination(previousWindowVisible: false, previousApplicationAvailable: false) == .none)
}
