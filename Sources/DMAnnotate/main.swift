import AppKit
import Darwin

private func runLaunchVerification() -> Never {
    let bundle = Bundle.main
    let fileManager = FileManager.default
    var failures: [String] = []

    let requiredStringKeys = [
        "CFBundleIdentifier",
        "CFBundleShortVersionString",
        "CFBundleVersion",
        "CFBundleExecutable",
        "CFBundleName",
        "CFBundleDisplayName"
    ]

    for key in requiredStringKeys {
        if let value = bundle.object(forInfoDictionaryKey: key) as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            continue
        }

        failures.append("Missing or empty \(key).")
    }

    if let executableURL = bundle.executableURL {
        if !fileManager.isExecutableFile(atPath: executableURL.path) {
            failures.append("Bundle executable is not marked executable.")
        }
    } else {
        failures.append("Bundle executable URL is missing.")
    }

    if let iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
       !iconName.isEmpty {
        let iconPath = bundle.resourcePath.map { "\($0)/\(iconName).icns" }
        if iconPath.map(fileManager.fileExists(atPath:)) != true {
            failures.append("Bundle icon resource is missing.")
        }
    } else {
        failures.append("Missing or empty CFBundleIconFile.")
    }

    if failures.isEmpty {
        print("dm-annotate launch verification OK")
        exit(EXIT_SUCCESS)
    }

    fputs("dm-annotate launch verification failed:\n", stderr)
    for failure in failures {
        fputs("- \(failure)\n", stderr)
    }
    exit(EXIT_FAILURE)
}

if CommandLine.arguments.contains("--verify-launch") {
    runLaunchVerification()
}

let app = NSApplication.shared
let delegate = AppDelegate(arguments: CommandLine.arguments)

app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
