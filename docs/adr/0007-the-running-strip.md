# 0007 — The start shortcut asks about the session it would interrupt

**Status:** accepted · 2026-09-19 · amends [ADR 0004](0004-remove-the-queue.md); reverses SPEC §2's mandatory abandon reason

## Context

[ADR 0004](0004-remove-the-queue.md) removed the queue and made the start shortcut silent while
a session was running. The reasoning was that a shortcut which queues work mid-session is an
invitation to stop and plan, and that capture should be the only thing you may write down
without ending what you are doing.

That was right about queueing and wrong about the key. Reaching for "start something" during a
session is not usually a request to plan — it is the moment the session stopped being the thing
you were doing. Answering it with nothing at all leaves the user pressing a shortcut that has
no effect and gives no account of itself, which is the worst of both: the impulse is not served
and it is not acknowledged either.

There were already two honest answers to that moment in the app, and both were buried in the
menu bar popover: stop the clock, or end the session. Neither was reachable from the keyboard
without opening the popover with the pointer first, which is a real gap in an app whose
positioning is that the mouse is never required for the loop it is about.

Separately, abandoning required a typed reason — `Engine.abandon` returned nil for a blank one,
and SPEC §2 described abandon as logging "with a reason". The intent was honesty: the record
should not be a silent deletion. But a mandatory field on the way out is friction on exactly
the action that must never become more expensive than quitting the app, which SPEC §2 names as
the thing abandon exists to prevent.

## Decision

The start shortcut, pressed while a session is running or paused, opens the **running strip**:
the same black line as the other two, carrying the session's intent and remaining time, and two
options arrowed with ↑↓ and taken with Return.

- **Pause the timer** — a *hold*, not a reasoned pause. The clock stops, nothing is asked for,
  nothing is spent, and the session's one reasoned pause is still there. It reads "Pause the
  timer" because that is what the notch bar's own button has always called it. While the
  session is held the option reads **Resume the timer**.
- **Abandon this session** — reveals a single field beneath it: *Reason (optional) — Return to
  abandon*. Typing is allowed and never required. Return with an empty field ends the session
  and writes the record with no reason at all. Escape goes back to the two options rather than
  closing the strip, so choosing Abandon is never a trap.

**Starting another session is deliberately not a third option.** Abandon returns Blocks to
idle, where the same shortcut opens the start strip as usual. Beginning something else is one
keystroke further away, and it goes past an explicit ending rather than through it.

`Engine.abandon` now accepts a blank reason and stores it as none rather than as an empty
string. The menu's own **Abandon…** prompt accepts a blank reason too — the rule is that a
reason is optional, not that it is optional on one surface. Pausing is unchanged and still
demands its sentence, because there the typing *is* the mechanism rather than a note beside it.

## Consequences

A third `StripKind` joins the shared strip panel. The running strip has a list and no text
field until Abandon is chosen, so it needs something to own the keyboard: `KeyCatcher`, an
invisible view that claims first responder the moment it enters the window — the same moment
and the same reason as `PromptTextField` — and swallows unhandled keys rather than passing them
to `super`, which would answer a keystroke with the system beep.

**What this costs, stated plainly:** abandoning is now genuinely free, and the abandoned records
in `blocks.jsonl` will get quieter. The history keeps *that* a session was abandoned and how
much time it had charged, which is the part reports read. What thins out is the record of *why*
work gets left — a small companion to the distraction archive SPEC §4 calls the most interesting
data Blocks produces, and the only place the app ever asked that question. That is a real loss,
traded for making the honest exit the cheap one.

There is also a second path to the same two actions now: the popover's **Pause…**/**Abandon…**
buttons and this strip. They do not disagree, but they are in different registers and the
popover's pause is the reasoned kind while the strip's is a hold.

**The symptom to watch for:** sessions being abandoned in bursts with no reasons at all, or the
strip being opened and escaped repeatedly without either option being taken — both would mean
the shortcut is being used to *check on* a session rather than to act on one, and the answer
then is a glanceable session state, not more options on this strip.

## Alternatives considered

- **Leave the shortcut silent**, as ADR 0004 had it. Rejected: a key that does nothing teaches
  nothing, and the two actions it now offers were otherwise keyboard-unreachable.
- **Offer "Start a new session" as a third option**, ending the current one and opening the
  start strip in one step. Rejected: it makes abandoning a side effect of starting, which is
  precisely the silent deletion the abandon record exists to prevent.
- **Make the strip's pause the reasoned kind**, so the one place the shortcut reaches also
  spends the session's pause. Rejected: the request was that pausing "just pauses", and a
  reasoned pause behind a shortcut would spend something the user did not know they were
  spending.
- **Keep the abandon reason mandatory but allow a one-key "no reason" answer.** Rejected as the
  same friction wearing a hat: if blank is acceptable, Return on an empty field is the way to
  say so.
