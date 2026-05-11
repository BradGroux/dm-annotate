# Architecture

`dm-annotate` is a small native macOS Swift app. The main design goal is to keep annotation reliable during live screen sharing while keeping the codebase approachable.

## Package layout

```text
Sources/
  DMAnnotate/        macOS app, windows, menus, screenshots, settings, shortcuts
  DMAnnotateCore/    annotation models, store, preferences, shortcut text, tests
Tests/
  DMAnnotateCoreTests/
```

## Main components

| Component | Responsibility |
| --- | --- |
| `AppDelegate` | App lifecycle, controller wiring, menus, command palette actions |
| `OverlayController` | Creates transparent overlay windows for active displays |
| `OverlayView` | Pointer input, drawing interaction, text entry |
| `AnnotationStore` | In-memory annotation state, tools, undo/redo, visibility, lock |
| `AnnotationRenderer` | AppKit drawing for strokes, shapes, text, laser, whiteboard |
| `ToolbarWindowController` | Floating always-on-top toolbar panel |
| `ToolbarContentView` | SwiftUI toolbar controls and hover help |
| `ShortcutController` | Local/global shortcut monitors and emergency escape handling |
| `ScreenshotController` | Full-display and region screenshot capture |
| `PreferencesController` | `UserDefaults` persistence and preference side effects |
| `PermissionOnboardingController` | First-run and manual permission guidance |

## State model

Annotations are stored in memory as typed values:

- Pen stroke
- Highlighter stroke
- Line
- Rectangle
- Ellipse
- Arrow
- Text

The app does not persist annotation sessions in V1. Exiting clears annotations.

Preferences are persisted locally with `UserDefaults`.

## Window model

The app uses:

- A regular macOS activation policy so the app can show a top menu when active.
- Transparent always-on-top overlay windows for drawing.
- A floating toolbar panel above normal app content.
- Region selection windows for screenshot capture.

Cursor mode is click-through. Drawing tools capture pointer input on the overlay.

## Privacy model

Normal operation is local-only:

- No accounts.
- No telemetry.
- No analytics.
- No cloud sync.
- No license activation.
- No network calls.

Screenshots are only copied to the local clipboard or saved to the configured local folder.

## Dependencies

The project currently has no production dependencies outside Apple frameworks and SwiftPM.

Keep it that way unless a native framework gap clearly justifies a dependency.

## Testing strategy

Core behavior should stay testable in `DMAnnotateCore` without launching a macOS UI:

- Annotation add/erase/undo/redo.
- Shortcut normalization.
- Preference migration.
- Screenshot naming.
- Safe exit state.

Manual checks are still required for:

- Multi-display overlay behavior.
- macOS permission prompts.
- Toolbar drag behavior.
- Screen recording and screen share visibility.
- Region screenshot interaction.
