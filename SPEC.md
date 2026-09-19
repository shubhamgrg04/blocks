# Blocks

A personal macOS menu bar app for focused work blocks.

**Status:** built and in use. Amended 2026-09-14 ([ADR 0001](docs/adr/0001-remove-the-break.md)) and 2026-09-15 ([ADR 0002](docs/adr/0002-queued-intents.md)).
Domain vocabulary lives in [CONTEXT.md](CONTEXT.md).
**Scope:** personal use only. Not distributed, not sold, not signed for anyone else's machine.

---

## Current behaviour — 2026-09-19

The following changes supersede the older design decisions below wherever they differ:

- **One task, one session.** Tasks have persistent identities, optional project tags, and a done/open state, and each one holds exactly one session. Starting the same words again creates a new task; there is no "focus again", and the start prompt offers queued intents only. Tasks recorded before this rule keep the sessions they already have.
- A session records the task ID, title, project snapshot, and charged focus seconds. Reports resolve a session's project through its task rather than through that snapshot, so retagging a task moves its recorded hours; the snapshot is never rewritten and is the fallback when the task is gone. There is no honesty takeover, next-session prompt, automatic start, or warning sound. The start shortcut remains user-initiated.
- **The boundary offers to extend.** At zero the session is held unwritten in a `finished` phase for five minutes: the menu bar reads **Done**, the notch timer reads **Done** in its right wing, the popover offers **Extend 25 minutes** (⇧⌘E, a third global shortcut) and **Finish now**, and nothing takes keyboard focus. Extending reopens the *same* record — one start, one end, `plannedSeconds` grown by 25 minutes — rather than opening a second session. Nothing is charged while the offer stands. It is closed by accepting, by **Finish now**, by starting another session, by the five minutes elapsing, or by a relaunch, all of which write the session as completed at its boundary.
- Tasks live in `state.json`. Older history is grouped by exact title and project without rewriting append-only logs. Legacy record IDs preserve task membership after retagging. An old checking checkpoint completes on launch.
- **Blocks is positioned as the keyboard-first focus buddy for getting things done consistently.** Every step of a session — start, length, task, capture, extend, queue — is reachable from the keyboard alone, and the product argument is repeated showing up rather than one heroic day. The buddy is the app; there is no character, mascot, or animal anywhere in it.
- **One session length, and it lives in Settings.** The default is 25 minutes, adjustable 1–180 with a stepper. It applies to every session started after it changes; a session that wants something else means changing the default first. The start prompt offers no length control at all — it asks what the session is for and nothing else. (The three named kinds on ⌘1/⌘2/⌘3 were tried and removed: a second decision at the start moment, in the way of the one keystroke that matters. A state file from that build decodes to the minutes its kind implied.)
- There is no audio of any sort: no music library, no soundscapes, no warning sound. The 30-second warning is the menu bar digits turning orange, silently.
- A **distraction** is what the app used to call a parked thought: the vocabulary is "capture a distraction", "resolve", "expire", everywhere in the interface. The stored names did not move — `parking.jsonl`, and the `parked` keys inside `state.json` and `blocks.jsonl` — because renaming them would orphan records already written.
- A non-activating, click-through **notch timer** is exactly as tall as the notch and flush with the top of the screen, at `NSWindow.Level.statusBar` so it covers the menu bar behind it: its top and bottom edges are the notch's own, and what grows during a session is the notch's width. It is built around the notch's real bounds — `auxiliaryTopLeftArea.maxX` to `auxiliaryTopRightArea.minX` — leaving that span empty, with a close button in the left wing and the time left in the right; the boundary reads **Done** there, and the last thirty seconds turn the digits orange. A screen without a notch gets the same bar at menu bar height, centred, with no gap. There is no progress bar, status line, or task text: nothing else fits at that height. The close button hands the clock back to the menu bar for the rest of that session — a dismissal, not a change of setting, so the next session starts with the bar again. The panel takes mouse events and accepts the first click so the button works while Blocks is in the background, and still never activates Blocks or takes the keyboard. It appears only during a session. Screen changes recalculate its position.
- **One clock at a time.** Settings asks one question with two answers: the session clock is the **notch bar** or the **menu bar**. The menu bar is the fallback everything lands on — it needs no particular hardware and cannot be closed — so with the bar off or closed by hand it carries the digits exactly as it did before; whenever the bar is on screen the menu bar keeps its icon (the pause glyph while held) and shows no digits. **Done** at the boundary is not suppressed, because it asks for an answer rather than counting. The menu carries a **Show/Hide the notch bar** toggle for as long as a session is open, so a bar closed by hand has a way back and a session can move its own clock without a trip to Settings; that move lasts the session, and the next one starts wherever the setting says. The three older placements (auto, always, off) are read as the two: auto and always ask for the bar, off for the menu bar, and the file is still written in the older spelling alongside the old boolean.
- Review contains Reports, Tasks, and Archive tabs. Reports provide day, rolling seven-day, and rolling thirty-day ranges, previous-period navigation, project filtering, stacked daily focus bars, project totals with shares, and a session timeline. Selecting a day filters its timeline; selecting a project total filters to that project.
- **Project tagging is one chip.** The same control assigns a project in the start prompt, the task shelf, and the session timeline: a capsule showing a colour dot and the name, opening a menu of existing projects plus "New project…". The start prompt also offers the three most recently used projects as pills on ⌘1/⌘2/⌘3. A project's colour follows its name rather than its position in a list, and collisions inside the live set are resolved deterministically, so a colour means the same thing week to week.
- Reports include charged time from partial sessions and exclude pauses and sleep. A whole session belongs to its end date. Legacy completed records use planned duration; legacy partial records can only estimate duration from their timestamps and pauses.
- Existing pause/reset, distraction expiry, queue/archive restore, hotkey, login, and durable write behaviour remain.

