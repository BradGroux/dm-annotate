import AppKit
import ApplicationServices
import SwiftUI

struct PermissionOnboardingView: View {
    @ObservedObject private var viewModel: PermissionOnboardingViewModel
    var onContinue: () -> Void

    init(viewModel: PermissionOnboardingViewModel, onContinue: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            VStack(spacing: 12) {
                ForEach(viewModel.items) { item in
                    PermissionCard(item: item) {
                        viewModel.requestOrOpen(item.kind)
                    }
                }
            }

            footer
        }
        .padding(28)
        .frame(minWidth: 720, minHeight: 560)
        .onAppear {
            viewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text("Finish Mac Permissions")
                .font(.system(size: 30, weight: .semibold))

            Text("Digital Meld Annotate works best when macOS lets it capture screenshots and listen for shortcuts while you present. Drawing still works without accounts, analytics, telemetry, or cloud services.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.nextStep)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button {
                    viewModel.refresh()
                } label: {
                    Label("Check Again", systemImage: "arrow.clockwise")
                }

                Spacer()

                Button("Continue") {
                    onContinue()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct PermissionCard: View {
    var item: PermissionItem
    var action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            statusIcon
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                    Spacer()
                    Text(item.status.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.status.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.status.tint.opacity(0.12), in: Capsule())
                }

                Text(item.reason)
                    .foregroundStyle(.primary)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(item.buttonTitle, action: action)
                .frame(width: 150)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var statusIcon: some View {
        switch item.status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .notGranted:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        case .unknown:
            Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(.blue)
        }
    }
}

@MainActor
final class PermissionOnboardingViewModel: ObservableObject {
    @Published private(set) var items: [PermissionItem] = []
    @Published private(set) var nextStep = ""
    private let permissions: PermissionClient
    private let openSettings: (SystemSettings) -> Void

    init(
        permissions: PermissionClient = .live,
        openSettings: @escaping (SystemSettings) -> Void = SystemSettings.open
    ) {
        self.permissions = permissions
        self.openSettings = openSettings
        refresh()
    }

    func refresh() {
        let screenRecordingStatus = permissions.screenRecordingStatus()
        let accessibilityStatus = permissions.accessibilityStatus()
        let inputMonitoringStatus = permissions.inputMonitoringStatus()

        items = [
            PermissionItem(
                kind: .screenRecording,
                title: "Screen Recording",
                reason: "Required for full-screen and region screenshots that include other apps behind your annotations.",
                detail: "macOS controls this in Privacy & Security. Return to this window after changing it and the status will refresh.",
                status: screenRecordingStatus,
                buttonTitle: screenRecordingStatus == .granted ? "Open Settings" : "Grant Access"
            ),
            PermissionItem(
                kind: .accessibility,
                title: "Accessibility",
                reason: "Used for reliable global shortcut behavior while another app is active.",
                detail: "Digital Meld Annotate does not inspect app content; return here after granting access and the status will refresh.",
                status: accessibilityStatus,
                buttonTitle: accessibilityStatus == .granted ? "Open Settings" : "Grant Access"
            ),
            PermissionItem(
                kind: .inputMonitoring,
                title: "Input Monitoring",
                reason: "May be required by macOS for global keyboard shortcuts, depending on OS version and security settings.",
                detail: "Digital Meld Annotate checks this with the supported listen-event API. Access is requested only when you choose Grant Access.",
                status: inputMonitoringStatus,
                buttonTitle: inputMonitoringStatus == .granted ? "Open Settings" : "Grant Access"
            )
        ]
        nextStep = Self.nextStep(
            screenRecording: screenRecordingStatus,
            accessibility: accessibilityStatus,
            inputMonitoring: inputMonitoringStatus
        )
    }

    func requestOrOpen(_ kind: PermissionKind) {
        switch kind {
        case .screenRecording:
            if permissions.screenRecordingStatus() != .granted {
                permissions.requestScreenRecording()
            }
            openSettings(.screenRecording)
        case .accessibility:
            if permissions.accessibilityStatus() != .granted {
                permissions.requestAccessibility()
            }
            openSettings(.accessibility)
        case .inputMonitoring:
            if permissions.inputMonitoringStatus() != .granted {
                permissions.requestInputMonitoring()
            }
            openSettings(.inputMonitoring)
        }

        refresh()
    }

