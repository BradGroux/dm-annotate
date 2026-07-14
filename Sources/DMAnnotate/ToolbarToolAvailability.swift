import DMAnnotateCore

enum ToolbarToolAvailability {
    private static let safeModeHelp = "Annotation tools are disabled in Safe Mode. Quit and reopen normally to draw."

    static func canSelectAnnotationTools(isSafeMode: Bool) -> Bool {
        !isSafeMode
    }

    static func isEnabled(_ tool: AnnotationTool, isSafeMode: Bool) -> Bool {
        tool == .cursor || canSelectAnnotationTools(isSafeMode: isSafeMode)
    }

    static func helpText(
        for tool: AnnotationTool,
        isSafeMode: Bool,
        availableHelp: String
    ) -> String {
        guard !isEnabled(tool, isSafeMode: isSafeMode) else { return availableHelp }
        return safeModeHelp
    }

    static func annotationToolHelpText(isSafeMode: Bool, availableHelp: String) -> String {
        canSelectAnnotationTools(isSafeMode: isSafeMode) ? availableHelp : safeModeHelp
    }
}
