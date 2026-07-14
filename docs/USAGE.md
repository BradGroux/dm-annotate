# Usage Guide

`dm-annotate` is designed for live annotation during demos, classes, design reviews, screen shares, and recordings.

<p align="center">
  <img src="assets/screenshots/dm-annotate-demo.png" alt="Digital Meld Annotate drawing over a GitHub page" width="900">
</p>

## Mac Requirements

- macOS 13 Ventura or later.
- Apple silicon and Intel Macs. Release builds from the current source require both `arm64` and `x86_64` executable slices.
- Screen Recording permission for full-screen and region screenshots that include other apps behind annotations.
- Accessibility permission for reliable global shortcuts while another app is active.
- Input Monitoring may be required by macOS for global keyboard shortcuts, depending on OS version and security settings.

The onboarding window checks these permissions and links to the relevant **System Settings > Privacy & Security** panes. It refreshes when you return from System Settings. Reopen it from **Permissions...** in the app menu or menu bar item.

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

> [!IMPORTANT]
> Current ad-hoc builds are not notarized. macOS Gatekeeper may block the first launch.
>
> After moving the app to `/Applications`, run:
>
> ```sh
> xattr -dr com.apple.quarantine "/Applications/Digital Meld Annotate.app"
> open "/Applications/Digital Meld Annotate.app"
> ```
>
> Only do this for builds you trust.

The app appears in the macOS menu bar and shows a floating toolbar.

## Install with Homebrew

The recommended install path is the dedicated `BradGroux/tap` Homebrew tap:

```sh
brew tap BradGroux/tap
brew install --cask dm-annotate
```

Homebrew installs use the current GitHub release artifact. Published Homebrew artifacts are Developer ID signed, notarized, and stapled. The existing v0.1.12 artifact is Apple silicon only; universal Apple silicon and Intel packaging takes effect with the next release.

## Permissions

macOS may require:

- Screen Recording: needed for screenshots that include underlying screen content.
- Accessibility: needed for global shortcut reliability and interaction recovery.
- Input Monitoring: may be needed by macOS for global keyboard handling. The app reports the listen-event permission state and requests it only when you choose **Grant Access**.

The onboarding window shows current permission status, links to the relevant System Settings panes, and refreshes when the app becomes active again after you return from System Settings. Global shortcut monitoring is rebuilt on activation so a newly granted Input Monitoring permission takes effect. Reopen onboarding from **Permissions...** in the app menu or menu bar item.

Consumable global shortcuts use a native macOS event tap so app shortcuts do not leak into the foreground app. If macOS denies that event tap, `dm-annotate` disables global shortcut dispatch and reports the failure in Diagnostics; grant Accessibility, confirm Input Monitoring, and restart shortcuts.

**Restart Shortcut Monitoring** in Settings and Diagnostics stops and restarts the local and global shortcut monitors. It does not test a shortcut or imply that macOS permissions were granted.

## Toolbar

The floating toolbar supports:

- Dragging by the grip.
- Vertical and horizontal layouts.
- Compact presenter mode.
- Collapse/expand.
- A find/pulse action if the toolbar gets lost.
- Local layout presets in Settings.
- Tooltips on hover with shortcut labels where available.
- A cyan border when the app is actively controlling pointer input.

Collapsed mode intentionally shows only the drag grip and expand button.

### Toolbar Layouts

| Light horizontal | Dark horizontal |
| --- | --- |
| <img src="assets/screenshots/toolbar-light-horizontal.png" alt="Light horizontal toolbar"> | <img src="assets/screenshots/toolbar-dark-horizontal.png" alt="Dark horizontal toolbar"> |

| Light vertical | Dark vertical |
| --- | --- |
| <img src="assets/screenshots/toolbar-light-vertical.png" alt="Light vertical toolbar" width="140"> | <img src="assets/screenshots/toolbar-dark-vertical.png" alt="Dark vertical toolbar" width="140"> |

## Drawing and Click-through

- Cursor mode passes pointer events through to apps underneath.
- Select mode captures pointer input for editing placed annotations.
- Drawing tools capture pointer input on the overlay.
- Press `Escape` once to exit drawing controls and return to cursor mode.
- Press `Escape` twice quickly to quit.
- Press `Command+Q` while the app is focused to quit.

## Command Palette

Press `Command+K` to open the command palette. Search is focused immediately, so you can type to filter without pressing Tab. The first matching command is selected; use `Up Arrow` and `Down Arrow` to change the selection, `Return` to run it, or `Escape` to close the palette. Filtering that produces no matches shows an explicit empty state. Keyboard selection changes are immediate and are announced by VoiceOver.

## Tools

Supported tools:

- Cursor
- Select
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
- Blackboard

Text annotations support:

- Plain `Enter` to commit the text annotation.
- `Shift+Enter` to insert a newline.
- Auto-expanding text entry as the sentence grows.
- Dragging existing text with the Text tool.
- Text style controls for font size, custom size, weight, and color.

Select mode supports:

