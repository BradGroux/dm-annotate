import AppKit
import SwiftUI

@MainActor
final class CommandPaletteController {
    private var panel: NSPanel?

    func show(commands: [CommandPaletteCommand]) {
        if panel == nil {
            makePanel(commands: commands)
        } else if let hostingView = panel?.contentView as? NSHostingView<CommandPaletteView> {
            hostingView.rootView = CommandPaletteView(commands: commands) { [weak self] in
                self?.panel?.close()
            }
        }

        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makePanel(commands: [CommandPaletteCommand]) {
        let view = CommandPaletteView(commands: commands) { [weak self] in
            self?.panel?.close()
        }
        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        panel.title = "Digital Meld Annotate Commands"
        panel.contentView = NSHostingView(rootView: view)
        panel.isReleasedWhenClosed = false
        self.panel = panel
    }
}

struct CommandPaletteCommand: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var systemImage: String
    var action: @MainActor () -> Void
}

private struct CommandPaletteView: View {
    let commands: [CommandPaletteCommand]
    var close: () -> Void
    @State private var query = ""

    private var filteredCommands: [CommandPaletteCommand] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return commands }
        return commands.filter {
            $0.title.lowercased().contains(trimmed) ||
                $0.subtitle.lowercased().contains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "command")
                    .foregroundStyle(.secondary)
                TextField("Search commands", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredCommands) { command in
                        Button {
                            close()
                            command.action()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: command.systemImage)
                                    .frame(width: 22)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(command.title)
                                        .font(.body.weight(.semibold))
                                    Text(command.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(10)
                        }
                        .buttonStyle(.plain)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityLabel(command.title)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 520, height: 520)
    }
}
