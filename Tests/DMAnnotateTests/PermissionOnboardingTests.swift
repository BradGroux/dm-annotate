import AppKit
import Testing
@testable import DMAnnotate

@MainActor
@Test func permissionOnboardingReadsInputMonitoringWithoutPrompting() throws {
    let state = TestPermissionState(inputMonitoring: .notGranted)
    let viewModel = PermissionOnboardingViewModel(permissions: state.client)

    let item = try #require(viewModel.items.first { $0.kind == .inputMonitoring })
    #expect(item.status == .notGranted)
    #expect(item.buttonTitle == "Grant Access")
    #expect(state.inputMonitoringRequestCount == 0)
}

@MainActor
@Test func explicitInputMonitoringActionRequestsAndRefreshesStatus() throws {
    let state = TestPermissionState(inputMonitoring: .notGranted, grantInputMonitoringOnRequest: true)
    var openedSettings: [SystemSettings] = []
    let viewModel = PermissionOnboardingViewModel(
        permissions: state.client,
        openSettings: { openedSettings.append($0) }
    )

    viewModel.requestOrOpen(.inputMonitoring)

    let item = try #require(viewModel.items.first { $0.kind == .inputMonitoring })
    #expect(state.inputMonitoringRequestCount == 1)
    #expect(openedSettings == [.inputMonitoring])
    #expect(item.status == .granted)
    #expect(item.buttonTitle == "Open Settings")
}

@MainActor
@Test func deniedInputMonitoringRequestRemainsNeeded() throws {
    let state = TestPermissionState(inputMonitoring: .notGranted, grantInputMonitoringOnRequest: false)
    let viewModel = PermissionOnboardingViewModel(
        permissions: state.client,
        openSettings: { _ in }
    )

    viewModel.requestOrOpen(.inputMonitoring)

    let item = try #require(viewModel.items.first { $0.kind == .inputMonitoring })
    #expect(state.inputMonitoringRequestCount == 1)
    #expect(item.status == .notGranted)
    #expect(item.buttonTitle == "Grant Access")
}

@MainActor
@Test func returningFromSettingsCanRefreshDeniedToGrantedWithoutAnotherPrompt() throws {
    let state = TestPermissionState(inputMonitoring: .notGranted)
    let viewModel = PermissionOnboardingViewModel(permissions: state.client)

    state.inputMonitoring = .granted
    viewModel.refresh()

    let item = try #require(viewModel.items.first { $0.kind == .inputMonitoring })
    #expect(item.status == .granted)
    #expect(state.inputMonitoringRequestCount == 0)
    #expect(viewModel.nextStep.contains("Required permissions are ready"))
}

@MainActor
@Test func grantedInputMonitoringActionOnlyOpensSettings() {
    let state = TestPermissionState(inputMonitoring: .granted)
    var openedSettings: [SystemSettings] = []
    let viewModel = PermissionOnboardingViewModel(
        permissions: state.client,
        openSettings: { openedSettings.append($0) }
    )

    viewModel.requestOrOpen(.inputMonitoring)

    #expect(state.inputMonitoringRequestCount == 0)
    #expect(openedSettings == [.inputMonitoring])
}

@MainActor
@Test func appActivationRequestsExactlyOneShortcutMonitorRestart() {
    let notificationCenter = NotificationCenter()
    var restartCount = 0
    let recovery = ShortcutActivationRecovery(notificationCenter: notificationCenter) {
        restartCount += 1
    }

    notificationCenter.post(name: NSApplication.didBecomeActiveNotification, object: nil)

    #expect(restartCount == 1)
    _ = recovery
}

@MainActor
private final class TestPermissionState {
    var screenRecording: PermissionStatus = .granted
    var accessibility: PermissionStatus = .granted
    var inputMonitoring: PermissionStatus
    private let grantInputMonitoringOnRequest: Bool
    private(set) var inputMonitoringRequestCount = 0

    init(inputMonitoring: PermissionStatus, grantInputMonitoringOnRequest: Bool = false) {
        self.inputMonitoring = inputMonitoring
        self.grantInputMonitoringOnRequest = grantInputMonitoringOnRequest
    }

    var client: PermissionClient {
        PermissionClient(
            screenRecordingStatus: { [unowned self] in screenRecording },
            accessibilityStatus: { [unowned self] in accessibility },
            inputMonitoringStatus: { [unowned self] in inputMonitoring },
            requestScreenRecording: {},
            requestAccessibility: {},
            requestInputMonitoring: { [unowned self] in
                inputMonitoringRequestCount += 1
                if grantInputMonitoringOnRequest {
                    inputMonitoring = .granted
                }
            }
        )
    }
}