    private static func nextStep(
        screenRecording: PermissionStatus,
        accessibility: PermissionStatus,
        inputMonitoring: PermissionStatus
    ) -> String {
        if screenRecording != .granted {
            return "Next: grant Screen Recording in System Settings, then return to this window."
        }
        if accessibility != .granted {
            return "Next: grant Accessibility in System Settings, then return to this window."
        }
        if inputMonitoring != .granted {
            return "Input Monitoring is not granted. If global shortcuts are unavailable, choose Grant Access, then return so shortcut monitoring can restart."
        }
        return "Required permissions are ready. If Diagnostics reports Global shortcuts as unavailable, restart shortcuts."
    }
}

struct PermissionItem: Identifiable, Equatable {
    var kind: PermissionKind
    var title: String
    var reason: String
    var detail: String
    var status: PermissionStatus
    var buttonTitle: String

    var id: PermissionKind { kind }
}

enum PermissionKind: String {
    case screenRecording
    case accessibility
    case inputMonitoring
}

enum PermissionStatus: Equatable {
    case granted
    case notGranted
    case unknown

    var label: String {
        switch self {
        case .granted: "Granted"
        case .notGranted: "Needed"
        case .unknown: "Check Manually"
        }
    }

    var tint: Color {
        switch self {
        case .granted: .green
        case .notGranted: .orange
        case .unknown: .blue
        }
    }
}

struct PermissionSummary: Equatable {
    var screenRecording: PermissionStatus
    var accessibility: PermissionStatus

    static func current() -> PermissionSummary {
        PermissionSummary(
            screenRecording: PermissionChecks.screenRecordingStatus(),
            accessibility: PermissionChecks.accessibilityStatus()
        )
    }

    var needsAttention: Bool {
        screenRecording != .granted || accessibility != .granted
    }

    var message: String {
        var missing: [String] = []
        if screenRecording != .granted {
            missing.append("Screen Recording")
        }
        if accessibility != .granted {
            missing.append("Accessibility")
        }
        return missing.isEmpty ? "Permissions granted" : "Missing permissions: \(missing.joined(separator: ", "))"
    }
}

@MainActor
struct PermissionClient {
    var screenRecordingStatus: () -> PermissionStatus
    var accessibilityStatus: () -> PermissionStatus
    var inputMonitoringStatus: () -> PermissionStatus
    var requestScreenRecording: () -> Void
    var requestAccessibility: () -> Void
    var requestInputMonitoring: () -> Void

    static let live = PermissionClient(
        screenRecordingStatus: PermissionChecks.screenRecordingStatus,
        accessibilityStatus: PermissionChecks.accessibilityStatus,
        inputMonitoringStatus: PermissionChecks.inputMonitoringStatus,
        requestScreenRecording: PermissionChecks.requestScreenRecording,
        requestAccessibility: PermissionChecks.requestAccessibilityPrompt,
        requestInputMonitoring: PermissionChecks.requestInputMonitoring
    )
}

enum PermissionChecks {
    static func screenRecordingStatus() -> PermissionStatus {
        CGPreflightScreenCaptureAccess() ? .granted : .notGranted
    }

    static func accessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .notGranted
    }

    static func inputMonitoringStatus() -> PermissionStatus {
        CGPreflightListenEventAccess() ? .granted : .notGranted
    }

    static func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
    }

    static func requestAccessibilityPrompt() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
    }
}

enum SystemSettings {
    case screenRecording
    case accessibility
    case inputMonitoring

    var url: URL {
        switch self {
        case .screenRecording:
            URL.screenRecordingSettings
        case .accessibility:
            URL.accessibilitySettings
        case .inputMonitoring:
            URL.inputMonitoringSettings
        }
    }

    static func open(_ destination: SystemSettings) {
        NSWorkspace.shared.open(destination.url)
    }
}

private extension URL {
    static let screenRecordingSettings = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    ) ?? URL(fileURLWithPath: "/System/Applications/System Settings.app")

    static let accessibilitySettings = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    ) ?? URL(fileURLWithPath: "/System/Applications/System Settings.app")

    static let inputMonitoringSettings = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    ) ?? URL(fileURLWithPath: "/System/Applications/System Settings.app")
}
