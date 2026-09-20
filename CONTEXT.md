# Blocks — domain language

Blocks is a keyboard-first focus buddy: it helps its owner focus on one task at a time, queue work for later, and come back consistently, on their own terms. The buddy is the app itself — there is no character.

## Work

**Task**: A piece of work with a title and an optional project tag, saved to To do or created by starting a session, and holding at most one. It stays open until its owner marks it done. Starting the same words again is a new task.

**Session**: One bounded stretch of focus, the only one its task will have. Finishing a session does not mean the task is done.
_Avoid_: Saying a task has “sessions”. “Block” is the older name for a session.

**Session length**: The planned ceiling for a session; completing the task can end it earlier. One number, set in Settings and 25 minutes by default. A change there applies to the next session; a running one keeps the length it started with. The start strip states that default and can override it for the one session it is starting, which changes nothing about the default.
_Avoid_: Calling the override a setting. It lives for one session and is never written back.

**Intent**: The description of what a session is for, taken from its task when the session starts.

**Project tag**: An optional grouping for related tasks, assigned when a session starts or at any time afterwards. Reports group a session under its task's current tag, so retagging reorganises the history it belongs to. The session record keeps the tag it was written with — the log is never rewritten — and that snapshot is only read for a session whose task no longer exists.

**Outcome**: How a session ended: completed when its timer ends or its owner finishes the task early, abandoned early, or reset after a second stop. An abandoned session may carry a reason and may carry none — the record is what keeps the history honest, not the sentence beside it.

**Boundary**: The moment the session’s remaining time reaches zero. The session stops charging time and is held, unwritten, while the offer to extend stands.

**Extension**: Twenty-five more minutes added to the session that just reached its boundary, reopening the same record rather than starting a second session.

**Offer to extend**: The five minutes after a boundary in which an extension can be accepted. Declining it, starting another session, quitting, or letting it lapse writes the session as completed at its boundary. Nothing is charged while it stands.

**Hold**: Stopping the clock, from the notch bar's own button or the running strip. No reason, no limit, nothing ended — the time simply stops being counted until it is let go.

**Pause**: A deliberate interruption with a reason. A session permits one reasoned pause; a second stop ends it as reset. Holds are not counted against it.
_Avoid_: Reading the running strip's "Pause the timer" as this. That option, like the notch bar button it is named after, is a [[hold]] — it asks for nothing and spends nothing.

**Focused time**: Time charged while a session is running. It excludes pauses, sleep, and time while the app is closed; partial sessions still contribute.

**Daily target**: The number of completed sessions someone aims for today. Both timer expiry and explicit early completion count.

## Task queue

**To do**: The list of tasks saved for later, with pending work first and completed items available to reopen. Items stay until started or explicitly removed; they never expire.

**Queued task**: A task that has not started a focus session. It can be marked done without recording focused time, or started when no other session is running or paused.

**Add to To do**: Saving a task from the global shortcut or the To do tab, including while another task is in progress.

**Start queued task**: Moving a pending task into its one focus session. Its identity and title are preserved, and it leaves To do for Reports.

**Mark task complete**: Ending a running or paused session successfully and marking its task done. Only actual focused time counts.

## Surfaces

**Reports**: Focused time and session history, grouped by date and project.

**Task shelf**: The collection of ongoing and completed tasks, each with the session it holds.

**Clock**: The session’s remaining time. It lives in exactly one place at a time — the notch timer when that is showing, the menu bar otherwise — so a glance never finds two of them counting down.

**Strip**: A surface in the notch timer's language — black, borderless, hung under the notch, the width of a sentence and sized to its job. There are three, and never two at once.

**Add task strip**: The one-line strip the Add to To do shortcut opens, saving work for later without interrupting the current session.

**Start strip**: The strip the start shortcut opens. The intent field on its top line; beneath it the pending queued tasks, filtered as you type and arrowable, four rows before it scrolls; and a footer row carrying the session length and the project. It grows downward, because the top edge is where it hangs from the notch. With nothing queued it is two lines tall.

**Running strip**: The strip the start shortcut opens when a session is running or paused. Mark task complete is first, followed by pause/resume, extend, notch visibility, and abandon. Arrowed with ↑↓, taken with Return.

**Length chip**: The control at the start strip's bottom left. It states the default rather than asking, and opening it picks a length for that one session.
_Avoid_: Treating it as a setting, or calling the start strip's footer a form.

**Notch timer**: An optional click-through black bar, exactly as tall as the notch and flush with the top of the screen, so it reads as the notch having widened rather than as a window below the menu bar. The notch's own span is left empty; a close button sits in the left wing and the time left in the right. Closing it returns that session's clock to the menu bar without changing the setting. It carries no character and takes no keyboard focus. A pause/play button sits beside the close button and holds the clock. Settings chooses between the bar and the menu bar, and the menu toggles it mid-session.

## Retired terms

**Honesty check**: The former mandatory end-of-session question. Old answers remain in history, but a session no longer requires an answer to finish.

**Break**: The former timed interval between sessions. The owner now decides when to begin again.

**Ambient bar**: The former display-edge timer. The optional notch timer now provides a small progress indicator near the notch.

**Focus again**: The former action that started another session on an existing task. A task now holds one session; a session that needs longer is extended instead.

**Distraction / parked thought**: The former capture concept, replaced by queued tasks. Existing live entries carry over into To do.

**Focus buddy (the turtle)**: The former animated turtle companion, removed 2026-09-19 along with its notch character. “Focus buddy” now names the app’s positioning, not a creature inside it.

**Soundscape**: The former built-in library of synthesized loops and its volume, removed 2026-09-19. Blocks plays no audio at all.