### Acceptance checks

1. Start a task with a project and complete its session. Start the same words again: it is a second task with its own session, and both appear under the project filter.
2. Leave work queued when the timer ends. No window takes focus and no next session begins. Invoke the start shortcut to choose work again.
3. Retag a task from the shelf or from a row in the session timeline. Its recorded sessions move to the new project in the totals, the breakdown, and the stacked bars, while `blocks.jsonl` keeps the tag each session was written with.
4. Start a session with only the keyboard, from the global shortcut to Return: it runs for the default length and nothing asks about time. Change the default in Settings and start again; the new session takes the new length and the one already running keeps its own.
5. Check the notch timer on a notched display, external display, fullscreen Space, and after unplugging a display: its top and bottom edges are the notch's, the gap sits on the hardware, and it never takes keyboard focus. Close it from another app's window and confirm the click lands, the bar goes, the menu bar digits return for the rest of that session, and the menu's toggle brings it back; the next session starts wherever the setting says. Hold and let go from the bar's own button and confirm the clock stops and starts without a prompt. Walk both placements, confirming the digits appear only when the bar does not, and enable Reduce Motion.
6. Navigate report dates, project filters, day selection, task completion/reopening, and task history using real records, including partial sessions.
7. Let a session reach zero and leave it: the menu bar reads Done, no window appears, and it files itself five minutes later. Repeat, extending with ⇧⌘E: one record, 50 minutes planned. Repeat again, quitting during the offer: the session is written at its boundary on the next launch.
8. Launch with older state/history in an isolated data directory; verify preserved history, migrated tasks, and one-time completion of a saved checking or finished phase.

`./test.sh` covers the core lifecycle, persistence, task identity, project snapshots, migration, session lengths, and focused-time accounting. `./scripts/preview.sh` renders native light/dark UI with isolated sample data. Physical notch/fullscreen behaviour still needs a hardware pass.

## Earlier design record

