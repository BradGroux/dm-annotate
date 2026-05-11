# PRD: dm-annotate

## Summary

Build `dm-annotate` / `Digital Meld Annotate` as a lean, open-source, MIT-licensed macOS screen annotation app inspired by Markury's practical workflow without copying its branding, UI artwork, text, code, or proprietary assets.

The app lets users draw over any Mac app, keep annotations visible during screen sharing or recording, switch back to click-through mode instantly, and capture annotated screenshots.

## Goals

- Open-source from day one under the MIT License.
- Mac-first, native, fast, local-only screen annotation.
- Near-parity with practical annotation workflows: draw, highlight, point, screenshot, clear.
- No accounts, licensing, telemetry, analytics, cloud sync, or network requirement.
- Keep the codebase small enough for contributors to understand quickly.

## V1 Scope

- Menu bar app with draggable floating toolbar.
- Transparent always-on-top annotation overlay across active displays.
- Cursor/click-through mode.
- Freehand pen, highlighter, eraser, line, rectangle, ellipse, arrow, text, laser pointer, and whiteboard mode.
- Annotation lock and reliable escape/recovery controls.
- Command palette for keyboard-first tools and actions.
- Undo, redo, clear all, and show/hide annotations.
- Color palette, four quick colors, default color, and stroke widths: `1`, `3`, `5`, `10` px.
- Full-display and region screenshots, copied to clipboard or saved as timestamped PNG, with copy/save/reveal controls.
- Customizable shortcuts with conflict detection and disable support.
- Settings for theme, toolbar orientation, high contrast, visible tools, screenshot destination, colors, and shortcuts.
- Permission warning in the toolbar, diagnostics view, Safe Mode launch, and abnormal-exit recovery.
- MIT `LICENSE`, contributor-friendly `README.md`, and clear privacy statement.

## Technical Direction

- Native Swift macOS app.
- AppKit for transparent overlay windows, menu bar status item, global event handling, display behavior, and screenshot capture.
- SwiftUI where useful for Settings and toolbar UI.
- Target macOS 13+ initially.
- Store preferences locally with `UserDefaults`.
- Store annotations in memory as typed objects.
- Avoid production dependencies unless a native gap clearly justifies one.

## Test Plan

- Verify launch, menu bar behavior, toolbar persistence, and overlay display on one and multiple monitors.
- Test every tool for creation, color, stroke width, undo, redo, erase, hide/show, and clear behavior.
- Confirm click-through mode works over normal apps and during screen recording/sharing.
- Confirm screenshots work in clipboard and folder modes, including region selection.
- Confirm permission-denied states are clear and recoverable.
- Confirm Safe Mode launch disables overlays/global shortcuts and abnormal-exit recovery starts in cursor mode.
- Confirm settings persist across restart.
- Track idle CPU near zero and smooth drawing during continuous strokes.
- Validate accessibility labels, keyboard navigation, visible focus states, and sufficient contrast.
