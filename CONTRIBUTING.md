# Contributing

Thanks for helping improve `dm-annotate`.

This project should stay native, small, local-only, and easy to understand.

## Development setup

Requirements:

- macOS 13+
- Swift 6.1 compatible toolchain
- Xcode command line tools

Run:

```sh
swift build
swift test
swift run dm-annotate
```

Build a local app bundle:

```sh
scripts/build-app.sh
```

## Before opening a pull request

Run:

```sh
swift build
swift test
plutil -lint Packaging/Info.plist
bash -n scripts/build-app.sh
bash -n scripts/package-release.sh
```

For UI changes, also manually check:

- Toolbar vertical and horizontal layouts.
- Collapsed toolbar.
- Hover tooltips.
- Drawing mode and cursor mode.
- Escape recovery.
- Screenshot capture.

## Scope guidelines

Good contributions:

- Fix annotation correctness bugs.
- Improve toolbar ergonomics.
- Improve permission and recovery flows.
- Add focused tests for core behavior.
- Improve docs that match shipped behavior.

Avoid by default:

- Network services.
- Accounts.
- Telemetry.
- Analytics.
- Cloud sync.
- Heavy dependencies.
- Large rewrites without an issue discussion.

## Coding style

- Prefer AppKit and SwiftUI patterns already used in the codebase.
- Keep UI changes accessible: labels, hover help, contrast, keyboard flow.
- Keep core state testable in `DMAnnotateCore`.
- Add dependencies only when a native framework gap clearly justifies them.
- Keep comments useful and sparse.

## Reporting bugs

Please include:

- macOS version.
- Build source: source run, local app bundle, or release zip.
- Display count and arrangement if relevant.
- Whether Screen Recording, Accessibility, and Input Monitoring are granted.
- Reproduction steps.
- Expected behavior.
- Actual behavior.
