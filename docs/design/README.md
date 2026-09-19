# Blocks: a quiet island

Blocks borrows Dynamic Island’s compact/expanded relationship: a glanceable clock beside the hardware notch, a pill for capture, and a rounded island for choosing or controlling a session. The physical notch stays unobstructed. Displays without a notch use a capsule.

## Palette and geometry

| Role | Value |
|---|---|
| Canvas | `#07090B` |
| Surface | `#111416` |
| Raised surface | `#161B1D` |
| Focus / primary action | `#A6D6C4` |
| Capture | `#BAB0E3` |
| Pause / last 30 seconds | `#E8BD7A` |

Most pixels remain neutral. Mint marks session progress and primary actions; lavender marks capture; amber marks pause or low time. Color always has another signal: a timer, pause, or checkmark symbol, a named action, or a project label. Existing project colors remain consistent across reports and tasks.

SF carries text, SF Mono keycaps, and tabular digits the clock. Controls use 12pt corners; grouped content 16–20pt; popups 22–24pt continuous corners. Black islands have a faint state-colored rim. Text stays left aligned, time values right aligned.

```
Notch       close / pause    [hardware gap]    progress ring / clock
Capture     capture icon    [type a thought]                 esc / ↵
Start       focus icon      [type a task]
                            captured suggestions
            duration / project                              ↑↓ / ↵
Running     progress ring   task                             clock
            pause / resume
            extend by 25 minutes
            show / hide notch bar
            abandon
            esc                                              ↑↓ / ↵
```

Repeated state headings and introductory prose are removed. The session ring shows real elapsed progress and changes to pause/checkmark. Action names and destructive explanations stay written; icons have accessibility labels and tooltips. Keyboard hints stay visible.

## Motion

- Popups and the notch enter with a 280ms ease-out and an 8pt downward settle.
- Dismissal takes 180ms, fading and lifting 6pt. Click-away still dismisses without submitting or reactivating the previous app.
- Expanded popups resize from their top edge over 220ms.
- Exiting windows immediately stop accepting clicks and keystrokes. An animation revision prevents an old exit completion from hiding a rapidly reopened window.
- Reduce Motion uses only a 100–120ms fade, with no displacement or resize animation. Symbol replacement and progress animation respect the same setting.
- The menu popover retains its native AppKit transition.

Motion belongs to the actual AppKit windows, so exits remain visible before the window is ordered out. Timer refreshes do not replay the entrance. The clock’s physical notch alignment is unchanged at rest.

## Keyboard and research

[Apple’s Dynamic Island design guidance](https://developer.apple.com/videos/play/wwdc2023/10194/) informed the rounded shapes, compact/expanded hierarchy, and glanceable state. This is a native macOS interpretation, not an ActivityKit widget.

[Apple HIG: Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards) and [Raycast’s shortcut conventions](https://manual.raycast.com/keyboard-shortcuts) informed visible key hints and familiar commands. Tasks/Distractions use ⌘1/2; ⌘N opens session controls; ⌘, opens Settings; ⌘[ / ⌘] navigate report periods. Existing configurable global shortcuts summon start and capture. Tab traversal follows macOS Keyboard Navigation settings.

[NSAnimationContext](https://developer.apple.com/documentation/appkit/nsanimationcontext/runanimationgroup(_:completionhandler:)) supplies native window animation and completion handling. Native menus and child popovers remain part of their parent interaction.

## Verification

`./scripts/preview.sh` renders native surfaces from isolated sample data, including the minimum review window size. `./scripts/smoke.sh` checks lifecycle/persistence, popup dismissal, rapid animation interruption, and reduced-motion geometry. `./test.sh` checks the core engine.

Physical notch alignment, fullscreen Spaces, and perceived motion on different refresh-rate displays still need hardware acceptance testing.

The running popup offers four keyboard-selectable actions. Extending adds 25 minutes to the same session, preserves elapsed focus and pause state, and leaves the default session length unchanged. The notch toggle reflects this session’s current bar visibility. Abandon stays last and retains its optional reason field.

The Tasks tab (⌘1) contains session history and time breakdowns. Distractions (⌘2) keeps unresolved items and shows resolved items dimmed and struck through for 24 hours after resolution. The timestamp persists across restarts; expired resolved items are removed on launch or the next timer tick. There is no Archive page. Unresolved distractions do not expire, and resolved items are excluded from start suggestions. Existing append-only history remains on disk.

The session popup combines an animated progress ring with remaining time and the total planned duration, including extensions. The menu popover shows the same total. The finished-session extension remains a button, without a local or global shortcut.

Click-away dismissal observes left, right, and other mouse-button presses in Blocks and other applications while a popup is open. It does not require a focus change, does not swallow the original click, and preserves child-popover and menu interactions. Monitoring stops on dismissal. The menu-bar logo uses the same SF Symbols `timer` glyph as the popup, rendered as a template for light and dark menu bars; pause and completion retain their state glyphs.