The sections below document the prior design and its rationale; the current behaviour above takes precedence.

## 1. Premise

Blocks's core mechanism is **deferral, not enforcement**.

Writing a distraction down is what makes it possible to not act on it. When a stray impulse surfaces mid-task — look something up, check a feed, answer a message — it can be dismissed cheaply because it has been captured somewhere real and will still be there afterwards. Everything in this app exists to protect that move.

> **Amended.** This section originally rested the mechanism on a *guaranteed near-term break*: a known, soon, sanctioned slot that made capturing cheap. The break was removed in [ADR 0001](docs/adr/0001-remove-the-break.md); captured distractions now live in the menu bar popover and are reviewed at will. The ADR records what that costs and the symptom that would justify reversing it.

Blocks therefore **blocks nothing and watches nothing**. It has no site blocker, no app blocker, no activity monitoring, no screenshots, no frontmost-app detection. The user is not fighting compulsion — they are managing a queue, and an adversarial tool would break a system that currently works cooperatively.

### Failure modes being addressed

| Mode | Mechanism in Blocks |
|---|---|
| **Distraction pull** — reflexively opening a distraction mid-task | The capture hotkey, and a list that stays one click away in the menu bar |
| **Time blindness** — hours vanish, elapsed time isn't felt | The boundary and the honesty check, arriving whether or not the time was watched; the menu bar clock for when it is |
| **Task thrash** — working, but on six things, switching constantly | Declared intent at block start + the honesty check at block end |

### Explicitly out of scope

- Any form of blocking or filtering. Considered and rejected — see §8.
- ~~Task management. Intents are one line of freeform text; Blocks is not a todo app.~~
  **Amended 2026-09-15.** Blocks keeps an ordered, persistent queue of **pending intents** (§2a).
  This is task management, admitted as such rather than renamed — see [ADR 0002](docs/adr/0002-queued-intents.md),
  which records the risk and what would justify reversing it. Still out of scope: due dates,
  priorities, projects, subtasks, or anything that turns an intent into more than one line.
- Integrations with Things / Todoist / Linear / calendar.
- Multi-user, sync, accounts, cloud, telemetry.
- Distribution to anyone else.

---

## 2. The block

| Property | Decision |
|---|---|
| Length | Fixed and configurable in Settings. Default 25 minutes. **Not** chosen per block. (Briefly three named kinds pickable at the start prompt on 2026-09-19; reverted the same day — see the current behaviour above.) |
| Intent | One line of freeform text, typed at block start. Required. |
| Monitoring | None. The app has no knowledge of what the user is doing. |

### Lifecycle

```
  idle ──start──▶ running ──30s left──▶ warning ──▶ [honesty check] ──▶ idle
                    │  ▲
                 pause │ resume
                    ▼  │
                  paused ──2nd stop──▶ reset (block dies, logged)
                    │
                 abandon ──▶ logged as abandoned
```

**Start.** Prompt for the intent. One line, no structure. If any intents are queued they are
offered as suggestions beneath an empty, focused field: ↑/↓ chooses one, typing filters them,
and typing something else ignores them entirely. Starting from a suggestion removes that one
from the queue and leaves the rest.

**Last 30 seconds.** The clock's digits turn a steady orange. (The sound this section described is gone along with all other audio.) This is a *warning*, not the boundary. The user gets to finish the sentence they're writing.

**Amended 2026-09-19.** The boundary no longer writes the session immediately: it holds it for five minutes with an offer of 25 more minutes. See the current behaviour above.

**End — the honesty check.** A single screen: *"You said: `<intent>`. Did you?"* → **Yes / Partly / No**, one keystroke each. This is the only mechanism in the app that compares declared work to actual work, and it is what keeps the history surface truthful. Without it the log records intentions and never outcomes.

Answering completes the block, writes it to the log, and returns Blocks to idle. The recorded end time is the **boundary** — when the planned time reached zero — not when the check was answered, which may be much later if the screen sat unattended.

