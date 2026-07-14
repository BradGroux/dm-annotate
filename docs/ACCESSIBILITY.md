# Accessibility Verification

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
