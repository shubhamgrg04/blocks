# Blocks — domain language

Blocks is a keyboard-first focus buddy: it helps its owner focus on one task at a time, keep distractions for later, and come back consistently, on their own terms. The buddy is the app itself — there is no character.

## Work

**Task**: A piece of work with a title and an optional project tag, created by starting a session and holding exactly one. It stays open until its owner marks it done. Starting the same words again is a new task.

**Session**: One bounded stretch of focus, the only one its task will have. Finishing a session does not mean the task is done.
_Avoid_: Saying a task has “sessions”. “Block” is the older name for a session.

**Session length**: How long a session runs. One number, set in Settings and 25 minutes by default. A change applies to the next session; a running one keeps the length it started with.
_Avoid_: Calling it a per-session choice. Nothing at the start prompt sets it.

**Intent**: The description of what a session is for, taken from its task when the session starts.

**Project tag**: An optional grouping for related tasks, assigned when a session starts or at any time afterwards. Reports group a session under its task's current tag, so retagging reorganises the history it belongs to. The session record keeps the tag it was written with — the log is never rewritten — and that snapshot is only read for a session whose task no longer exists.

**Pending intent**: Work deliberately queued for a future session. Starting it removes it from the queue; it never starts automatically and never expires.

**Outcome**: How a session ended: completed after its full planned time, abandoned early with a reason, or reset after a second stop.

**Boundary**: The moment the session’s remaining time reaches zero. The session stops charging time and is held, unwritten, while the offer to extend stands.

**Extension**: Twenty-five more minutes added to the session that just reached its boundary, reopening the same record rather than starting a second session.

**Offer to extend**: The five minutes after a boundary in which an extension can be accepted. Declining it, starting another session, quitting, or letting it lapse writes the session as completed at its boundary. Nothing is charged while it stands.

**Hold**: Stopping the clock, from the notch bar's own button. No reason, no limit, nothing ended — the time simply stops being counted until it is let go.

**Pause**: A deliberate interruption with a reason. A session permits one reasoned pause; a second stop ends it as reset. Holds are not counted against it.

**Focused time**: Time charged while a session is running. It excludes pauses, sleep, and time while the app is closed; partial sessions still contribute.

**Daily target**: The number of completed sessions someone aims for today. It measures time served, not tasks delivered.

## Distractions

**Distraction**: Something that pulled at its owner mid-session and was written down instead of acted on. Unlike a pending intent, it is deliberately deferred rather than work deliberately planned.
_Avoid_: “Parked thought”, the former name. On disk it is still `parking.jsonl` and the `parked` key.

**Capture**: Writing a distraction down through the global shortcut.

**Resolve**: Marking a distraction as dealt with and moving it to the archive.

**Expiry**: An unresolved distraction moving to the archive seven days after capture. Pending intents do not expire.

**Archive**: The record of resolved or expired distractions and removed pending intents. Removed intents remain restorable for thirty days.

**Restore**: Returning an archived item to its live list. A restored distraction gets a fresh seven days; a pending intent keeps its original date.

**Disposition**: The latest action on an archived item: resolved, expired, removed, or restored.

## Surfaces

**Reports**: Focused time and session history, grouped by date and project.

**Task shelf**: The collection of ongoing and completed tasks, each with the session it holds.

**Clock**: The session’s remaining time. It lives in exactly one place at a time — the notch timer when that is showing, the menu bar otherwise — so a glance never finds two of them counting down.

**Notch timer**: An optional click-through black bar, exactly as tall as the notch and flush with the top of the screen, so it reads as the notch having widened rather than as a window below the menu bar. The notch's own span is left empty; a close button sits in the left wing and the time left in the right. Closing it returns that session's clock to the menu bar without changing the setting. It carries no character and takes no keyboard focus. A pause/play button sits beside the close button and holds the clock. Settings chooses between the bar and the menu bar, and the menu toggles it mid-session.

## Retired terms

**Honesty check**: The former mandatory end-of-session question. Old answers remain in history, but a session no longer requires an answer to finish.

**Break**: The former timed interval between sessions. The owner now decides when to begin again.

**Ambient bar**: The former display-edge timer. The optional notch timer now provides a small progress indicator near the notch.

**Focus again**: The former action that started another session on an existing task. A task now holds one session; a session that needs longer is extended instead.

**Parked thought**: The former name for a distraction. Retired 2026-09-19; the stored keys keep it.

**Focus buddy (the turtle)**: The former animated turtle companion, removed 2026-09-19 along with its notch character. “Focus buddy” now names the app’s positioning, not a creature inside it.

**Soundscape**: The former built-in library of synthesized loops and its volume, removed 2026-09-19. Blocks plays no audio at all.
