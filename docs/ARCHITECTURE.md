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
| `AnnotationRenderer` | AppKit drawing for strokes, shapes, text, laser, whiteboard/blackboard backgrounds |
| `ToolbarWindowController` | Floating always-on-top toolbar panel |
| `ToolbarContentView` | SwiftUI toolbar controls and hover help |
| `ToolbarLayoutMetrics` | Shared toolbar sizing constants and panel size estimates |
| `ShortcutController` | Local/global shortcut monitors and emergency escape handling |
| `ScreenshotController` | Full-display and region screenshot capture with region-first rendering |
| `ScreenshotFeedbackPresenter` | Compact, non-animated copy/save outcome feedback and VoiceOver announcements |
| `ScreenshotGeometry` | Testable screenshot region-to-pixel geometry |
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
- Text with content, font size, font weight, and color

Annotation sessions can be saved to and loaded from local `.dmannotate-session` JSON files. The app preserves annotation geometry, display IDs, colors, stroke widths, text styles, visibility, lock state, and whiteboard state. Loading retargets annotations to the current main display when a saved display is missing. The core session boundary applies the same annotation, point, text, style, geometry, color, and encoded-byte validation before export and after import. Store exports validate before an atomic file replacement, and live freehand strokes are progressively simplified to remain within the session point limit.

High-frequency annotation work uses explicit bounds. `AnnotationItem` owns the effective highlighter width, painted stroke radius, smoothed cubic stroke segments, and arrowhead geometry shared by AppKit rendering, painted bounds, selection, hit testing, eraser culling, and invalidation. Stroke interaction combines the painted radius, antialias tolerance, and caller-provided selection or eraser radius. Cubic hit testing uses adaptive subdivision, while chunk bounds conservatively include each segment's control hull. The store caches each annotation's display-space bounds plus 64-segment spatial chunks and updates that index across edits, load, undo, and redo. Eraser input rejects both annotation bounds and chunk bounds before detailed segment hit testing. Overlay redraws query the bounds index for the dirty region; text remains conservatively uncullable and text mutations request a safe full redraw until AppKit layout metrics are shared. Persisted freehand paths are cached by annotation ID, and targeted store invalidations evict only changed paths and redraw only their old/new regions. Freehand input uses the session-compatible 20,000-point cap with geometry-aware reduction. Laser input retains at most 240 spatially distinct samples over 1.5 seconds and owns one stable cleanup timer per overlay.

Preferences, including toolbar layout presets, are persisted locally with `UserDefaults`.

## Window model

The app uses:

- A regular macOS activation policy so the app can show a top menu when active.
- Transparent always-on-top overlay windows for drawing.
- A floating toolbar panel above normal app content.
- Region selection windows for screenshot capture.
- A nonactivating screenshot feedback panel excluded from capture and screen sharing.

Cursor mode is click-through. Select and drawing tools capture pointer input on the overlay.

## Privacy model

Normal operation is local-only:

- No accounts.
- No telemetry.
- No analytics.
- No cloud sync.
- No license activation.
- No network calls.

Screenshots are only copied to the local clipboard or saved to the configured local folder.

Successful and failed screenshot outputs produce compact native feedback. Each capture owns a sequenced feedback session and its capture display's visible frame, so stale asynchronous outcomes are suppressed and feedback stays on the originating display. The presenter uses no window animation, posts a VoiceOver announcement, opts the panel out of window sharing, and is synchronously hidden before each capture so feedback cannot leak into a subsequent screenshot.

Region capture crops the screen image before allocating its annotated render target. PNG encoding uses the existing `CGImage` directly through Image I/O, and encoding plus file writes run off the main actor after hidden capture chrome has been restored. Clipboard publication returns to the main actor because `NSPasteboard` is an AppKit boundary.

## Dependencies

The project currently has no production dependencies outside Apple frameworks and SwiftPM.

Keep it that way unless a native framework gap clearly justifies a dependency.

## Testing strategy

Core behavior should stay testable in `DMAnnotateCore` without launching a macOS UI:

- Annotation add/erase/undo/redo.
- Shortcut normalization.
- Preference migration.
- Screenshot naming.
- Screenshot crop geometry and direct PNG dimensions/alpha.
- Text move and text style normalization.
- Safe exit state.

Manual checks are still required for:

- Multi-display overlay behavior.
- macOS permission prompts.
- Toolbar drag behavior.
- Screen recording and screen share visibility.
- Region screenshot interaction.
- Screenshot feedback placement, VoiceOver announcements, and capture exclusion on supported macOS versions.
