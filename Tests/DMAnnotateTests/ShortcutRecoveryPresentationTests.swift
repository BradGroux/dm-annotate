import Testing
@testable import DMAnnotate

@Test func shortcutRecoveryPresentationDescribesRestartWithoutClaimingATest() {
    #expect(ShortcutRecoveryPresentation.actionLabel == "Restart Shortcut Monitoring")
    #expect(ShortcutRecoveryPresentation.actionHelp(isSafeMode: false).contains("Restart local and global shortcut monitors"))
    #expect(!ShortcutRecoveryPresentation.actionLabel.localizedCaseInsensitiveContains("test"))
    #expect(!ShortcutRecoveryPresentation.actionHelp(isSafeMode: false).localizedCaseInsensitiveContains("success"))
    #expect(ShortcutRecoveryPresentation.isEnabled(isSafeMode: false))
    #expect(!ShortcutRecoveryPresentation.isEnabled(isSafeMode: true))
    #expect(ShortcutRecoveryPresentation.actionHelp(isSafeMode: true) == "Shortcuts are disabled in Safe Mode.")
}
