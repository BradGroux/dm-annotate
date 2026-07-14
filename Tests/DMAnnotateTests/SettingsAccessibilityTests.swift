import AppKit
import Testing
@testable import DMAnnotate

@Test func shortcutRecorderAccessibilityDescribesAssignedShortcut() {
    let state = ShortcutRecorderAccessibilityState(
        actionName: "Toggle Annotation Mode",
        shortcut: "option+command+a",
        isRecording: false,
        isDuplicate: false,
        rejectionFeedback: nil
    )

    #expect(state.label == "Toggle Annotation Mode shortcut")
    #expect(state.value == "Option+Command+A")
    #expect(state.help == "Press to record a new shortcut. Press Delete while recording to clear it.")
}

@Test func shortcutRecorderAccessibilityAnnouncesConflictOwnership() {
    let state = ShortcutRecorderAccessibilityState(
        actionName: "Command Palette",
        shortcut: "command+k",
        isRecording: false,
        isDuplicate: true,
        rejectionFeedback: nil
    )

    #expect(state.value == "Command+K. Conflict: also assigned to another action.")
    #expect(state.help == "Press to record a different shortcut. Press Delete while recording to clear it.")
}

@Test func shortcutRecorderAccessibilityAnnouncesRecordingInstructions() {
    let state = ShortcutRecorderAccessibilityState(
        actionName: "Command Palette",
        shortcut: "command+k",
        isRecording: true,
        isDuplicate: false,
        rejectionFeedback: nil
    )

    #expect(state.value == "Recording. Press a shortcut now.")
    #expect(state.help == "Press Delete to clear the shortcut, or Escape to cancel recording.")
}

@Test func shortcutRecorderAccessibilityAnnouncesRejectedAndUnassignedStates() {
    let rejected = ShortcutRecorderAccessibilityState(
        actionName: "Command Palette",
        shortcut: "command+k",
        isRecording: true,
        isDuplicate: false,
        rejectionFeedback: "Function keys cannot be assigned."
    )
    let unassigned = ShortcutRecorderAccessibilityState(
        actionName: "Command Palette",
        shortcut: "",
        isRecording: false,
        isDuplicate: false,
        rejectionFeedback: nil
    )

    #expect(rejected.value == "Function keys cannot be assigned. Recording continues.")
    #expect(unassigned.value == "Not assigned")
}

@MainActor
@Test func recordingShortcutFieldExposesAnActionableAccessibilityInterface() {
    let field = RecordingShortcutField()
    field.actionName = "Command Palette"
    field.actionIdentifier = "commandPalette"
    field.shortcut = "command+k"

    #expect(field.accessibilityRole() == .button)
    #expect(field.accessibilityLabel() == "Command Palette shortcut")
    #expect(field.accessibilityValue() == "Command+K")
    #expect(field.accessibilityHelp() == "Press to record a new shortcut. Press Delete while recording to clear it.")
    #expect(field.accessibilityIdentifier() == "settings.shortcut.commandPalette")

    field.isDuplicate = true
    #expect(field.accessibilityValue() == "Command+K. Conflict: also assigned to another action.")
}

@MainActor
@Test func recorderFocusDoesNotStartRecordingUntilTheControlIsActivated() {
    let field = RecordingShortcutField()
    field.actionName = "Command Palette"
    field.shortcut = "command+k"

    #expect(field.becomeFirstResponder())
    #expect(field.accessibilityValue() == "Command+K")

    #expect(field.accessibilityPerformPress())
    #expect(field.accessibilityValue() == "Recording. Press a shortcut now.")
}

@Test func settingsSidebarAccessibilityIdentifiesSelection() {
    let selected = SettingsSidebarAccessibilityState(sectionTitle: "Shortcuts", isSelected: true)
    let unselected = SettingsSidebarAccessibilityState(sectionTitle: "General", isSelected: false)

    #expect(selected.label == "Shortcuts settings")
    #expect(selected.value == "Selected")
    #expect(unselected.label == "General settings")
    #expect(unselected.value == "Not selected")
}

@MainActor
@Test func recorderKeyboardActivationStartsRecordingWithoutPointerInput() throws {
    let field = RecordingShortcutField()
    field.actionName = "Command Palette"
    field.shortcut = "command+k"
    let space = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: 49
        )
    )

    field.keyDown(with: space)

    #expect(field.accessibilityValue() == "Recording. Press a shortcut now.")
}

@MainActor
@Test func recorderAccessibilityAnnouncesRejectedInputWhileRecordingContinues() throws {
    let field = RecordingShortcutField()
    field.actionName = "Command Palette"
    field.shortcut = "command+k"
    let unmodifiedA = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        )
    )

    #expect(field.accessibilityPerformPress())
    field.keyDown(with: unmodifiedA)

    #expect(field.accessibilityValue() == "Use modifier... Recording continues.")
    #expect(field.accessibilityHelp() == "Press Delete to clear the shortcut, or Escape to cancel recording.")
}

@MainActor
@Test func recorderDeleteClearsTheOwnedShortcutAndAnnouncesUnassigned() throws {
    let field = RecordingShortcutField()
    field.actionName = "Command Palette"
    field.shortcut = "command+k"
    var changedShortcut: String?
    field.onChange = { changedShortcut = $0 }
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 240, height: 40),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.contentView = field
    let delete = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "\u{7f}",
            charactersIgnoringModifiers: "\u{7f}",
            isARepeat: false,
            keyCode: 51
        )
    )

    #expect(field.accessibilityPerformPress())
    field.keyDown(with: delete)

    #expect(changedShortcut == "")
    #expect(field.accessibilityValue() == "Not assigned")
}