- Selecting placed annotations.
- Moving a selected annotation.
- Deleting a selected annotation with `Delete`.
- Recoloring a selected annotation from toolbar color controls.
- Resizing selected strokes and shapes from toolbar stroke controls.

Whiteboard and blackboard controls toggle white and black presentation backgrounds. Settings can still choose light grid or dark grid board backgrounds.

| Whiteboard | Blackboard |
| --- | --- |
| <img src="assets/screenshots/whiteboard.png" alt="Whiteboard mode"> | <img src="assets/screenshots/blackboard.png" alt="Blackboard mode"> |

## Colors, Stroke Width, and Text Style

The toolbar includes:

- A 10-color editable toolbar palette.
- A custom color swatch that opens the macOS color panel.
- Saved palettes that can be reloaded later.
- Stroke presets from `1` through `64` px plus a custom stroke width entry.
- A text style popover with font size presets, custom font size, font weight, and text color.

The first four palette colors are mapped to Command+1 through Command+4 by default. Palette colors and the default color can be changed in Settings.

## Screenshots

Screenshot actions include:

- Full-display screenshot using the configured default output.
- Region screenshot with crosshair guide lines while selecting.
- Copy flattened PNG to clipboard.
- Save flattened PNG to disk.
- Save transparent annotation-only PNG for layering in another editor.
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
- Compact presenter mode and local toolbar presets.
- High contrast toolbar.
- Toolbar tooltips.
- Visible tools.
- Screenshot output and folder.
- Whiteboard background.
- Default color, toolbar palette, and saved palettes.
- Keyboard shortcuts with duplicate detection and disable support.
- Community links for SSTB.ai, the Start Small, Think Big podcast playlist, and Discord.
- Help, version, permission, and diagnostics links.

Settings controls expose their names and current state to VoiceOver. Sidebar sections announce selection, and repeated actions such as clearing shortcuts or deleting toolbar presets include the affected item name.

To edit a shortcut without a pointer, use Full Keyboard Access to focus its recorder, press `Space` or `Return`, then press the new shortcut. Press `Delete` while recording to clear it or `Escape` to cancel. VoiceOver announces the action name, assigned shortcut, recording instructions, and any duplicate or rejected state.

See [Settings Accessibility Validation](ACCESSIBILITY-TESTING.md) for the packaged AX smoke coverage and manual VoiceOver/Accessibility Inspector matrix.

## Annotation Sessions

Use **File > Save Annotation Session...** to write the current annotations to a local `.dmannotate-session` file. Use **File > Load Annotation Session...** to restore one later.

Session files contain annotation geometry, display IDs, colors, stroke widths, text styles, visibility, lock state, and whiteboard state. If a saved display is missing when loading, annotations are retargeted to the current main display. Session files stay local and are not synced by the app.

Sessions support up to 10,000 annotations, 20,000 points per annotation, 8,000 characters per text annotation, and 10 MiB of encoded data. Long live strokes are progressively simplified before they reach the point limit while preserving endpoints and sharp turns. Saving validates the complete session before atomically replacing a file, so a failed save leaves an existing file unchanged and reports what to reduce or recreate before retrying.

Interactive drawing work is bounded independently of the session limits. Laser trails retain at most 240 spatially distinct samples from the latest 1.5 seconds and reuse one 30 Hz cleanup timer per overlay. Erasing first checks cached annotation bounds, then rejects 64-segment spatial chunks before detailed segment tests. The selected performance budget is one 120 Hz frame (8.33 ms) for an eraser event in a heavy session.

Run the repeatable optimized benchmark from the repository root:

```bash
swift run -c release DMAnnotateBenchmarks
```

The benchmark reports median and p95 work for live stores containing two million and ten million points at the supported per-annotation limit. It allocates and slightly translates every stroke independently so the dataset is not backed by one copy-on-write point array. Both adversarial scenarios place the eraser inside every annotation's overall bounds: one misses all detailed stroke segments, while the other hits every candidate. The command exits unsuccessfully if either p95 exceeds 8.33 ms. The ten-million-point live store intentionally exceeds the 10 MiB encoded-session limit and is not presented as a saveable session. Keep timing out of the portable unit suite because hardware and concurrent system load vary; use Instruments to validate drawing, erasing, moving, and laser input on supported hardware before a release.

Reference run on July 14, 2026, using an Apple M5 with macOS 26.5.1: two million points measured 3.274 ms p95 for the inside-bounds miss and 0.687 ms for the multi-candidate hit; ten million points measured 1.479 ms and 1.662 ms respectively. All four cases stayed below the enforced 8.33 ms budget. Treat these as comparison evidence, not universal guarantees.

## Safe Mode

Hold `Shift` while launching to start in Safe Mode. Safe Mode disables overlays, annotation tool selection in every toolbar layout, and global shortcuts so you can recover from bad settings or permission issues. Cursor, toolbar layout, settings, and other recovery controls remain available. Quit and reopen normally to draw again.

If the previous run exited abnormally, the next launch starts in cursor mode and recenters the toolbar.
