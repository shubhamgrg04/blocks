# Blocks: quiet company

The keyboard is the memorable element. Every surface is laid out so the thing you would reach for with a mouse has a key instead, and the visible hints — the shortcut chip on the start card, ⇧⌘E on the extend button, the ↑↓ line under the suggestions — are part of the design rather than documentation. Nothing moves until the user acts. The menu leads with the task and timer; reports make the history readable.

## Tokens

| Role | Light | Dark |
|---|---|---|
| Blue-grey canvas | `#F0F4F5` | `#202B30` |
| Surface | `#FFFFFF` | `#2A373D` |
| Ink | `#263D43` | `#EEF5F3` |
| Teal accent | `#256C68` | `#A4D4C9` |
| Pale green | `#DFEDE9` | `#344E4A` |
| Secondary ink | `#607277` | `#B2C4C7` |

SF Rounded carries short headings and timers; SF carries lists and descriptions. Data is left aligned, with tabular time values. Project colours distinguish groups wherever a project appears — chart, totals, chips — with text labels providing the same information. A colour is derived from the project's name, not its place in a list, so it survives projects being added and removed.

The first pass retained the previous cobalt/lilac card system. The revised direction changes the palette to water and shell tones and removes the mandatory full-screen boundary entirely. An earlier pass reserved the app's personality for an animated turtle; that character was removed on 2026-09-19, and what carries the character now is the typography, the cards, and how little the app asks of you. The original B remains the app and menu icon.

```
Menu                         Review                    Start prompt
status line                  reports / tasks / archive task title
start / task + countdown     dates + project filter    project pills
session target               focused time + sessions   queued work
queue + distractions         daily stacked bars        keyboard selection
reports / settings / quit    project totals            cancel / begin
                             session timeline
```

The notch timer is black to meet the physical notch, sits flush with the top edge of the screen above the menu bar, and is exactly `NSScreen.safeAreaInsets.top` tall — the notch's own height. It is positioned from the notch's real left and right edges and leaves that span empty, so what a session adds is width on either side: a close button and a pause/play button on the left, dim until the pointer finds them, and the time left on the right at 12pt, with only the bottom corners rounded to continue the curve the notch already has. Closing it is a dismissal for that session rather than a setting — the clock reappears in the menu bar, where it lives whenever the bar is not up. A screen without a notch gets the same bar at menu bar height. It is click-through and non-activating and carries no character. The progress bar and the status line were cut when the bar came down to notch height; the clock turning orange for the last thirty seconds is the only state it reports. Because it is a second clock, Settings decides which one runs — the bar or the menu bar — and while it is up the menu bar drops its digits. The menu's toggle moves this session's clock between the two. It disappears at completion without replacing the screen or asking for a response. Progress interpolation respects Reduce Motion.

At the boundary the running card keeps its shape and swaps its contents: the clock reads 00:00, the status line reads "Time's up", and two buttons appear — a filled **Extend 25 minutes** and a plain **Finish now** — with the countdown to the automatic save sitting quietly beside them. The menu bar shows a checkmark and the word Done. Nothing is coloured red, nothing animates, nothing is dismissed.

Session length is one stepper in Settings, in the same card shape as the daily target, and it appears nowhere else: the start prompt is one field and a row of project pills.

Projects are deliberately the quietest thing in the interface. They never appear as a form field: tagging is a capsule chip — a colour dot and a name — that opens a menu, and it sits at the end of a line that already exists rather than taking one of its own. The same chip does the work in the start prompt, the task shelf, and the session timeline, so an untagged stretch of history can be fixed where it is noticed. Nothing waits on a project being chosen. Blocks plays no audio at all: the 30-second warning is the menu bar digits turning orange, silently.

## Verification

`./scripts/preview.sh` renders actual SwiftUI/AppKit views from isolated sample data. `Resources/Previews` includes light/dark menus, reports, task shelf, prompts, settings, the boundary offer, and the notch timer. These are native renderings, not screenshots of the owner’s desktop.

`./test.sh` checks core behaviour, including that a session takes the default length and that an extension reopens one record rather than writing two. `./scripts/smoke.sh` checks app-level persistence and that a changed default survives a relaunch. Physical notch alignment and fullscreen Spaces remain hardware acceptance checks.

Design references: [Flumen project tagging](https://news.ycombinator.com/item?id=47069336), [iPromise notch interaction](https://ipromise.work/) (its buddy is what Blocks deliberately does not have), [Session reporting](https://www.stayinsession.com/).

API references: [NSScreen safe area](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets), [NSPanel](https://developer.apple.com/documentation/appkit/nspanel), [keyboardShortcut(_:modifiers:)](https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:modifiers:)).
