# 0004 — Remove the queue of pending intents

**Status:** accepted · 2026-09-19 · supersedes [ADR 0002](0002-queued-intents.md) · amended same day by [ADR 0007](0007-the-running-strip.md)

## Context

[ADR 0002](0002-queued-intents.md) gave Blocks an ordered, persistent queue of pending intents.
The start shortcut opened the intent prompt when idle and a *queueing* prompt while a session
ran; the queue came back as suggestions at the next start, arrowable with ↑↓.

That ADR was explicit that this was task management and that the thing to watch for was "the
queue grows, stops being consumed, and becomes a backlog that is avoided rather than worked."
It named a cap or an expiry as the cheapest fix if that happened.

The problem turned out to be earlier than the backlog. The queue gave the start shortcut a
second meaning *during a session*, and a shortcut that does something mid-session is an
invitation to stop and plan. Blocks already has one thing you are allowed to do while a session
runs — write a distraction down and let it go. Queueing was a second one, and unlike capture it
was not deferral: it was picking the work up, deciding where it went, and putting it in an
ordered list, all in the middle of the session that was supposed to be about something else.

Two mechanisms for "not now", with different lifetimes, different surfaces and different
archives, also cost the app its one-sentence explanation. [ADR 0002](0002-queued-intents.md)
defended the distinction as honest; honest it was, but it was a distinction the user had to
hold in their head at exactly the moment they had least attention to spare.

## Decision

Remove the queue entirely.

The start shortcut starts a session, and does nothing at all while one is running or paused.

> **Amended by [ADR 0007](0007-the-running-strip.md)**, the same day. Doing nothing was right
> about queueing and wrong about the key: the shortcut now asks about the session it would have
> interrupted, offering to hold or abandon it. No work can still be lined up behind a running
> session, which is what this ADR was actually about.

The queueing prompt, the suggestion list in the intent prompt with its ↑↓ handling, the "Up next"
sections in the popover and the review window, and the "Removed intents" half of the archive are
all gone. `PendingIntent`, `IntentEvent`, `Engine.queue`, `removePending`, `restorePending` and
`start(consuming:)` are gone with them.

Capture is now the only thing that can be written down mid-session, which is what ADR 0001 and
this project's positioning always claimed it was.

## Consequences

`LiveState` stops reading `pending` and `pendingIntentEvents`; a state file that still carries
them loads fine and is rewritten without them on the next save. `intents.jsonl` stops being
written and is left on disk untouched, as every retired Blocks log is. Anything still queued at
upgrade is therefore recoverable from the file by hand, and from nowhere in the app.

**What this costs, stated plainly:** the thought that arrives mid-session as *work* rather than
as a distraction now has one place to go, and it is the distraction list — a list that expires
in seven days and is framed as things you decided not to do. Planned work will be filed under
deferral, and some of it will quietly expire.

**The symptom to watch for:** the distraction list filling with things that are plainly next
actions rather than impulses, or captures being reworded to survive as reminders. If that
appears, the fix is to let a *captured* item be started as a session from the popover — giving
the one list two exits — rather than to bring back a second list and a second shortcut meaning.

## Alternatives considered

- **Keep the queue but drop the mid-session shortcut**, so intents could only be queued from the
  popover. Rejected: it keeps the whole second lifecycle, its archive and its surfaces for a
  feature no longer reachable at the moment it existed to serve.
- **Cap the queue at one slot**, the "next up" ADR 0002 rejected in favour of a real queue.
  Rejected for the reason above: the cost here is the interruption, not the depth.
- **Fold pending intents into the distraction list** as a flagged kind. Rejected: it preserves
  the two-mechanism problem and moves it inside one list, where the distinction is harder to
  see rather than easier.
