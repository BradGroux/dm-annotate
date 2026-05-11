# dm-annotate

`dm-annotate` / **Digital Meld Annotate** is a native macOS screen annotation tool. It is MIT licensed, local-only, and built to stay lean.

The app runs from the macOS menu bar and provides a floating toolbar for drawing over any app during demos, classes, design reviews, screen shares, and recordings.

> Status: early public release. Core annotation, screenshot, shortcut, settings, and permission flows are implemented, but signed/notarized distribution is still a maintainer release step.

## Features

- Always-on-top transparent annotation overlay across active displays
- Click-through cursor mode
- Standard macOS top menu when the app is active
- Floating toolbar with vertical/horizontal layouts, collapse, drag positioning, and find pulse
- Per-display toolbar position memory
- Cyan drawing-mode indicator when screen controls are active
- Pen, highlighter, eraser, line, rectangle, ellipse, arrow, text, laser pointer, and whiteboard mode
- Annotation lock to prevent accidental edits during presentations
- Tool shortcuts, shortcut tooltips, and click-to-record shortcut customization
- Command palette for keyboard-first access to tools and actions
- Undo, redo, clear all, and show/hide annotations
- Quick colors, 32-color palette, custom color picker, default color, and stroke widths: `1`, `3`, `5`, `10` px
- Full-display and region screenshots to clipboard or timestamped PNG files, with copy/save/reveal options
- Local settings for theme, toolbar, visible tools, screenshot destination, colors, and shortcuts
- Permission warning in the toolbar when Screen Recording or Accessibility is missing
- Diagnostics view for local issue triage
- Global/local shortcut handling with duplicate shortcut warnings

## Documentation

- [Usage guide](docs/USAGE.md)
- [Shortcut reference](docs/SHORTCUTS.md)
- [Architecture notes](docs/ARCHITECTURE.md)
- [Release guide](docs/RELEASE.md)
- [Product requirements](docs/PRD.md)
- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## Requirements

- macOS 13+
- Swift 6.1 compatible toolchain
- Xcode command line tools for local builds

## Clone

```sh
git clone https://github.com/bradgroux/dm-annotate.git
cd dm-annotate
```

## Run from source

```sh
swift run dm-annotate
```

macOS may require Screen Recording permission for screenshots and Accessibility/Input Monitoring permission for global shortcuts.

On first launch, the app shows a permissions onboarding window with status checks and direct links to the required System Settings panes. You can reopen it later from the menu bar under **Permissions...**.

## Emergency exit

- Press `Escape` once to leave drawing mode and return to click-through cursor mode.
- Press `Escape` twice quickly to quit the app.
- Press `Command+Q` while the app has focus to quit immediately.
- Hold `Shift` while launching to start in Safe Mode with overlays and global shortcuts disabled.

If the app previously exited abnormally, the next launch starts in cursor mode and recenters the toolbar.

## Build a local app bundle

```sh
scripts/build-app.sh
open ".build/Digital Meld Annotate.app"
```

The generated app bundle is unsigned. Release builds should be signed and notarized before distribution.

Developer preview downloads may require manual Gatekeeper approval because they are not notarized. See [Opening developer preview builds](docs/RELEASE.md#opening-developer-preview-builds).

## Package a release

```sh
scripts/package-release.sh
```

Optional release environment:

```sh
CODESIGN_IDENTITY="Developer ID Application: Example" scripts/package-release.sh
CODESIGN_IDENTITY="Developer ID Application: Example" NOTARIZE_PROFILE="dm-annotate" scripts/package-release.sh
```

See [docs/RELEASE.md](docs/RELEASE.md) for the full release checklist.

## Build and test

```sh
swift build
swift test
```

## Privacy

`dm-annotate` is designed to be local-only:

- No accounts
- No analytics
- No telemetry
- No cloud sync
- No license activation
- No network calls during normal operation

Annotations live in memory and are cleared when the app exits.

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Contributing

Issues and pull requests are welcome. Please keep the app native, small, local-only, and dependency-light. Start with [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
