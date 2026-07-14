# Shortcut Reference

Shortcuts are configurable in Settings. Clear a shortcut field to disable that action.

Shortcut key names use macOS virtual key positions, so a shortcut keeps the same
physical key when the active keyboard input source changes. The recorder supports
letters, numbers, ANSI punctuation, Tab, Space, Return, Delete, F1-F20, and
navigation keys. Numeric-keypad keys are rejected so their printable symbols do
not collide with main-keyboard descriptors. Unsupported keys are
rejected instead of being saved as shortcuts that cannot run. Shortcuts containing
Control or Option can run while another app is active; Command-only shortcuts
remain app-local.

Preferences saved by an older release used characters from the keyboard layout
that was active when the shortcut was recorded. On first launch after upgrading,
those descriptors are converted once through the active input layout to the new
physical-key format. A legacy value that the active layout cannot resolve is kept
in an explicit non-dispatching legacy mode and remains visible in Settings so it
can be recorded again without silently changing which key it means. Delete and Forward Delete are separate shortcut keys;
pressing either one without modifiers still clears the recorder field.

The defaults are:

| Action | Default shortcut |
| --- | --- |
| Toggle annotation mode | `Option+Command+A` |
| Cursor mode | `Esc` |
| Collapse/expand toolbar | `Option+Command+T` |
| Switch toolbar orientation | `Option+Command+O` |
| Compact presenter mode | `Option+Command+M` |
| Find toolbar | `Option+Command+F` |
| Select tool | `Control+Option+S` |
| Pen tool | `Control+Option+P` |
| Highlighter tool | `Control+Option+H` |
| Eraser tool | `Control+Option+E` |
| Line tool | `Control+Option+L` |
| Rectangle tool | `Control+Option+R` |
| Ellipse tool | `Control+Option+O` |
| Arrow tool | `Control+Option+A` |
| Text tool | `Control+Option+T` |
| Laser pointer | `Control+Option+D` |
| Whiteboard mode | `Control+Option+W` |
| Lock/unlock annotations | `Option+Command+L` |
| Show/hide annotations | `Option+Command+V` |
| Undo | `Command+Z` |
| Redo | `Shift+Command+Z` |
| Quick color 1 | `Command+1` |
| Quick color 2 | `Command+2` |
| Quick color 3 | `Command+3` |
| Quick color 4 | `Command+4` |
| Custom color | `Control+Option+C` |
| Decrease stroke width | `Command+-` |
| Increase stroke width | `Command+=` |
| Clear all | `Option+Command+C` |
| Screenshot | `Option+Command+S` |
| Copy screenshot | `Option+Shift+Command+C` |
| Save screenshot | `Option+Shift+Command+S` |
| Region screenshot | `Option+Command+R` |
| Reveal last screenshot | `Option+Shift+Command+R` |
| Permissions | `Option+Command+P` |
| Settings | `Command+,` |
| Command palette | `Command+K` |

## Emergency shortcuts

These are intentionally not configurable:

| Action | Shortcut |
| --- | --- |
| Exit drawing controls | `Esc` |
| Quit after exiting drawing controls | double-tap `Esc` |
| Quit when app has focus | `Command+Q` |
| Safe Mode launch | hold `Shift` while launching |

## Text entry shortcuts

These apply while the inline text editor is active:

| Action | Shortcut |
| --- | --- |
| Commit text annotation | `Enter` |
| Insert newline | `Shift+Enter` |
| Cancel text entry and exit controls | `Esc` |

## Selection shortcuts

These apply while the Select tool has a selected annotation:

| Action | Shortcut |
| --- | --- |
| Delete selected annotation | `Delete` |
| Clear selection | `Esc` |