**Hold.** The pause button on the notch bar stops the clock and the play button starts it again. Nothing is asked for and nothing is spent: a session can be held as often as it likes, and held time is excluded from focus duration like any other pause.

**Pause.** The reasoned kind, from the menu. The reason must be **typed before the timer stops**. Capped at **one pause per block** — holds do not count against it, and a reason given while already held lands on that stretch rather than opening another. A second stop resets the block to zero.

> The six seconds of typing is the actual mechanism — enough friction to make the user notice they are leaving, which is the only thing needed. The reset is a backstop so the cap means something.

**Abandon.** An explicit, always-available action that ends the block and logs it as abandoned with a reason. It exists so that quitting the app never becomes the de facto escape hatch that also erases the evidence.

**Interruption by reality.**
- Block state persists to disk on every tick and resumes on relaunch.
- **Sleep pauses the timer.** Wall-clock would lie — the user was not working.
- Lid close / display sleep behaves the same as sleep.

---

## 2a. Pending intents

An intent can be typed before there is a block to put it in. The start shortcut opens a queueing
prompt while a block is running; the queue is offered back at the next boundary.

| Property | Decision |
|---|---|
| Depth | Unbounded and ordered. Not a single slot — see [ADR 0002](docs/adr/0002-queued-intents.md) |
| Lifetime | No expiry. A plan does not go stale the way an impulse does |
| Consumed by | Starting a block from it, or removing it. Nothing else |
| Removal | Archives to `intents.jsonl`, restorable for thirty days. Never destroyed |
| Survives | Quit, relaunch, abandon, and reset |
| Auto-start | Never. The prompt is always shown; the boundary always takes a keystroke |

After abandon or reset Blocks returns to idle in silence however much is queued — nothing should
start a block that was just walked away from. Only an honesty answer offers the next intent, and
only when the queue is non-empty; an empty queue returns to idle as before, which is the one
remaining place a working day is allowed to end.

## 3. Between blocks

**Nothing.** Answering the honesty check returns Blocks to idle. There is no interval, no timer, and no screen between one block and the next; the next block starts when its intent is typed.

Removed in [ADR 0001](docs/adr/0001-remove-the-break.md). Blocks previously ran a timed, skippable break here that opened with the captured list. That screen was the only place distractions were ever shown, which is why they moved to the menu bar popover (§6).

---

## 4. Capturing distractions

A global hotkey opens a small text field anywhere, over anything. Type a few words, press return, it vanishes. Total interaction budget: under three seconds.

- Both shortcuts are Carbon hot keys on one handler, told apart by the `EventHotKeyID` carried on the event. Carbon reports a clash between Blocks's *own* two shortcuts (`eventHotKeyExistsErr`), but **not** a clash with macOS or another app: ⌘Space, ⌃⌘Space and ⌘Tab all register cleanly and then never fire. Measured, not assumed. This is a known trap, deliberately left unaddressed.
- The capture panel must **activate Blocks** when it opens: keystrokes are delivered to the active application, so a panel summoned by an accessory app is visible but untypeable until Blocks activates. Order the panel in *first* and activate *second*, so a `fullScreenAuxiliary` panel already on screen keeps activation from switching away from a fullscreen space. Dismissal reactivates whatever app capture interrupted — capture must leave the user where it found them.
- **Initial focus must be claimed from AppKit, not SwiftUI.** An `NSHostingView` builds its subviews before it has a window, and SwiftUI does not call `updateNSView` again once the panel is shown. Every SwiftUI-side approach — `@FocusState` set in `onAppear`, `defaultFocus`, or a window check inside `updateNSView` — therefore runs while `window` is still nil and is silently dropped, leaving a field that must be clicked. Blocks owns the `NSTextField` and calls `makeFirstResponder` from `viewDidMoveToWindow`, the one moment the field is guaranteed to be in a window. Verified, not assumed: the first responder becomes the field editor even before the panel is key.
- Implemented with Carbon `RegisterEventHotKey`, which requires **no Accessibility permission**. Do not use `NSEvent.addGlobalMonitorForEvents` — it needs a TCC grant and would break Blocks's zero-permission property (§7).
- Captured distractions surface in the menu bar popover, and stay there until resolved or expired.
- **Items auto-expire after seven days** into the log. Expiry prevents the list becoming a guilt pile the user starts avoiding; a week is long enough that a distraction captured on Monday survives to a quiet Friday. (Originally 24 hours, on the reasoning that "if it wasn't wanted a day later, it was never wanted" — that proved too aggressive in use.) Pending intents (§2a) have no expiry.

