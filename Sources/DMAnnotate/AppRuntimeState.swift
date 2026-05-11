import AppKit
import Combine

@MainActor
final class AppRuntimeState: ObservableObject {
    @Published private(set) var isSafeMode = false
    @Published private(set) var recoveredFromAbnormalExit = false

    func configure(isSafeMode: Bool, recoveredFromAbnormalExit: Bool) {
        self.isSafeMode = isSafeMode
        self.recoveredFromAbnormalExit = recoveredFromAbnormalExit
    }

    var modeLabel: String? {
        if isSafeMode {
            return "Safe Mode"
        }
        if recoveredFromAbnormalExit {
            return "Recovered"
        }
        return nil
    }
}

struct LaunchState {
    var isSafeMode: Bool
    var recoveredFromAbnormalExit: Bool
}

final class LaunchRecoveryController {
    private let defaults: UserDefaults
    private let activeKey = "dmAnnotate.launch.active.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func beginLaunch() -> LaunchState {
        let recovered = defaults.bool(forKey: activeKey)
        defaults.set(true, forKey: activeKey)
        return LaunchState(isSafeMode: Self.shiftKeyPressed(), recoveredFromAbnormalExit: recovered)
    }

    func markCleanExit() {
        defaults.set(false, forKey: activeKey)
    }

    private static func shiftKeyPressed() -> Bool {
        CGEventSource.flagsState(.combinedSessionState).contains(.maskShift)
    }
}

