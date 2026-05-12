import AppKit

enum DMWindowLevels {
    private static let screenSaverBase = Int(CGWindowLevelForKey(.screenSaverWindow))

    static let annotationOverlay = NSWindow.Level(rawValue: screenSaverBase)
    static let toolbar = NSWindow.Level(rawValue: screenSaverBase + 1)
    static let toolbarTooltip = NSWindow.Level(rawValue: screenSaverBase + 2)
    static let regionSelection = NSWindow.Level(rawValue: screenSaverBase + 3)
}
