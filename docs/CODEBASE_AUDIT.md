# Codebase Audit

Last audited: 2026-05-16

## Scope

This audit covered the SwiftPM package, AppKit and SwiftUI runtime code, core model layer, tests, scripts, packaging metadata, CI, release workflow, Homebrew distribution docs, and user-facing docs.

## Current State

`dm-annotate` remains a lean native macOS app with no production dependencies outside Apple frameworks. The codebase is small enough to keep moving quickly, but several UI files now carry enough responsibility that future feature work should avoid adding more behavior directly into those views.

Strengths:

- Core annotation state is isolated in `DMAnnotateCore` and covered by fast Swift Testing tests.
- Packaging is scriptable through SwiftPM and shell scripts rather than an Xcode-only workflow.
- The privacy posture is simple and credible: local-only, no accounts, no telemetry, no normal-operation network calls.
- Release metadata and Homebrew distribution docs are aligned with the current `BradGroux/tap` distribution path.

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
- Release notes now record notarized release verification status for generated release artifacts.
- Screenshot region-to-pixel math now lives in a core helper with unit coverage for Retina scaling, bounds clamping, and invalid geometry.
- Toolbar sizing constants now live in one app-level layout helper shared by SwiftUI toolbar controls and the AppKit panel frame estimator.
- Shortcut conflict handling now has a core resolver shared by runtime dispatch, settings diagnostics, and menu key equivalents.
- Toolbar layout metrics now have unit coverage for horizontal clamping and permission-status height changes.
- Permission status changes now request a toolbar resize, keeping the AppKit panel estimate aligned with SwiftUI content after returning from System Settings.
- Release docs now include the same package smoke and SHA256 checks that CI runs.
- Release workflow signing notes now distinguish local ad-hoc builds from required signed/notarized tag releases.
- Release zip verification now installs the generated archive into a temporary directory, checks bundle metadata and signatures, and runs a permission-free launch smoke mode.
- Local UI smoke now verifies toolbar, settings, permissions, and command palette windows can appear from a packaged app startup path, then exercises toolbar layout states, command palette action generation, and toolbar preset preference round-tripping.
- Permission onboarding now refreshes when reopened or when the app becomes active after returning from System Settings, with a direct next-step prompt.
- Eligible global shortcuts now use a native consumable event-tap path, and Diagnostics surfaces event-tap failures instead of silently falling back to non-consumable global shortcuts.
- Settings sections now live in focused SwiftUI views with shared form components, leaving `SettingsView` responsible for navigation and layout shell only.
- Toolbar tool selection, stroke/text controls, screenshot actions, and shared button/tooltip styles now live in focused SwiftUI views.
- Screenshot export now supports transparent annotation-only PNGs alongside the default flattened annotated screenshots.
- Annotation sessions now save and load local `.dmannotate-session` files with safe display retargeting.
- Select mode now supports placed annotation move, delete, recolor, stroke sizing, and text style edits with undo/redo.
- Toolbar layout presets now save and apply local display-aware toolbar layouts.
- Compact presenter mode now exposes the active tool, color, stroke width, undo, delete/clear, and cursor controls in a smaller toolbar.
- Tagged GitHub releases now validate complete Developer ID signing and notarization for public artifacts, while still allowing explicit ad-hoc developer-preview releases.

## Remaining Refactor Targets


## Improvement Backlog

- Add richer resize handles for direct mouse resizing of selected shapes.
