# dm-annotate

`dm-annotate` / **Digital Meld Annotate** is a native macOS screen annotation tool. It is MIT licensed, local-only, and built to stay lean.

The app runs from the macOS menu bar and provides a floating toolbar for drawing over any app during demos, classes, design reviews, screen shares, and recordings.

> Status: early public release. Core annotation, screenshot, shortcut, settings, session, and permission flows are implemented. GitHub and Homebrew release artifacts are Developer ID signed, notarized, and stapled.

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
- Floating toolbar with vertical/horizontal layouts, compact presenter mode, collapse, drag positioning, and find pulse
- Per-display toolbar position memory and local layout presets
- Cyan drawing-mode indicator when screen controls are active
- Select, pen, highlighter, eraser, line, rectangle, ellipse, arrow, text, laser pointer, whiteboard, and blackboard modes
- Annotation lock to prevent accidental edits during presentations
- Tool shortcuts, shortcut tooltips, and click-to-record shortcut customization
- Command palette for keyboard-first access to tools and actions
- Undo, redo, clear all, and show/hide annotations
- Text annotations with movable text, Shift+Enter multiline entry, an auto-expanding editor, and text style controls for size, weight, and color
- Placed annotation selection for move, delete, recolor, and stroke/text size edits with undo/redo
- Local annotation session save/load using `.dmannotate-session` files
- 10-color editable palette, saved/reloadable palettes, custom color picker, default color, and stroke widths from `1` through `64` px with custom entry
- Full-display and crosshair-guided region screenshots to clipboard or timestamped PNG files, with copy/save/reveal options and transparent annotation-only PNG export
- Local settings for theme, toolbar, tooltips, visible tools, screenshot destination, colors, and shortcuts
- Permission warning in the toolbar when Screen Recording or Accessibility is missing
- Diagnostics view for local issue triage
- Consumable global shortcut handling with Diagnostics warnings and duplicate shortcut detection

## Documentation

- [Usage guide](docs/USAGE.md)
- [Shortcut reference](docs/SHORTCUTS.md)
- [Architecture notes](docs/ARCHITECTURE.md)
- [Codebase audit](docs/CODEBASE_AUDIT.md)
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

The first-run onboarding window checks these permissions and links to the relevant **System Settings > Privacy & Security** panes. It refreshes when you return from System Settings, and you can reopen it from **Permissions...** in the app menu or menu bar item. Consumable global shortcuts use a native macOS event tap when permission is available; if macOS denies that tap, Diagnostics reports the failure and global shortcuts stay disabled until permissions are fixed.

## Local Preview Gatekeeper Step

> [!IMPORTANT]
> Local source-built ad-hoc bundles are not notarized. macOS Gatekeeper may block them with an "Apple could not verify" dialog.
>
> After moving the app to `/Applications`, run:
>
> ```sh
> xattr -dr com.apple.quarantine "/Applications/Digital Meld Annotate.app"
> open "/Applications/Digital Meld Annotate.app"
> ```
>
> Only do this for local builds you trust. See [Opening local preview builds](docs/RELEASE.md#opening-local-preview-builds).

## Install with Homebrew

The recommended install path is the dedicated `BradGroux/tap` Homebrew tap:

```sh
brew tap BradGroux/tap
brew install --cask dm-annotate
```

Homebrew installs use the current GitHub release artifact. Published Homebrew artifacts are Developer ID signed, notarized, and stapled.

`BradGroux/tap` is the only supported Homebrew tap for `dm-annotate`. If Homebrew reports that `dm-annotate` exists in multiple taps, remove the retired app-repo tap:

```sh
brew untap BradGroux/dm-annotate
brew install --cask dm-annotate
```

If Homebrew refuses to untap because `dm-annotate` is installed from the retired tap, migrate the installed cask first:

```sh
brew reinstall --cask bradgroux/tap/dm-annotate
brew untap --force BradGroux/dm-annotate
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

The generated app bundle is ad-hoc signed by default, but it is not Developer ID signed or notarized unless release signing is configured.

## Package a release

```sh
scripts/package-release.sh
```

Verify the generated zip and packaged app bundle:

```sh
scripts/verify-release-zip.sh
```

Run a local UI smoke check:

```sh
scripts/smoke-ui.sh
```

Optional release environment:

```sh
CODESIGN_IDENTITY="Developer ID Application: Example" scripts/package-release.sh
CODESIGN_IDENTITY="Developer ID Application: Example" \
NOTARIZE_KEY_PATH="$HOME/private_keys/AuthKey_EXAMPLE.p8" \
NOTARIZE_KEY_ID="EXAMPLE1234" \
NOTARIZE_ISSUER_ID="00000000-0000-0000-0000-000000000000" \
scripts/package-release.sh
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
