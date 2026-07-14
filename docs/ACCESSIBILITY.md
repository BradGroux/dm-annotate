# Accessibility Verification

## Toolbar State

The floating toolbar exposes one shared semantic state model in full, compact, and collapsed layouts. The full toolbar root, Compact Presenter button, and collapsed Expand button each provide the complete summary for their layout. That summary names cursor, drawing, or Safe Mode and whether pointer input passes through or is captured. It also names the current tool, the paired Whiteboard/Blackboard family and exact solid or grid background, annotation lock and visibility, color, stroke width, and text style. Collapsing the toolbar therefore hides controls without hiding the state needed to understand what the app will do.

Individual controls expose stable identifiers, current values, enabled state, and selected traits. Safe Mode keeps Cursor selected and available while unavailable drawing controls remain visible to assistive technology as disabled with the value `Unavailable in Safe Mode`. Color swatches include spoken color names, and selected colors, stroke widths, text sizes, tools, boards, lock, and hidden-annotation state do not rely on color alone.

Safety-mode, annotation-lock, and annotation-visibility transitions post one concise final-state announcement after a cancellable 250-millisecond trailing debounce. Rapid reversals replace the pending snapshot, so VoiceOver cannot be left reporting stale cursor, drawing, lock, or visibility state. Concurrent important-state changes are coalesced into one safety, lock, and visibility summary. Switching rapidly among drawing tools, boards, colors, widths, or text styles updates live AX values but does not proactively announce, avoiding VoiceOver chatter during presentation shortcuts and drawing. No toolbar accessibility transition animates.

Focused tests cover the shared summary, paired board semantics, Safe Mode disabled selection, custom-color naming, and the announcement boundary. The packaged UI smoke inspects the live AX tree in normal full, compact, collapsed, board, and Safe Mode states.

## Toolbar Help

Toolbar controls use the app's custom tooltip panel as their only visual help surface. SwiftUI's native visual help tag is not installed on those controls, avoiding a second tooltip after the pointer rests over the same item. Each control still exposes one semantic accessibility hint whether visual toolbar tooltips are enabled or disabled.

Hover feedback is immediate in horizontal, vertical, compact, and collapsed layouts. The shared panel tracks the control that most recently presented it, so an out-of-order hover-exit event from a neighboring control cannot hide the current tooltip. Turning off Show toolbar tooltips clears the panel unconditionally without removing accessibility hints. Focused ownership tests cover adjacent-control replacement, current-control dismissal, and preference-driven clearing.

## Adaptive Selected Controls

Selected toolbar controls, settings sidebar rows, stroke widths, and text sizes share `AdaptiveSelectedControlStyle`. The style uses AppKit's semantic selected-control background so the surface follows the current macOS accent and appearance. It selects black or white foreground content from the resolved background using WCAG relative luminance and applies the higher-contrast option. Selection changes are immediate and do not animate because these controls are used frequently and can be changed with keyboard shortcuts.

Inactive windows use the semantic unemphasized-selection background. Disabled toolbar items suppress the selected treatment and retain the existing disabled opacity. Increase Contrast adds a one-point outline derived from the selected foreground while AppKit resolves the semantic surface for the high-contrast appearance.

### Automated contrast measurements

`AdaptiveSelectedControlStyleTests` covers representative sRGB values for every standard macOS accent to verify the foreground-selection algorithm independently. It also resolves the actual AppKit semantic selected backgrounds for the current system accent under Aqua, Dark Aqua, high-contrast Aqua, and high-contrast Dark Aqua, in both active and inactive states. Each resolved pair must meet the same 4.5:1 minimum.

| Accent sample | Chosen foreground | Contrast ratio |
| --- | --- | ---: |
| Graphite | Black | 6.44:1 |
| Red | Black | 5.92:1 |
| Orange | Black | 9.55:1 |
| Yellow | Black | 13.89:1 |
| Green | Black | 9.45:1 |
| Blue | Black | 5.22:1 |
| Purple | Black | 5.08:1 |
| Pink | Black | 5.76:1 |

The tests also sample 101 grayscale backgrounds from black through white. The chosen foreground must meet the 4.5:1 minimum at every step.

### Automated appearance matrix

The automated semantic-color test resolves and measures each state below using the machine's current macOS accent. The independent accent sweep above verifies the WCAG foreground choice for Graphite, Red, Orange, Yellow, Green, Blue, Purple, and Pink samples. This document does not claim that a manual visual pass was performed.

| Appearance | Window | Semantic background | Automated assertion |
| --- | --- | --- | --- |
| Aqua | Active | Selected control | Resolved foreground contrast is at least 4.5:1 |
| Aqua | Inactive | Unemphasized selection | Resolved foreground contrast is at least 4.5:1 |
| Dark Aqua | Active | Selected control | Resolved foreground contrast is at least 4.5:1 |
| Dark Aqua | Inactive | Unemphasized selection | Resolved foreground contrast is at least 4.5:1 |
| High-contrast Aqua | Active and inactive | Corresponding semantic selection | Each resolved pair is at least 4.5:1 |
| High-contrast Dark Aqua | Active and inactive | Corresponding semantic selection | Each resolved pair is at least 4.5:1 |

Focused state tests separately verify that disabled unavailable toolbar actions suppress selection, Increase Contrast exposes the shared outline, and selected toolbar buttons provide immediate, non-animated pressed feedback. The shared style continues to apply the selected accessibility trait whenever its selected treatment is visible.

## Find Toolbar Motion

Every current Find Toolbar entry point is keyboard-capable or high frequency: the global shortcut, application and status menus, and command palette. They all use one static presentation policy. The toolbar is ordered front without positional movement, whether Reduce Motion is on or off. The system Reduce Motion value is read for every invocation rather than cached, so changing the preference cannot leave stale motion behavior.

Find Toolbar posts the concise VoiceOver announcement “Toolbar is visible.” The announcement is limited to once per second using monotonic process uptime, so rapid invocation remains responsive without flooding assistive feedback. There are no animation completion handlers, frame-reset timers, or delayed tasks to race with later requests.

Automated tests cover normal, Reduce Motion, and rapid repeated decisions. The packaged UI smoke invokes Find Toolbar twice and asserts that the panel frame stays unchanged and its AppKit animation behavior is disabled. A manual release check should still confirm VoiceOver announcement delivery and frontmost visibility across multiple displays with Reduce Motion both on and off.
