# Blocks: desktop studio

A focus app should feel inviting before a block and quiet during one. The memorable device is a set of rounded building blocks: the B mark, daily progress pieces, and weekly columns share that vocabulary.

## Visual system

| Role | Light | Dark |
|---|---|---|
| Porcelain canvas | `#F6F7FC` | `#202235` |
| Surface | `#FFFFFF` | `#2B2E45` |
| Ink | `#242744` | `#F3F2FC` |
| Cobalt accent | `#4149DB` | `#B5B8FF` |
| Lilac | `#E8E5FF` | `#3C3B63` |
| Peach | `#FFE2D3` | `#564038` |

SF Rounded carries the wordmark, headings, and timer; standard SF keeps lists and secondary text compact. List rows are 14 pt and nothing on any surface drops below 12 pt: timestamps, hints, and counts share one small size rather than the system captions. Headings are left aligned, sentence case, with no decorative labels or gradients. The timer uses tabular digits, and its digits roll rather than blink when a second passes.

Motion is a response to the pointer, never decoration. Every control lifts slightly under hover and sinks on press, on one shared spring; list rows are roomy enough to click without aiming, brighten under hover, and settle in or out when a thought is parked, resolved, or removed. Filled progress cells pop in sequence as a block completes. All of it collapses to plain opacity changes when Reduce Motion is on.

The first layout review rejected a numeric dashboard hero, and a second review replaced the slogan that followed it: a new block starts with an intent, so the idle panel leads with one large, obviously pressable start button, with the global shortcut shown beside it. A running block replaces it with remaining time and the user's intent. Weekly bars represent completed blocks; all honest answers count equally. The review window carries no heading or wordmark of its own: a two-segment tab control is its top edge, and the archive of resolved thoughts and removed intents lives on the second tab (⌘1 / ⌘2), always opening on the week.

```
Menu                      Review                     Prompt
brand / date              tabs: this week · archive  brand
start button + shortcut   seven-day block chart      direct question
                          today's outcomes           focused text field
daily progress pieces     queued work                queue suggestions
queue / parked thoughts   parked thoughts            cancel / action
review / settings / quit  (archive tab: restorable)
```

## Brand source

`Sources/Blocks/Brand.swift` is the single source of the three-brick B. The menu bar uses an adaptive template image. The app icon uses the identical geometry on a cobalt tile. Never substitute an SF Symbol for the brand mark.

## Verification

`./scripts/preview.sh` builds and renders the actual SwiftUI/AppKit views using isolated sample data in `.build/design-preview-data`. PNGs go to `Resources/Previews`. These are rendered views, not screenshots of the user's desktop. It includes light/dark menus, active and paused blocks, prompts, settings, review, and the honesty check.

Native text-field focus, Return/Escape handling, shortcut recording, and all model operations are retained. The core runner is `./test.sh`.

API references consulted: [Apple Button](https://developer.apple.com/documentation/SwiftUI/Button), [Apple ImageRenderer](https://developer.apple.com/documentation/swiftui/imagerenderer). Native controls require the NSHostingView render path used here.