The archive of captured distractions is the most interesting data Blocks produces — a record of exactly what pulls at the user's attention, which is currently invisible to them.

---

## 5. The clock

This section used to argue the opposite of what Blocks now does, and the honest record is to say
so rather than redefine the terms until both fit.

The original claim: time blindness is a **perception** problem, not an information problem, so
the answer had to be perceived rather than read — "a menu bar countdown fails because it must be
looked at, and looking at it is precisely what doesn't happen." The ambient bar was built on
that claim: a thin bar inset under the notch, or along the bottom edge of every other display,
shrinking as the block's time passed.

**That claim is conceded, not answered.** The ambient bar has been removed. The countdown is a
number you look at, and Blocks no longer claims to solve time blindness by perception — what it
relies on instead is the boundary arriving on its own, and the honesty check being asked whether
or not the time was ever watched. What this costs is set out in
[ADR 0003](docs/adr/0003-remove-the-ambient-bar.md), along with the symptom that would mean the
trade was wrong.

The clock is the menu bar title itself, not something behind a click:

| State | Treatment |
|---|---|
| Idle | The icon alone, no text — the text slot means "a block is running" |
| Running | Bare `mm:ss` in monospaced digits, no icon |
| Last 30 seconds | The digits turn a steady orange (§2), no pulse |
| Paused, or the machine asleep | The pause glyph returns beside greyed digits — a frozen number must never read as a live one |

Implementation notes:

- Blocks owns an `NSStatusItem` and assigns `button.attributedTitle` on every tick. A SwiftUI
  `MenuBarExtra` label is **not** sufficient: the status bar renders it as a template image,
  which drops the text, strips the colour the warning depends on, and leaves the refresh to
  SwiftUI's discretion. This is what hid the countdown in the first place.
- The popover is an `NSPopover` measured from its content each time it opens, since the queue
  and the distraction list vary in length.
- The popover is dismissed whenever a prompt, a capture, the honesty check, Review, or Settings
  opens — it must never be left behind a takeover.

---

## 6. Goal, data, surfaces

### Goal

- A **daily** configurable target (e.g. 9 blocks).
- Only **completed, un-abandoned** blocks count.
- A **"No"** on the honesty check **still counts** — the time was served honestly.
- **No streaks.** A long streak invites a fake 11:40pm session to protect it, and one honest sick day takes out both the streak and often the habit.
- A rolling **7-day sparkline** instead: a good week stays visible without a bad day becoming a catastrophe.

### Data

Append-only JSONL, one line per block, at `~/Library/Application Support/Blocks/blocks.jsonl`.

```json
{
  "id": "uuid",
  "start": "2026-09-13T09:00:00+05:30",
  "end": "2026-09-13T09:25:00+05:30",
  "intent": "refactor the sync layer",
  "plannedSeconds": 1500,
  "outcome": "completed",
  "check": "partly",
  "pauses": [{"at": "...", "seconds": 90, "reason": "doorbell"}],
  "parked": [{"at": "...", "text": "look up NSScreen notch API", "resolved": false}]
}
```

The `parked` key holds what the app now calls distractions; the stored name is unchanged so older records stay readable.

