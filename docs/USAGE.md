# Usage Guide

`dm-annotate` is designed for live annotation during demos, classes, design reviews, screen shares, and recordings.

## Launch

Run from source:

```sh
swift run dm-annotate
```

Build and open a local app bundle:

```sh
scripts/build-app.sh
open ".build/Digital Meld Annotate.app"
```

The app appears in the macOS menu bar and shows a floating toolbar.

## Permissions

macOS may require:

- Screen Recording: needed for screenshots that include underlying screen content.
- Accessibility: needed for global shortcut reliability and interaction recovery.
- Input Monitoring: may be needed by macOS for global keyboard handling.

The onboarding window shows current permission status and links to the relevant System Settings panes. Reopen it from **Permissions...** in the app menu or menu bar item.

## Toolbar

The floating toolbar supports:

- Dragging by the grip.
- Vertical and horizontal layouts.
- Collapse/expand.
- A find/pulse action if the toolbar gets lost.
- Tooltips on hover with shortcut labels where available.
- A cyan border when the app is actively controlling pointer input.

Collapsed mode intentionally shows only the drag grip and expand button.

## Drawing and Click-through

- Cursor mode passes pointer events through to apps underneath.
- Drawing tools capture pointer input on the overlay.
- Press `Escape` once to exit drawing controls and return to cursor mode.
- Press `Escape` twice quickly to quit.
- Press `Command+Q` while the app is focused to quit.

## Tools

Supported tools:

- Cursor
- Pen
- Highlighter
- Eraser
- Line
- Rectangle
- Ellipse
- Arrow
- Text
- Laser pointer
- Whiteboard

Whiteboard mode supports white, black, light grid, and dark grid backgrounds.

## Colors and Stroke Width

The toolbar includes:

- Four quick colors.
- A 32-color palette.
- A custom color swatch that opens the macOS color panel.
- Stroke widths: `1`, `3`, `5`, and `10` px.

Quick colors and the default color can be changed in Settings.

## Screenshots

Screenshot actions include:

- Full-display screenshot using the configured default output.
- Region screenshot.
- Copy PNG to clipboard.
- Save timestamped PNG to disk.
- Reveal the last saved screenshot in Finder.

The default folder is `~/Downloads`.

Screenshot filename format:

```text
dm-annotate-YYYYMMDD-HHMMSS.png
```

## Settings

Settings include:

- Theme.
- Toolbar orientation and collapsed state.
- High contrast toolbar.
- Visible tools.
- Screenshot output and folder.
- Whiteboard background.
- Default and quick colors.
- Keyboard shortcuts with duplicate detection and disable support.

## Safe Mode

Hold `Shift` while launching to start in Safe Mode. Safe Mode disables overlays and global shortcuts so you can recover from bad settings or permission issues.

If the previous run exited abnormally, the next launch starts in cursor mode and recenters the toolbar.
