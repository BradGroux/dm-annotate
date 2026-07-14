import AppKit
import Combine
import DMAnnotateCore
import Foundation

@MainActor
final class PreferencesController: ObservableObject {
    @Published private(set) var snapshot: PreferencesSnapshot

    private let store: AnnotationStore
    private let defaults: UserDefaults
    private let key = "dmAnnotate.preferences.v1"

    init(store: AnnotationStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(PreferencesSnapshot.self, from: data) {
            let migrated = Self.migrated(
                decoded,
                keyCodeForLegacyCharacter: ActiveKeyboardLayout.keyCode
            )
            snapshot = migrated
            if migrated != decoded, let data = try? JSONEncoder().encode(migrated) {
                defaults.set(data, forKey: key)
            }
        } else {
            snapshot = PreferencesSnapshot()
        }
    }

    func update(_ mutate: (inout PreferencesSnapshot) -> Void) {
        let previous = snapshot
        var next = snapshot
        mutate(&next)
        next = Self.migrated(
            next,
            keyCodeForLegacyCharacter: ActiveKeyboardLayout.keyCode
        )
        snapshot = next
        save()
        applySideEffects(previous: previous, next: next)
    }

    func reset() {
        snapshot = PreferencesSnapshot()
        save()
        applyToStore()
    }

    func applyToStore() {
        store.currentColor = snapshot.defaultColor
        store.whiteboardBackground = snapshot.whiteboardBackground
        applyTheme(snapshot.theme)
    }

    private func applySideEffects(previous: PreferencesSnapshot, next: PreferencesSnapshot) {
        if previous.theme != next.theme {
            applyTheme(next.theme)
        }

        if previous.whiteboardBackground != next.whiteboardBackground {
            store.whiteboardBackground = next.whiteboardBackground
        }

        if previous.defaultColor != next.defaultColor {
            store.currentColor = next.defaultColor
        }
    }

    private func applyTheme(_ theme: AppTheme) {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        }
    }

    func expandedScreenshotFolderURL() -> URL {
        let expanded = NSString(string: snapshot.screenshotFolder).expandingTildeInPath
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }

    func duplicateShortcuts() -> Set<String> {
        ShortcutResolver.duplicateDescriptors(in: snapshot.shortcuts)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    private static func migrated(
        _ snapshot: PreferencesSnapshot,
        keyCodeForLegacyCharacter: (String, ShortcutModifiers) -> Int64?
    ) -> PreferencesSnapshot {
        var migrated = snapshot

        migrated.migrateLegacyShortcuts(keyCodeForCharacter: keyCodeForLegacyCharacter)
        migrated.shortcuts = PreferencesSnapshot.normalizedShortcuts(migrated.shortcuts)

        migrated.paletteColors = PreferencesSnapshot.normalizedPaletteColors(migrated.paletteColors)
        migrated.quickColors = Array(migrated.paletteColors.prefix(4))
        migrated.visibleTools = PreferencesSnapshot.normalizedVisibleTools(migrated.visibleTools)

        return migrated
    }
}
