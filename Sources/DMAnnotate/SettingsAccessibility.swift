import DMAnnotateCore

struct SettingsSidebarAccessibilityState: Equatable {
    var sectionTitle: String
    var isSelected: Bool

    var label: String {
        "\(sectionTitle) settings"
    }

    var value: String {
        isSelected ? "Selected" : "Not selected"
    }
}

struct ShortcutRecorderAccessibilityState: Equatable {
    var actionName: String
    var shortcut: String
    var isRecording: Bool
    var isDuplicate: Bool
    var rejectionFeedback: String?

    var label: String {
        "\(actionName) shortcut"
    }

    var value: String {
        if let rejectionFeedback {
            return "\(rejectionFeedback) Recording continues."
        }
        if isRecording {
            return "Recording. Press a shortcut now."
        }
        if shortcut.isEmpty {
            return "Not assigned"
        }
        let assignedValue = ShortcutDescriptor.display(shortcut)
        guard isDuplicate else { return assignedValue }
        return "\(assignedValue). Conflict: also assigned to another action."
    }

    var help: String {
        if isRecording {
            return "Press Delete to clear the shortcut, or Escape to cancel recording."
        }
        let action = isDuplicate ? "Press to record a different shortcut." : "Press to record a new shortcut."
        return "\(action) Press Delete while recording to clear it."
    }
}
