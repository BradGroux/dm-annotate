import Combine
import Foundation

struct CommandPaletteCommand: Identifiable {
    let id: UUID
    var title: String
    var subtitle: String
    var systemImage: String
    var action: @MainActor () -> Void

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping @MainActor () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.action = action
    }
}

enum CommandPaletteSelectionMovement {
    case previous
    case next
}

enum CommandPaletteKeyboardCommand {
    case movePrevious
    case moveNext
    case perform
    case cancel
}

@MainActor
final class CommandPaletteInteractionModel: ObservableObject {
    @Published private(set) var query = ""
    @Published private(set) var selectedCommandID: CommandPaletteCommand.ID?
    @Published private(set) var focusRequest = 0
    @Published private(set) var commands: [CommandPaletteCommand]

    init(commands: [CommandPaletteCommand]) {
        self.commands = commands
        selectedCommandID = commands.first?.id
    }

    var filteredCommands: [CommandPaletteCommand] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return commands }
        return commands.filter {
            $0.title.lowercased().contains(trimmed) ||
                $0.subtitle.lowercased().contains(trimmed)
        }
    }

    var resultAnnouncement: String {
        let results = filteredCommands
        guard !results.isEmpty else { return "No matching commands." }
        guard let selectedCommandID,
              let selectedIndex = results.firstIndex(where: { $0.id == selectedCommandID }) else {
            return results.count == 1 ? "1 command." : "\(results.count) commands."
        }
        let count = results.count
        let countDescription = count == 1 ? "1 command." : "\(count) commands."
        return "\(countDescription) \(results[selectedIndex].title) selected, result \(selectedIndex + 1) of \(count)."
    }

    func replaceCommands(_ commands: [CommandPaletteCommand]) {
        self.commands = commands
        query = ""
        selectedCommandID = commands.first?.id
    }

    func requestSearchFocus() {
        focusRequest &+= 1
    }

    func updateQuery(_ query: String) {
        self.query = query
        reconcileSelection()
    }

    func select(_ commandID: CommandPaletteCommand.ID) {
        guard filteredCommands.contains(where: { $0.id == commandID }) else { return }
        selectedCommandID = commandID
    }

    func moveSelection(_ movement: CommandPaletteSelectionMovement) {
        let results = filteredCommands
        guard !results.isEmpty else {
            selectedCommandID = nil
            return
        }

        let currentIndex = selectedCommandID.flatMap { selectedID in
            results.firstIndex(where: { $0.id == selectedID })
        } ?? 0
        let nextIndex: Int
        switch movement {
        case .previous:
            nextIndex = max(results.startIndex, currentIndex - 1)
        case .next:
            nextIndex = min(results.index(before: results.endIndex), currentIndex + 1)
        }
        selectedCommandID = results[nextIndex].id
    }

    @discardableResult
    func performSelected(onDismiss: () -> Void) -> Bool {
        guard let selectedCommandID,
              let command = filteredCommands.first(where: { $0.id == selectedCommandID }) else {
            return false
        }
        onDismiss()
        command.action()
        return true
    }

    @discardableResult
    func handleKeyboardCommand(_ command: CommandPaletteKeyboardCommand, onDismiss: () -> Void) -> Bool {
        switch command {
        case .movePrevious:
            moveSelection(.previous)
            return true
        case .moveNext:
            moveSelection(.next)
            return true
        case .perform:
            return performSelected(onDismiss: onDismiss)
        case .cancel:
            onDismiss()
            return true
        }
    }

    private func reconcileSelection() {
        let results = filteredCommands
        if let selectedCommandID, results.contains(where: { $0.id == selectedCommandID }) {
            return
        }
        selectedCommandID = results.first?.id
    }
}
