import DMAnnotateCore
import Testing
@testable import DMAnnotate

@Test func safeModeKeepsCursorAvailableAndDisablesEveryAnnotationTool() {
    #expect(ToolbarToolAvailability.isEnabled(.cursor, isSafeMode: true))
    #expect(!ToolbarToolAvailability.canSelectAnnotationTools(isSafeMode: true))

    for tool in AnnotationTool.allCases where tool != .cursor {
        #expect(!ToolbarToolAvailability.isEnabled(tool, isSafeMode: true))
    }
}

@Test func normalModeEnablesEveryToolbarTool() {
    #expect(ToolbarToolAvailability.canSelectAnnotationTools(isSafeMode: false))
    for tool in AnnotationTool.allCases {
        #expect(ToolbarToolAvailability.isEnabled(tool, isSafeMode: false))
    }
}

@Test func safeModeHelpExplainsHowToRestoreAnnotationTools() {
    let normalHelp = "Pen (Control+Option+P)"

    #expect(
        ToolbarToolAvailability.helpText(
            for: .pen,
            isSafeMode: true,
            availableHelp: normalHelp
        ) == "Annotation tools are disabled in Safe Mode. Quit and reopen normally to draw."
    )
    #expect(
        ToolbarToolAvailability.helpText(
            for: .cursor,
            isSafeMode: true,
            availableHelp: "Cursor mode"
        ) == "Cursor mode"
    )
    #expect(
        ToolbarToolAvailability.helpText(
            for: .pen,
            isSafeMode: false,
            availableHelp: normalHelp
        ) == normalHelp
    )
    #expect(
        ToolbarToolAvailability.annotationToolHelpText(
            isSafeMode: true,
            availableHelp: "Active tool: Cursor"
        ) == "Annotation tools are disabled in Safe Mode. Quit and reopen normally to draw."
    )
}

@MainActor
@Test func safeModeFullToolbarToolUsesAnExplicitDisabledVisualState() {
    let state = ToolbarIconButtonStyle.visualState(
        active: false,
        highContrast: false,
        isEnabled: false,
        isPressed: false
    )

    #expect(state.foregroundToken == .primary)
    #expect(state.fillToken == .white)
    #expect(state.fillOpacity == 0.035)
    #expect(state.contentOpacity == 0.55)
}

@MainActor
@Test func safeModeCompactToolbarMenuSuppressesActiveAndPressedTreatments() {
    let state = ToolbarIconButtonStyle.visualState(
        active: true,
        highContrast: true,
        isEnabled: false,
        isPressed: true
    )

    #expect(state.foregroundToken == .primary)
    #expect(state.fillToken == .primary)
    #expect(state.fillOpacity == 0.08)
    #expect(state.contentOpacity == 0.55)
}

@MainActor
@Test func enabledToolbarButtonVisualStatesRetainUnselectedAndPressedTreatments() {
    let active = ToolbarIconButtonStyle.visualState(
        active: true,
        highContrast: false,
        isEnabled: true,
        isPressed: false
    )
    let pressed = ToolbarIconButtonStyle.visualState(
        active: false,
        highContrast: false,
        isEnabled: true,
        isPressed: true
    )
    let selectedPressedScale = AdaptiveSelectedControlStyle.selectedScale(
        selectedIsVisible: true,
        isEnabled: true,
        isPressed: true
    )

    #expect(active.foregroundToken == .primary)
    #expect(active.fillToken == .white)
    #expect(active.fillOpacity == 0.07)
    #expect(active.contentOpacity == 1)
    #expect(pressed.foregroundToken == .primary)
    #expect(pressed.fillToken == .white)
    #expect(pressed.fillOpacity == 0.14)
    #expect(pressed.contentOpacity == 1)
    #expect(selectedPressedScale == 0.94)
}
