# Blocks — domain language

The vocabulary Blocks is built on. This file is a glossary, not a spec and not a design
document: it says what each word means, never how it is implemented.

## Core

**Block** — one bounded stretch of declared work. A block has a fixed planned length, exactly
one intent, and ends in one of three outcomes. It is the unit everything else counts.

**Intent** — the one line of freeform text declared at the start of a block, naming the single
thing that block is for. Not a task, not an item on a list: it is a statement of what this
stretch of time is for, and it is what the honesty check later asks about.

**Pending intent** — an intent typed ahead of time, waiting for a block to run in. Pending
intents are offered as suggestions when the next block's intent is asked for; choosing one
starts a block with it and removes it from the queue, and typing something else leaves the
queue untouched. They never expire — a plan does not go stale the way an impulse does — and
leave only by being started or removed by hand. Removing one archives it rather than destroying
it: it stays **restorable for thirty days**.

> Do not confuse a **pending intent** with a **parked thought**. Both are one line of freeform
> text in a list, and their capture shortcuts are one Shift apart, but they are opposites: a
> pending intent is work deliberately planned *to do*, a parked thought is a distraction
> deliberately *not* done. They have separate lists, separate lifetimes, and separate fates —
> a pending intent becomes a block, a parked thought becomes an archive entry.

**Outcome** — how a block ended. Exactly one of:
- **Completed** — the full planned time was served. Counts toward the daily target.
- **Abandoned** — deliberately ended early, with a typed reason.
- **Reset** — ended by a second stop after the block's one pause had been used.

**Boundary** — the moment a running block's planned time reaches zero. The boundary is when
the time was served, and is the timestamp recorded as the block's end — distinct from when the
honesty check is answered, which may be much later.

**Warning** — the last 30 seconds of a block, signalled ambiently so the boundary arriving is
expected rather than abrupt. A warning, not the boundary itself.

**Honesty check** — the question asked at the boundary: *you said `<intent>` — did you?*
Answered **Yes**, **Partly**, or **No**. It is the only place in Blocks where declared work is
compared to actual work, and it is what makes the history truthful rather than aspirational.
All three answers complete the block; **No** counts exactly as much as **Yes**, because the
thing being counted is time served honestly, not work delivered.

**Pause** — a deliberate, reasoned interruption of a running block. A pause requires a typed
reason and there is one per block; a second stop resets the block instead.

**Abandon** — explicitly ending a block early with a reason. Always available. It exists so
that quitting Blocks never becomes the escape hatch that also erases the evidence.

## Parking

**Parked thought** — a distraction captured in a few words instead of acted on. The act of
parking is Blocks's central move: writing it down is what makes it safe to not do it now.

**Capture** — the interaction that creates a parked thought: a global shortcut, a text field
over whatever is on screen, a few words, return. Under three seconds, from anywhere.

**Resolve** — marking a parked thought as dealt with. A resolution is an outcome, not a
deletion: the thought moves to the archive with its disposition recorded.

**Expiry** — a parked thought that is still unresolved **seven days** after capture leaves the
list on its own, archived as expired. The list must not become a guilt pile, but a week is long
enough that a thought parked on Monday survives to a quiet Friday. Expiry applies to parked
thoughts only; pending intents never expire.

**Archive** — the permanent record of parked thoughts that were resolved or expired, and of
pending intents that were removed. This is the most interesting data Blocks produces: a record of
exactly what pulls at attention, and of work planned and then abandoned.

**Restore** — putting an archived item back into its live list. A restored parked thought
starts its seven days over, because expiry is measured from capture and it would otherwise be
swept away again immediately. A restored pending intent keeps its original timestamp, since
nothing expires it and the useful fact is when it was first planned.

**Disposition** — what happened to an archived item: *resolved*, *expired*, *removed*, or
*restored*. Archive files are append-only, so an item does not leave the archive by having its
record deleted — a new event is appended, and an item's current standing is the disposition of
its most recent event.

## Surfaces

**Review** — the window holding everything not in the menu bar: the seven-day sparkline and
today's blocks, then the live queue and parked list, then everything finished below a divider.
Formerly called History, renamed when it stopped being only retrospective.

## Time and progress

**Ambient bar** — the thin bar along a display edge that shrinks as a block's time passes.
It is designed to be *perceived* without being *read*, because time blindness is a perception
problem rather than an information problem. It doubles as the warning channel.

**Daily target** — a number of completed blocks per day. Deliberately not a streak: a streak
invites a dishonest late-night session to protect it, and one honest sick day destroys both the
streak and usually the habit.

## Retired terms

**Break** (also called the *rest timer*) — a timed, skippable interval between blocks, during
which the parked list was shown. Removed. Parked thoughts now live in the menu bar popover and
are reviewed whenever their owner chooses. See
[ADR 0001](docs/adr/0001-remove-the-break.md) for why, and for what the removal costs.
