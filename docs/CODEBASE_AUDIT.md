# Codebase Audit

Last audited: 2026-05-16

## Scope

This audit covered the SwiftPM package, AppKit and SwiftUI runtime code, core model layer, tests, scripts, packaging metadata, CI, release workflow, Homebrew cask, and user-facing docs.

## Current State

`dm-annotate` remains a lean native macOS app with no production dependencies outside Apple frameworks. The codebase is small enough to keep moving quickly, but several UI files now carry enough responsibility that future feature work should avoid adding more behavior directly into those views.

Strengths:

- Core annotation state is isolated in `DMAnnotateCore` and covered by fast Swift Testing tests.
- Packaging is scriptable through SwiftPM and shell scripts rather than an Xcode-only workflow.
- The privacy posture is simple and credible: local-only, no accounts, no telemetry, no normal-operation network calls.
- Release and Homebrew metadata are present and mostly aligned with the current `BradGroux/tap` distribution path.

## Fixed During This Audit

- Screenshot capture now hides toolbar chrome and tooltips while capturing, preventing app UI from leaking into screenshots.
- Global shortcut handling no longer dispatches bare Command-style shortcuts while another app is foregrounded.
- Duplicate shortcut conflicts no longer dispatch whichever action dictionary ordering happens to return first.
- Menu key equivalents now use the current shortcut preferences and refresh when shortcuts change.
- Region screenshot selection explicitly makes its selection view first responder so Escape cancel is reliable.
- Horizontal toolbar sizing and frame clamping now behave on narrow displays.
- Single-click pen and highlighter marks are stored and rendered as visible dots.
- Laser timer cleanup now runs when overlay views leave their windows.
- Erase undo restores annotations at their original indexes to preserve draw and hit-test ordering.
- Text move history no longer records phantom undo actions for annotations that are not in the store.
- CI now smoke-packages the release zip, not just shell-syntax checks the packaging scripts.
- Docs now describe local builds as ad-hoc signed but not notarized, matching the scripts.
- Release notes now record the actual signing/notarization status for each generated release.
- Screenshot region-to-pixel math now lives in a core helper with unit coverage for Retina scaling, bounds clamping, and invalid geometry.
- Toolbar sizing constants now live in one app-level layout helper shared by SwiftUI toolbar controls and the AppKit panel frame estimator.
- Shortcut conflict handling now has a core resolver shared by runtime dispatch, settings diagnostics, and menu key equivalents.
- Toolbar layout metrics now have unit coverage for horizontal clamping and permission-status height changes.
- Permission status changes now request a toolbar resize, keeping the AppKit panel estimate aligned with SwiftUI content after returning from System Settings.
- Release docs now include the same package smoke and SHA256 checks that CI runs.
- Release workflow signing notes now distinguish ad-hoc, Developer ID signed only, and Developer ID signed plus notarized builds.
- Release zip verification now installs the generated archive into a temporary directory, checks bundle metadata and signatures, and runs a permission-free launch smoke mode.
- Local UI smoke now verifies toolbar, settings, permissions, and command palette windows can appear from a packaged app startup path.
- Permission onboarding now refreshes when reopened or when the app becomes active after returning from System Settings, with a direct next-step prompt.
- Eligible global shortcuts now use a native consumable event-tap path, while local shortcuts and the existing global monitor remain as fallback behavior.
- Settings sections now live in focused SwiftUI views with shared form components, leaving `SettingsView` responsible for navigation and layout shell only.
- Toolbar tool selection, stroke/text controls, screenshot actions, and shared button/tooltip styles now live in focused SwiftUI views.
- Screenshot export now supports transparent annotation-only PNGs alongside the default flattened annotated screenshots.

## Remaining Refactor Targets


## Improvement Backlog

- Add optional session save/load for annotation sets while keeping local-only storage.
- Add shape editing after placement: move, resize, recolor, and delete individual annotations.
- Add per-display toolbar presets for common presentation setups.
- Add a compact presenter mode with only the active tool, color, width, undo, and cursor controls.
