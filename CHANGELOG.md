# Changelog

All notable changes to `dm-annotate` will be documented here.

This project uses `MAJOR.MINOR.PATCH` versioning while the app is pre-1.0.

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
- Pen, highlighter, eraser, line, rectangle, ellipse, arrow, text, laser pointer, and whiteboard tools.
- Annotation lock, undo, redo, clear all, and show/hide annotations.
- Quick colors, palette, custom color panel, and stroke width controls.
- Full-display and region screenshots.
- Configurable local/global shortcuts with duplicate warnings.
- Settings, diagnostics, permission onboarding, Safe Mode, and abnormal-exit recovery.
- Local-only privacy posture with no accounts, analytics, telemetry, cloud sync, or normal-operation network calls.
- SwiftPM build/test setup, app bundle packaging script, release packaging script, CI, release workflow, and public documentation.
