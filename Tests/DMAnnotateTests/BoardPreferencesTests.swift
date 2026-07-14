import DMAnnotateCore
import Foundation
import Testing
@testable import DMAnnotate

@MainActor
@Test func boardVisibilityAndBackgroundPersistAcrossControllerRestart() throws {
    let suiteName = "BoardPreferencesTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let firstStore = AnnotationStore()
    let firstController = PreferencesController(store: firstStore, defaults: defaults)
    firstController.update { snapshot in
        snapshot.whiteboardBackground = .lightGrid
        snapshot.setBoardToolsVisible(false)
    }
    firstController.setActiveTool(.blackboard)

    let restartedController = PreferencesController(store: AnnotationStore(), defaults: defaults)

    #expect(restartedController.snapshot.whiteboardBackground == .darkGrid)
    #expect(!restartedController.snapshot.boardToolsVisible)
}

@MainActor
@Test func preferencesUpdateCannotLeaveOneBoardToolVisible() throws {
    let suiteName = "BoardPreferencesTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let controller = PreferencesController(store: AnnotationStore(), defaults: defaults)

    controller.update { snapshot in
        snapshot.visibleTools.remove(.whiteboard)
    }

    #expect(controller.snapshot.boardToolsVisible)
    #expect(controller.snapshot.visibleTools.contains(.whiteboard))
    #expect(controller.snapshot.visibleTools.contains(.blackboard))
}