`outcome` ∈ `completed` | `abandoned` | `reset`. `check` ∈ `yes` | `partly` | `no` | `null`. A completed block is written at the honesty answer; nothing about it is learned after that.

Records written before ADR 0001 carry a `breakSkipped` field, which is now ignored on read. A `state.json` naming the retired `onBreak` phase decodes as `idle` rather than failing — a retired phase must never be able to disable the app.

Distraction archive events go to `parking.jsonl` (named before the rename, and kept), removed-intent events to `intents.jsonl`, both append-only and both carrying a per-event `id`.

Live state (for crash/quit recovery) goes in a separate small `state.json`, rewritten on tick. Every key in it decodes with a default fallback: a key added by a later build must not fail the decode, because a failed decode disables Blocks on a file Blocks wrote itself.

### Surfaces

**Menu bar popover** — today only. Progress dots (6/9), current intent, the **pending intent queue** (§2a) with a control to remove one, and the **distraction list**: every unresolved one with a control to resolve it. This is the only place a captured distraction is seen between capture and expiry, which is the cost ADR 0001 accepts.

**Review window** — one continuous scroll, opened from the menu. Top half is where you are: the 7-day sparkline, today's blocks, the pending intent queue, and the distraction list — the last two fully interactive, so a long list can be worked through somewhere bigger than a popover. Below a `HISTORICAL` divider: the distraction archive and removed intents, each restorable.

Renamed from "History" and no longer *purely retrospective*, which is what it was originally specified as. It holds live, mutable state now, and the divider is what keeps that legible.

**Restores and the append-only rule.** Archive files never have lines removed, so restoring appends a `restored` event rather than deleting the original. An item's current standing is the disposition of its **latest** event — which is why each event carries its own `id` and deduplication is per event, not per item. A single thought can accrue `expired`, `restored`, `resolved` over its life, and all three stay on disk.

Removed intents are restorable for **thirty days**; the file keeps every record, as every other Blocks log does, so it is the restore window that closes rather than the history.

**Settings window** (⌘,) — session length, daily target, and all three shortcuts: **capture a distraction** (⌘/ by default), **start a block** (⇧⌘/) and **extend a finished session** (⇧⌘E). An `NSWindow` owned by Blocks, **not** a SwiftUI `Settings` scene: `SettingsLink` and `openSettings` only *order* their window forward, which is invisible in an accessory app that is not frontmost, so a second ⌘, appeared to do nothing. Owning the window lets Blocks activate first, and guarantees the window is key so the shortcut recorder receives key events at all.

Per-intent aggregation ("6 blocks this week on 'sync layer'") is deliberately deferred. Freeform strings won't group cleanly; revisit after a month of real data shows whether they're groupable.

---

## 7. Stack and build

**Swift + SwiftUI.** `MenuBarExtra` for the menu bar, `NSWindow` + `NSHostingView` for the overlay and takeover screens, Carbon for the global hotkey.

**No Xcode.** Swift Package plus a `./build.sh` that:
1. `swift build -c release`
2. Assembles the `.app` bundle (Info.plist, icon, binary)
3. Self-signs with a locally generated code-signing certificate
4. Installs to `/Applications`
5. Registers login-launch via `SMAppService.mainApp.register()` on first run

Command Line Tools only (~700MB), no IDE, one command. The user does not write Swift and will not open the source; the build must never require them to.

> **Self-signing matters.** Ad-hoc signing (`codesign -s -`) derives the app's identity from its hash, so it changes on every build and macOS treats each rebuild as a new unidentified app. A locally generated self-signed cert, imported into the login keychain and trusted for code signing, keeps the identity stable across rebuilds. No Apple account needed. (`openssl pkcs12 -export` requires `-legacy` or the keychain import fails silently.)

### Permissions: none

