# Inline Text Editor Contrast Test Matrix

The inline editor is a temporary control over unpredictable screen pixels. It uses a solid black or white surface selected from the calibrated preview color's display-resolved sRGB components, then uses the unchanged calibrated preview for the editor text, insertion point, border, and selection background. Selected text uses the surface color. This makes the editor independent of the content behind it. The editor snapshots the selected RGBA when entry begins, and the final committed annotation renderer is unchanged.

## Automated evidence

| Area | Matrix | Evidence |
| --- | --- | --- |
| Color contrast | Black, white, all ten default palette colors, 101 dense crossover samples from 0.35 through 0.60 including input gray 0.46, and custom mixed colors; standard and Increase Contrast | `InlineTextEditorPresentationTests` independently converts the colors applied to `NSTextView` into sRGB and requires at least 4.5:1 between the opaque editor preview and its solid surface. |
| Backing decision | Black and white extremes | Tests require black text to receive a light surface and white text to receive a dark surface. Because the surface is opaque, light, dark, grid, and live backing pixels cannot change the measured pair. |
| Caret and selection | Yellow preview with Increase Contrast | The AppKit application test requires final-color text and insertion point, final-color selection background, inverse selected text, and a two-point border. |
| Final output | Custom dark RGB with 35% alpha; palette changes while editing | Return commits the exact session RGBA value, origin, font size, and weight. A begin-change-refresh-commit regression verifies the opaque preview and annotation color remain invariant when the store color changes. |
| Keyboard behavior | Return, Shift-Return, Escape | Tests require commit, newline without commit, and cancel plus cursor recovery. |
| Positioning | Editor opened beyond the top-right overlay edges | The existing eight-point margin clamp is exercised directly. |
| Accessibility refresh | Active custom-color editor with Increase Contrast off then on | A focused refresh-seam test requires the border to change from one to two points without changing the session color or preview; the overlay observes macOS accessibility display-options changes for its lifetime. |
| Packaged app | Standard palette under Increase Contrast | `scripts/smoke-ui.sh` constructs and applies the presentation from the universal release app and rejects missing background, border, or selection chrome. |
| Capture isolation | App capture call path | `ScreenshotController` nests composition inside `OverlayController.temporarilyHideForCapture`, which orders out the entire overlay before pixel acquisition. Automated smoke cannot acquire screen pixels without Screen Recording permission. |

## Manual visual matrix

Run this matrix on a physical Mac before release. The current automated run does not claim these subjective visual checks or Screen Recording validation.

| Final color | Light page | Dark page | Light grid | Dark grid | Mixed live content | Increase Contrast |
| --- | --- | --- | --- | --- | --- | --- |
| Black | Pending | Pending | Pending | Pending | Pending | Off and on |
| White | Pending | Pending | Pending | Pending | Pending | Off and on |
| Red / yellow | Pending | Pending | Pending | Pending | Pending | Off and on |
| Blue / purple | Pending | Pending | Pending | Pending | Pending | Off and on |
| 35% alpha custom color | Pending | Pending | Pending | Pending | Pending | Off and on |

For each cell:

1. Type, move the caret through the line, and select part and all of the text.
2. Verify text, caret, selection, and border stay immediately distinguishable with no animation.
3. Press Shift-Return, Return, and Escape in separate entries.
4. Open near every display edge and verify the editor remains inside the overlay.
5. Capture while the editor is active and verify temporary editor chrome is absent while committed annotations remain.
6. Compare the committed annotation with the selected color, including alpha.
