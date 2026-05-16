import AppKit
import DMAnnotateCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AnnotationStore
    @ObservedObject var preferences: PreferencesController
    var shortcutController: ShortcutController
    @ObservedObject var runtimeState: AppRuntimeState

    @State private var selectedSection: SettingsSection = .general

    init(
        store: AnnotationStore,
        preferences: PreferencesController,
        shortcutController: ShortcutController,
        runtimeState: AppRuntimeState,
        initialSection: SettingsSection = .general
    ) {
        self.store = store
        self.preferences = preferences
        self.shortcutController = shortcutController
        self.runtimeState = runtimeState
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            contentPane
        }
        .frame(minWidth: 900, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

            ForEach(SettingsSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedSection == section ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selectedSection == section ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(12)
        .frame(width: 190)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    private var contentPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedSection.title)
                        .font(.system(size: 28, weight: .semibold))
                    Text(selectedSection.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                selectedContent
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 30)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var selectedContent: some View {
        switch selectedSection {
        case .general:
            SettingsGeneralSectionView(store: store, preferences: preferences)
        case .tools:
            SettingsToolsSectionView(preferences: preferences)
        case .colors:
            SettingsColorsSectionView(store: store, preferences: preferences)
        case .shortcuts:
            SettingsShortcutsSectionView(preferences: preferences, shortcutController: shortcutController)
        case .community:
            SettingsCommunitySectionView()
        case .help:
            SettingsHelpSectionView(preferences: preferences, selectedSection: $selectedSection)
        case .privacy:
            SettingsPrivacySectionView()
        case .diagnostics:
            SettingsDiagnosticsSectionView(
                preferences: preferences,
                shortcutController: shortcutController,
                runtimeState: runtimeState
            )
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case tools
    case colors
    case shortcuts
    case community
    case help
    case privacy
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .tools: "Tools"
        case .colors: "Colors"
        case .shortcuts: "Shortcuts"
        case .community: "Community"
        case .help: "Help"
        case .privacy: "Privacy"
        case .diagnostics: "Diagnostics"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "Core behavior, screenshots, and whiteboard defaults."
        case .tools: "Choose which annotation tools appear in the toolbar."
        case .colors: "Manage the default color, toolbar palette, and saved palettes."
        case .shortcuts: "Customize or disable keyboard shortcuts."
        case .community: "Connect with SSTB.ai, the podcast, and the Discord community."
        case .help: "Find tooltip, shortcut, permission, and version details."
        case .privacy: "Review local-only behavior and macOS permissions."
        case .diagnostics: "Inspect runtime state and recover local integrations."
        }
    }

    var systemImage: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .tools: "pencil.and.outline"
        case .colors: "paintpalette"
        case .shortcuts: "keyboard"
        case .community: "person.3"
        case .help: "questionmark.circle"
        case .privacy: "lock.shield"
        case .diagnostics: "stethoscope"
        }
    }
}