Blocks requires **zero entitlements and zero TCC prompts**. No Accessibility, no Automation, no Screen Recording, no Full Disk Access, no Network Extension, no paid Developer Program membership. This is a deliberate design property: it means nothing to grant, nothing to re-grant after rebuilds, and nothing that breaks against a macOS update.

---

## 8. Rejected, with reasons

Recording these so they aren't relitigated.

| Rejected | Why |
|---|---|
| Site/app blocking of any kind | User isn't fighting compulsion; a blocker makes an adversarial relationship out of a cooperative system that works |
| `NEFilterDataProvider` content filter | Restricted entitlement — needs a $99/yr Developer Program membership and a provisioning profile, or SIP **and** AMFI disabled (Permissive Security on Apple Silicon). Not worth it for a personal timer |
| Screen Time / FamilyControls / ManagedSettings | **Does not exist on macOS.** iOS/iPadOS/visionOS only; the Mac Catalyst listing fails at runtime with a sandbox error |
| `/etc/hosts` + `pf` blocking | Moot once blocking was rejected. Also leaks through DNS-over-HTTPS and iCloud Private Relay |
| Mid-block "still on task?" prompt | A prompt that fires mid-flow to ask whether you're focused is self-defeating |
| A length picker at the start prompt | Two decisions where the product only has one. The start moment is worth protecting: what you are working on is the question, and how long is a setting you touch a few times a year |
| A boundary panel asking extend-or-finish | Same objection one step later: a panel at zero takes the keyboard from whatever the extra minutes were for. The offer is made in the menu bar, the popover and the notch, and it answers itself |
| Repeating a task ("focus again") | A task that collects attempts turns the record into a scoreboard for one piece of work. A session that needs longer is extended; a session started tomorrow is tomorrow's task |
| Fixed 25/5 pomodoro branding | The intervals are arbitrary, and after ADR 0001 there is no 5 — a block is a bounded stretch of declared work, nothing more. 25 minutes survives as one of three offered lengths, not as the product |
| A bundled music and soundscape library | Removed 2026-09-19. Loops, volume, and a track picker are a second product living in the menu of a focus timer, and the good ones already run in a separate app the user already has |
| Streaks | Invites dishonest sessions; one bad day destroys the habit |
| Task list / todo integrations | Building one turns Blocks into a todo app with a timer feature |
| Electron / Tauri | 150MB and a battery-draining background process, in a focus app. Native is smaller and the overlay work drops to AppKit either way |

---

## 9. Known weaknesses

1. **Task thrash is thinly addressed.** After rejecting detection and the mid-block challenge, the only interventions are declaring an intent and being asked at the end whether it was met. Nothing catches drift in the moment. This may be the right trade — every alternative interrupts flow — but it is the failure mode most likely to persist.
2. **The pause penalty can't distinguish a fire alarm from a rabbit hole.** With no detection, a reset punishes both identically. The symptom to watch for: avoiding the app entirely on days that might get interrupted.
3. **Captured distractions no longer have a guaranteed moment.** The break used to bring the list to you; now you have to open the popover. This is the far end of the axis this list previously flagged as "skippable breaks erode the core mechanism," and it is the weakness most likely to bite. [ADR 0001](docs/adr/0001-remove-the-break.md) names the symptom and the fallback.
4. **The only signal that worked without being looked at is gone.** The ambient bar was removed in favour of the menu bar clock; everything that remains needs a glance, except the 30-second sound, which a muted Mac silences. The symptom to watch for: the boundary feeling abrupt again. [ADR 0003](docs/adr/0003-remove-the-ambient-bar.md) names the fallback.

---

## 10. Build order

Sequenced so something runnable exists from step 1.

0. `build.sh` — bundle, self-sign, install, login item
1. `NSStatusItem` with a working countdown; block length in Settings
2. Intent prompt at block start
3. JSONL logging + the honesty check
4. Capture hotkey + distraction list in the popover + seven-day expiry
5. History window, sparkline, daily goal
