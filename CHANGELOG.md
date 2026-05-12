# Changelog

All notable changes to `dm-annotate` will be documented here.

This project uses `MAJOR.MINOR.PATCH` versioning while the app is pre-1.0.

## Unreleased

## 0.1.4 - 2026-05-11

### Changed

- Documented the temporary `xattr` quarantine workaround required for ad-hoc signed preview builds.
- Added README and usage guide screenshots for toolbar layouts plus whiteboard and blackboard modes.
- Made the toolbar drag grip use adaptive gray so it remains visible in light mode.

## 0.1.3 - 2026-05-11

### Changed

- Replaced the toolbar color list with a compact swatch popover.
- Replaced the fixed 32-color picker with an editable 10-color palette, color-panel add/replace, and saved palette reload.
- Expanded stroke width presets to `1` through `64` px and added custom stroke width entry.
- Added app-owned hover tooltips for toolbar controls so labels show reliably over the floating overlay.
- Added a setting to disable toolbar tooltips.
- Expanded the horizontal toolbar window to fit its visible controls instead of clipping trailing actions.
- Kept the toolbar above annotation overlays so tools can be switched without pressing Escape first.
- Replaced the cramped camera menu button with a plain screenshot icon and compact options popover.
- Reduced stroke width presets to a clean 3-by-4 grid.
- Fixed collapse/expand and vertical/horizontal toolbar transitions leaving the panel at the previous layout size.
- Suppressed origin persistence during programmatic toolbar frame changes so layout toggles cannot overwrite themselves.
- Switched active toolbar glyphs to white on accent-colored buttons.
- Reworked Settings into a sidebar preferences layout with constrained content sections.
- Routed toolbar collapse and orientation buttons through the toolbar window controller so frame changes and mode changes are applied together.
- Made the toolbar Settings and Command Palette buttons close their windows when clicked again.
- Added a blackboard toolbar control beside whiteboard mode.
- Sized the vertical toolbar to its visible controls instead of leaving trailing empty space.
- Removed the toolbar Command Palette and Help buttons now that hover tooltips cover inline help.
- Moved Help into the Settings sidebar.
- Moved recovered/safe-mode launch status out of the toolbar and into Settings Diagnostics.

## 0.1.2 - 2026-05-11

### Fixed

- Ad-hoc sign local and release app bundles so macOS does not treat the assembled unsigned preview bundle as damaged.

## 0.1.1 - 2026-05-11

### Added

- App icon generated from the Digital Meld Annotate artwork.
- App bundle icon wiring for local and GitHub Release builds.

## 0.1.0 - 2026-05-11

Initial public developer preview.

### Added

- Native macOS menu bar app.
- Transparent always-on-top annotation overlays.
- Floating draggable toolbar with vertical, horizontal, and collapsed layouts.
- Cursor/click-through mode.
- Pen, highlighter, eraser, line, rectangle, ellipse, arrow, text, laser pointer, whiteboard, and blackboard tools.
- Annotation lock, undo, redo, clear all, and show/hide annotations.
- Quick colors, palette, custom color panel, and stroke width controls.
- Full-display and region screenshots.
- Configurable local/global shortcuts with duplicate warnings.
- Settings, diagnostics, permission onboarding, Safe Mode, and abnormal-exit recovery.
- Local-only privacy posture with no accounts, analytics, telemetry, cloud sync, or normal-operation network calls.
- SwiftPM build/test setup, app bundle packaging script, release packaging script, CI, release workflow, and public documentation.
