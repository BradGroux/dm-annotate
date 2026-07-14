# Changelog

All notable changes to `dm-annotate` will be documented here.

This project uses `MAJOR.MINOR.PATCH` versioning while the app is pre-1.0.

## Unreleased

### Security

- Fail closed for public release tags unless signing, notarization, Gatekeeper validation, and default-branch provenance checks pass; keep ad-hoc previews behind an explicit draft-prerelease workflow.

### Changed

- Build universal macOS release artifacts for Apple silicon and Intel, and reject archives with missing or unexpected executable slices.
- Move release artifact upload and download actions to pinned Node.js 24-compatible versions.
- Define the latest stable release as the single supported security line and document upgrade and backport expectations.

### Fixed

- Adapt selected toolbar, settings sidebar, stroke-width, and text-size controls to the native macOS selected-control palette with measured foreground contrast across every standard accent.
- Enforce Safe Mode annotation-tool availability consistently across full, compact, and collapsed toolbar recovery states.
- Publish portable SHA256 sidecars that standard verification tools can validate from any download directory.
- Validate annotation sessions before atomic export, preserve existing files on failed saves, and bound live stroke points so saved sessions always remain reloadable.
- Report Input Monitoring through the supported listen-event APIs, request it only from an explicit action, and rebuild global shortcut monitoring after app activation.
- Name shortcut recovery consistently as Restart Shortcut Monitoring without implying that a permission or shortcut test occurred.
- Crop region screenshots before allocating the annotated output, remove the TIFF-to-PNG round trip, and move PNG encoding and file writes off the main actor.
- Focus command search on open and support immediate Up/Down selection, Return execution, Escape cancellation, empty results, and VoiceOver selection announcements.
- Share highlighter and arrow paint geometry across rendering, bounds, selection, hit testing, and erasing so visible strokes remain interactive.

## 0.1.12 - 2026-05-31

### Added

- Added selected-annotation toolbar action sizing coverage so edit controls fit when an annotation is selected.
- Added diagnostics for global shortcut event-tap availability.
- Expanded packaged UI smoke coverage for toolbar layout states, command palette actions, and toolbar preset preference round-tripping.

### Changed

- Keep the cursor and a recovery drawing tool available when visible toolbar tools are customized.
- Disable global shortcut dispatch when macOS denies the consumable event tap instead of falling back to non-consumable global monitoring.

### Fixed

- Prevent starting duplicate region screenshot selection windows.
- Harden annotation session loading against oversized files, excessive annotation counts, excessive point counts, invalid geometry, invalid colors, and long text payloads.
- Cap live undo history for long sessions.
- Keep AppKit toolbar panel sizing controller-owned across SwiftUI layout changes.

## 0.1.11 - 2026-05-25

### Added

- Added App Store Connect API key notarization support for local and GitHub release packaging.

### Changed

- Updated install and release docs to reflect Developer ID signed, notarized, stapled Homebrew artifacts.
- Removed the repo-local Homebrew cask mirror so `BradGroux/tap` is the single cask source of truth.

### Fixed

- Tightened the vertical toolbar layout, moved Compact Presenter into the third top-control position, and removed extra bottom space.
- Kept notarized release packaging logs off stdout so automation receives only the release zip path.

## 0.1.10 - 2026-05-16

### Added

- Added release zip verification and local UI smoke scripts for packaged app validation.
- Added transparent annotation-only PNG export alongside flattened screenshot output.
- Added consumable global shortcut handling with local shortcut fallback.
- Added local annotation session save/load.
- Added Select mode for moving, deleting, recoloring, and resizing placed annotations with undo/redo.
- Added toolbar layout presets and compact presenter mode.

### Changed

- Split toolbar and settings sections into focused SwiftUI views.
- Updated release docs and generated release notes to distinguish ad-hoc developer previews from signed, notarized release artifacts.

### Fixed

- Hide toolbar chrome during screenshot capture.
- Refresh permission onboarding and toolbar warning state after returning from System Settings.
- Preserve visible single-click pen/highlighter dots, erase undo ordering, region screenshot Escape handling, and toolbar sizing on narrow displays.

## 0.1.9 - 2026-05-13

### Changed

- Kept the floating toolbar annotation lock button and grouped screenshot actions together.
- Fixed vertical toolbar sizing so the bottom action controls are not clipped.

## 0.1.8 - 2026-05-13

### Added

- Added a Homebrew Cask definition and installation documentation.
- Added the dedicated `BradGroux/tap` Homebrew install path to the docs.
- Added a Community settings page with SSTB.ai, podcast playlist, and Discord links.
- Shortened the macOS app menu title to `Annotate` while keeping the app display name as `Digital Meld Annotate`.

## 0.1.7 - 2026-05-12

### Fixed

- Keep the live text entry box anchored and on-screen while typing or resizing.

## 0.1.6 - 2026-05-12

### Added

- Added the annotated demo screenshot to README and usage docs.
- Added toolbar text style controls for font size, weight, and text color.

### Fixed

- Let Shift+Enter insert a newline while plain Enter commits text annotations.
- Make the live text entry box expand as text grows instead of clipping the sentence.
- Prevent the same click from both committing a text annotation and starting a move/new text action.

## 0.1.5 - 2026-05-12

### Fixed

- Render screenshot annotations at native display pixel resolution so saved PNGs are sharper on Retina displays.
- Show a crosshair cursor and guide lines as soon as region screenshot selection starts.
- Put Undo and Redo first in the toolbar action group, with annotation lock immediately after them.
- Allow existing text annotations to be dragged with the Text tool, including undo/redo for moves.

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
