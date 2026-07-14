import AppKit

enum CommandPaletteAppKitSeams {
    static let emptyStateAccessibilityLabel = "No matching commands. Try a different command or action name."

    static func keyboardCommand(for selector: Selector) -> CommandPaletteKeyboardCommand? {
        switch selector {
        case #selector(NSResponder.moveUp(_:)): .movePrevious
        case #selector(NSResponder.moveDown(_:)): .moveNext
        case #selector(NSResponder.insertNewline(_:)): .perform
        case #selector(NSResponder.cancelOperation(_:)): .cancel
        default: nil
        }
    }

    static func scrollTarget(for selectedCommandID: CommandPaletteCommand.ID?) -> CommandPaletteCommand.ID? {
        selectedCommandID
    }

    static func restorationDestination(previousWindowVisible: Bool, previousApplicationAvailable: Bool) -> FocusDestination {
        if previousWindowVisible { return .window }
        if previousApplicationAvailable { return .application }
        return .none
    }

    enum FocusDestination: Equatable {
        case window
        case application
        case none
    }
}

@MainActor
final class CommandPaletteSearchFocusCoordinator {
    private(set) var fulfilledRequest = -1
    private var pendingRequest = -1
    private weak var searchField: NSSearchField?
    private let tryFocus: (NSSearchField) -> Bool

    init(tryFocus: @escaping (NSSearchField) -> Bool = { searchField in
        guard let window = searchField.window, window.isKeyWindow else { return false }
        return window.makeFirstResponder(searchField)
    }) {
        self.tryFocus = tryFocus
    }

    func request(_ request: Int, for searchField: NSSearchField) {
        guard fulfilledRequest != request else { return }
        pendingRequest = request
        self.searchField = searchField
    }

    @discardableResult
    func attempt() -> Bool {
        guard pendingRequest != fulfilledRequest, let searchField, tryFocus(searchField) else { return false }
        fulfilledRequest = pendingRequest
        return true
    }
}

@MainActor
final class CommandPaletteAccessibilityAnnouncer {
    private let post: (NSSearchField, String) -> Void

    init(post: @escaping (NSSearchField, String) -> Void = { searchField, message in
        NSAccessibility.post(
            element: searchField,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }) {
        self.post = post
    }

    func announce(_ message: String, from searchField: NSSearchField) {
        post(searchField, message)
    }
}
