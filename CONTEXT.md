# Blocks — domain language

Blocks is a keyboard-first focus buddy: it helps its owner focus on one task at a time, keep distractions for later, and come back consistently, on their own terms. The buddy is the app itself — there is no character.

## Work

**Task**: A piece of work with a title and an optional project tag, created by starting a session and holding exactly one. It stays open until its owner marks it done. Starting the same words again is a new task.

**Session**: One bounded stretch of focus, the only one its task will have. Finishing a session does not mean the task is done.
_Avoid_: Saying a task has “sessions”. “Block” is the older name for a session.

**Session length**: How long a session runs. One number, set in Settings and 25 minutes by default. A change there applies to the next session; a running one keeps the length it started with. The start strip states that default and can override it for the one session it is starting, which changes nothing about the default.
_Avoid_: Calling the override a setting. It lives for one session and is never written back.

**Intent**: The description of what a session is for, taken from its task when the session starts.

**Project tag**: An optional grouping for related tasks, assigned when a session starts or at any time afterwards. Reports group a session under its task's current tag, so retagging reorganises the history it belongs to. The session record keeps the tag it was written with — the log is never rewritten — and that snapshot is only read for a session whose task no longer exists.

**Outcome**: How a session ended: completed after its full planned time, abandoned early, or reset after a second stop. An abandoned session may carry a reason and may carry none — the record is what keeps the history honest, not the sentence beside it.

**Boundary**: The moment the session’s remaining time reaches zero. The session stops charging time and is held, unwritten, while the offer to extend stands.

**Extension**: Twenty-five more minutes added to the session that just reached its boundary, reopening the same record rather than starting a second session.

**Offer to extend**: The five minutes after a boundary in which an extension can be accepted. Declining it, starting another session, quitting, or letting it lapse writes the session as completed at its boundary. Nothing is charged while it stands.

**Hold**: Stopping the clock, from the notch bar's own button or the running strip's first option. No reason, no limit, nothing ended — the time simply stops being counted until it is let go.

**Pause**: A deliberate interruption with a reason. A session permits one reasoned pause; a second stop ends it as reset. Holds are not counted against it.
_Avoid_: Reading the running strip's "Pause the timer" as this. That option, like the notch bar button it is named after, is a [[hold]] — it asks for nothing and spends nothing.

**Focused time**: Time charged while a session is running. It excludes pauses, sleep, and time while the app is closed; partial sessions still contribute.

**Daily target**: The number of completed sessions someone aims for today. It measures time served, not tasks delivered.

## Distractions

**Distraction**: Something that pulled at its owner mid-session and was written down instead of acted on. It is deferred, not planned: nothing about writing one down schedules it.
_Avoid_: “Parked thought”, the former name. On disk it is still `parking.jsonl` and the `parked` key.

**Capture**: Writing a distraction down through the global shortcut. The only thing the shortcut can do mid-session, and the only thing a session accepts being told.

**Resolve**: Marking a distraction as dealt with and moving it to the archive. Starting a session on one from the start strip resolves it too — acting on a written-down thought is the other way of being finished with it, so the live list has two exits and no deletions.

**Expiry**: An unresolved distraction moving to the archive seven days after capture.

**Archive**: The record of resolved or expired distractions.

**Restore**: Returning an archived distraction to the live list, with a fresh seven days.

**Disposition**: The latest action on an archived distraction: resolved, expired, or restored.

## Surfaces

**Reports**: Focused time and session history, grouped by date and project.

**Task shelf**: The collection of ongoing and completed tasks, each with the session it holds.

**Clock**: The session’s remaining time. It lives in exactly one place at a time — the notch timer when that is showing, the menu bar otherwise — so a glance never finds two of them counting down.

**Strip**: A surface in the notch timer's language — black, borderless, hung under the notch, the width of a sentence and sized to its job. There are three, and never two at once.

**Capture strip**: The strip the capture shortcut opens. A waiting dot, the label, the field, and the one key that ends it — nothing else, on one line.

**Start strip**: The strip the start shortcut opens. The intent field on its top line; beneath it the distractions captured along the way, filtered as you type and arrowable, four rows before it scrolls; and a footer row carrying the session length and the project. It grows downward, because the top edge is where it hangs from the notch. With nothing captured it is two lines tall.

**Running strip**: The strip the start shortcut opens when a session is already running. It names the session and its remaining time, and offers the two honest answers to reaching for "start" mid-session: hold the clock, or abandon. Arrowed with ↑↓, taken with Return. Starting something else is not on it — that is one keystroke further, from idle.

**Length chip**: The control at the start strip's bottom left. It states the default rather than asking, and opening it picks a length for that one session.
_Avoid_: Treating it as a setting, or calling the start strip's footer a form.

**Notch timer**: An optional click-through black bar, exactly as tall as the notch and flush with the top of the screen, so it reads as the notch having widened rather than as a window below the menu bar. The notch's own span is left empty; a close button sits in the left wing and the time left in the right. Closing it returns that session's clock to the menu bar without changing the setting. It carries no character and takes no keyboard focus. A pause/play button sits beside the close button and holds the clock. Settings chooses between the bar and the menu bar, and the menu toggles it mid-session.

## Retired terms

**Honesty check**: The former mandatory end-of-session question. Old answers remain in history, but a session no longer requires an answer to finish.

**Break**: The former timed interval between sessions. The owner now decides when to begin again.

**Pending intent**: Work deliberately queued for a future session, entered with the start shortcut while a session ran and offered back at the next start prompt. Retired 2026-09-19: a session should not be interruptible by planning the next one. Capture is the only thing that can be written down mid-session; the start shortcut now asks about the running session instead of lining work up behind it. The stored `pending` and `pendingIntentEvents` keys are read past, and `intents.jsonl` is left where it is.
_Avoid_: “Queue”, “Up next”, “enqueue”.

**Ambient bar**: The former display-edge timer. The optional notch timer now provides a small progress indicator near the notch.

**Focus again**: The former action that started another session on an existing task. A task now holds one session; a session that needs longer is extended instead.

**Parked thought**: The former name for a distraction. Retired 2026-09-19; the stored keys keep it.

**Focus buddy (the turtle)**: The former animated turtle companion, removed 2026-09-19 along with its notch character. “Focus buddy” now names the app’s positioning, not a creature inside it.

**Soundscape**: The former built-in library of synthesized loops and its volume, removed 2026-09-19. Blocks plays no audio at all.
