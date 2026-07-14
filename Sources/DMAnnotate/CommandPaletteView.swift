import AppKit
import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var model: CommandPaletteInteractionModel
    var close: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "command")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                CommandPaletteSearchField(model: model, close: close)
                    .frame(height: 24)
            }
            .padding(12)
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )

            commandResults
        }
        .padding(16)
        .frame(width: 520, height: 520)
        .transaction { transaction in
            transaction.animation = nil
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var commandResults: some View {
        if model.filteredCommands.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No matching commands")
                    .font(.headline)
                Text("Try a different command or action name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(CommandPaletteAppKitSeams.emptyStateAccessibilityLabel)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(model.filteredCommands.enumerated()), id: \.element.id) { index, command in
                            commandRow(command, index: index, count: model.filteredCommands.count)
                                .id(command.id)
                        }
                    }
                }
                .onChange(of: model.selectedCommandID) { selectedCommandID in
                    guard let selectedCommandID = CommandPaletteAppKitSeams.scrollTarget(for: selectedCommandID) else { return }
                    proxy.scrollTo(selectedCommandID, anchor: .center)
                }
            }
        }
    }

    private func commandRow(_ command: CommandPaletteCommand, index: Int, count: Int) -> some View {
        let isSelected = command.id == model.selectedCommandID
        return Button {
            model.select(command.id)
            _ = model.performSelected(onDismiss: close)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: command.systemImage)
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                        .font(.body.weight(.semibold))
                    Text(command.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "return")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .padding(10)
        }
        .buttonStyle(.plain)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.16)
                : Color(nsColor: .controlBackgroundColor).opacity(0.6),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 1)
        }
        .accessibilityLabel(command.title)
        .accessibilityValue(
            isSelected
                ? "Selected, result \(index + 1) of \(count). \(command.subtitle)"
                : "Result \(index + 1) of \(count). \(command.subtitle)"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct CommandPaletteSearchField: NSViewRepresentable {
    @ObservedObject var model: CommandPaletteInteractionModel
    var close: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model, close: close)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = "Search commands"
        searchField.delegate = context.coordinator
        searchField.focusRingType = .default
        searchField.setAccessibilityLabel("Search commands")
        searchField.setAccessibilityHelp(model.resultAnnouncement)
        return searchField
    }

    func updateNSView(_ searchField: NSSearchField, context: Context) {
        context.coordinator.model = model
        context.coordinator.close = close
        if searchField.stringValue != model.query {
            searchField.stringValue = model.query
        }
        searchField.setAccessibilityHelp(model.resultAnnouncement)

        context.coordinator.focusCoordinator.request(model.focusRequest, for: searchField)
        DispatchQueue.main.async { [weak searchField] in
            guard searchField != nil else { return }
            context.coordinator.focusCoordinator.attempt()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var model: CommandPaletteInteractionModel
        var close: () -> Void
        let focusCoordinator: CommandPaletteSearchFocusCoordinator
        let announcer: CommandPaletteAccessibilityAnnouncer

        init(
            model: CommandPaletteInteractionModel,
            close: @escaping () -> Void,
            focusCoordinator: CommandPaletteSearchFocusCoordinator = CommandPaletteSearchFocusCoordinator(),
            announcer: CommandPaletteAccessibilityAnnouncer = CommandPaletteAccessibilityAnnouncer()
        ) {
            self.model = model
            self.close = close
            self.focusCoordinator = focusCoordinator
            self.announcer = announcer
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeKey(_:)),
                name: NSWindow.didBecomeKeyNotification,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func windowDidBecomeKey(_ notification: Notification) {
            focusCoordinator.attempt()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else { return }
            model.updateQuery(searchField.stringValue)
            searchField.setAccessibilityHelp(model.resultAnnouncement)
            announce(model.resultAnnouncement, from: searchField)
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            guard let searchField = control as? NSSearchField else { return false }

            guard let command = CommandPaletteAppKitSeams.keyboardCommand(for: commandSelector) else { return false }
            switch command {
            case .movePrevious, .moveNext:
                model.handleKeyboardCommand(command, onDismiss: close)
                announce(model.resultAnnouncement, from: searchField)
                return true
            case .perform:
                if !model.handleKeyboardCommand(.perform, onDismiss: close) {
                    NSSound.beep()
                    announce(model.resultAnnouncement, from: searchField)
                }
                return true
            case .cancel:
                model.handleKeyboardCommand(.cancel, onDismiss: close)
                return true
            }
        }

        private func announce(_ message: String, from searchField: NSSearchField) {
            announcer.announce(message, from: searchField)
        }
    }
}
