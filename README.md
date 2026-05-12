# dm-annotate

`dm-annotate` / **Digital Meld Annotate** is a native macOS screen annotation tool. It is MIT licensed, local-only, and built to stay lean.

The app runs from the macOS menu bar and provides a floating toolbar for drawing over any app during demos, classes, design reviews, screen shares, and recordings.

> Status: early public release. Core annotation, screenshot, shortcut, settings, and permission flows are implemented, but signed/notarized distribution is still a maintainer release step.

## Demo

<p align="center">
  <img src="docs/assets/screenshots/dm-annotate-demo.png" alt="Digital Meld Annotate drawing over a GitHub page" width="950">
</p>

## Toolbar Preview

<p align="center">
  <img src="docs/assets/screenshots/toolbar-dark-horizontal.png" alt="Digital Meld Annotate dark horizontal toolbar" width="900">
</p>

| Light toolbar | Dark toolbar |
| --- | --- |
| <img src="docs/assets/screenshots/toolbar-light-horizontal.png" alt="Digital Meld Annotate light horizontal toolbar"> | <img src="docs/assets/screenshots/toolbar-dark-horizontal.png" alt="Digital Meld Annotate dark horizontal toolbar"> |

| Whiteboard | Blackboard |
| --- | --- |
| <img src="docs/assets/screenshots/whiteboard.png" alt="Digital Meld Annotate whiteboard mode"> | <img src="docs/assets/screenshots/blackboard.png" alt="Digital Meld Annotate blackboard mode"> |

## Features

- Always-on-top transparent annotation overlay across active displays
- Click-through cursor mode
- Standard macOS top menu when the app is active
- Floating toolbar with vertical/horizontal layouts, collapse, drag positioning, and find pulse
- Per-display toolbar position memory
- Cyan drawing-mode indicator when screen controls are active
- Pen, highlighter, eraser, line, rectangle, ellipse, arrow, text, laser pointer, whiteboard, and blackboard modes
- Annotation lock to prevent accidental edits during presentations
- Tool shortcuts, shortcut tooltips, and click-to-record shortcut customization
- Command palette for keyboard-first access to tools and actions
- Undo, redo, clear all, and show/hide annotations
- Text annotations with movable text, Shift+Enter multiline entry, an auto-expanding editor, and text style controls for size, weight, and color
- 10-color editable palette, saved/reloadable palettes, custom color picker, default color, and stroke widths from `1` through `64` px with custom entry
- Full-display and crosshair-guided region screenshots to clipboard or timestamped PNG files, with copy/save/reveal options
- Local settings for theme, toolbar, tooltips, visible tools, screenshot destination, colors, and shortcuts
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

## Mac Requirements

- macOS 13 Ventura or later.
- Screen Recording permission for full-screen and region screenshots that include other apps behind annotations.
- Accessibility permission for reliable global shortcuts while another app is active.
- Input Monitoring may be required by macOS for global keyboard shortcuts, depending on OS version and security settings.
- Swift 6.1 compatible toolchain and Xcode command line tools for local source builds.

The first-run onboarding window checks these permissions and links to the relevant **System Settings > Privacy & Security** panes. You can reopen it from **Permissions...** in the app menu or menu bar item.

## Developer Preview Gatekeeper Step

> [!IMPORTANT]
> Current GitHub release downloads are ad-hoc signed and not notarized. macOS Gatekeeper may block them with an "Apple could not verify" dialog until Developer ID signing is configured.
>
> After moving the app to `/Applications`, run:
>
> ```sh
> xattr -dr com.apple.quarantine "/Applications/Digital Meld Annotate.app"
> open "/Applications/Digital Meld Annotate.app"
> ```
>
> Only do this for builds you trust. See [Opening developer preview builds](docs/RELEASE.md#opening-developer-preview-builds).

## Install with Homebrew

The repository includes a Homebrew Cask for the current GitHub release:

```sh
brew tap BradGroux/dm-annotate https://github.com/BradGroux/dm-annotate
brew install --cask bradgroux/dm-annotate/dm-annotate
```

Until releases are Developer ID signed and notarized, Homebrew installs may still need the Gatekeeper preview step above before first launch.

The long tap name is temporary. Once a dedicated `BradGroux/homebrew-tap` repo exists, the intended install path is:

```sh
brew tap BradGroux/tap
brew install --cask dm-annotate
```

## Clone

```sh
git clone https://github.com/bradgroux/dm-annotate.git
cd dm-annotate
```

## Run from source

```sh
swift run dm-annotate
```

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

The generated app bundle is unsigned. Release builds should be signed and notarized before broad distribution.

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
