# Accessibility Validation

## Toolbar

The packaged UI smoke (`scripts/smoke-ui.sh`) identifies the one visible toolbar window and scopes every query to its single current root. It validates accessible name, role, help, value, selected and enabled state, and action contract across full, compact, and collapsed layouts, including selected tool/board, paired board family and grid style, lock, hidden annotations, named color, stroke width, text style, and Safe Mode's enabled Cursor plus visible disabled drawing controls. It transitions layouts with live `AXPress` and covers collapsed Safe Mode. Compact menu buttons must expose `AXShowMenu`, but the in-process smoke deliberately does not invoke that action: AppKit menu tracking is unsafe to self-introspect from the application under test. Opening and dismissing each compact menu with VoiceOver remains a manual release-matrix check. No keyboard or HID events are posted.

Before release, traverse the packaged toolbar with VoiceOver in each layout. Confirm that cursor versus drawing pointer behavior is clear before activation, board family and background are both spoken, each selected value is named without depending on its color or border, and rapid tool/color/width shortcuts do not produce proactive announcement chatter. Toggle Cursor/Drawing, Lock, and Visibility slowly enough to confirm their bounded announcements, then rapidly to confirm they remain usable without flooding speech.

## Settings

The packaged UI smoke (`scripts/smoke-ui.sh`) opens the real Settings window and validates the live application accessibility tree through `AXUIElement`. It checks:

- the selected Shortcuts sidebar item exposes `AXButton`, `AXPress`, `AXSelected=true`, and the value `Selected`;
- the Tools section exposes one named `AXCheckBox` for the Whiteboard/Blackboard pair, and `AXPress` hides or shows both tools atomically;
- the Command Palette recorder is present in the automatic forward and reverse key-view loop;
- the recorder is discoverable by its stable AX identifier and exposes `AXButton`, `AXPress`, and its assigned `AXValue`;
- Space and Return start recording through real window event dispatch;
- Delete clears the shortcut and changes its live AX value to `Not assigned`;
- recording publishes an observed `AXValueChanged` notification.

Automation cannot confirm the exact words VoiceOver speaks under every user verbosity setting or reproduce Accessibility Inspector's presentation. Before release, run this matrix against the packaged app with Full Keyboard Access enabled and VoiceOver or Accessibility Inspector attached:

| State | Steps | Expected result |
| --- | --- | --- |
| Settings navigation | Open Settings and move through every sidebar item with Tab and Shift+Tab | Focus follows visual order; each item speaks its section name; the current item announces selected |
| Section traversal | Traverse every control in General, Tools, Colors, Shortcuts, Community, Help, Privacy, and Diagnostics | Every control is understandable without nearby visual text; picker/color values and toggle states are spoken |
| Repeated actions | Inspect preset Apply/Delete buttons and each shortcut Clear button | Each action includes the affected preset or shortcut action name |
| Assigned shortcut | Focus an assigned shortcut recorder without activating it | VoiceOver speaks the owned action and current shortcut; focus alone does not start recording |
| Keyboard activation | Press Space, then repeat with Return | The recorder announces recording instructions immediately with no animation |
| Accepted shortcut | While recording, press a supported modified key | The new shortcut is announced and focus continues through the Settings key-view loop |
| Conflict | Assign the same shortcut to two actions | Both affected recorders announce the assigned shortcut and conflict state |
| Rejected shortcut | While recording, press an unsupported or unmodified key | The rejection reason is announced and recording continues |
| Clear | While recording, press Delete or Forward Delete | The owned action becomes `Not assigned`; its separate Clear button becomes unavailable |
| Cancel | While recording, press Escape | The original shortcut returns and normal keyboard traversal resumes |
