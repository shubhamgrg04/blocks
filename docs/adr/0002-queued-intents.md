# 0002 — A queue of pending intents

**Status:** superseded 2026-09-19 by [ADR 0004](0004-remove-the-queue.md) · accepted 2026-09-15

## Context

Starting a block requires typing an intent (SPEC §2), and until now that could only happen at
the moment the block began. Intentions formed mid-block — *next I should look at the sync
layer* — had nowhere to go. The parking shortcut was the wrong home for them: a parked thought
is a distraction being declined, and putting planned work in that list conflates the two.

A global shortcut for starting a block made the gap obvious. Pressed while a block is already
running it cannot start anything, so the question became what it *should* do.

## Decision

Blocks keeps a queue of **pending intents**. The start shortcut (⇧⌘/ by default) opens the intent
prompt when idle, and a queueing prompt while a block is running. At the next boundary — after
the honesty check is answered — the intent prompt opens with the queue offered as suggestions
and the text field empty and focused: ↑/↓ chooses one, typing filters, and typing something
else entirely ignores the queue.

Starting from a suggestion consumes that one and leaves the rest. Pending intents never expire
and persist across relaunch. They appear in the popover above the parked list, with a control
to remove one.

Abandon and reset return to idle in silence no matter how much is queued. Nothing should start
a block you have just walked away from.

## Consequences

**This crosses a line SPEC §1 drew.** That section rules out task management by name: "Intents
are one line of freeform text; Blocks is not a todo app." A single-slot *next intent* would have
stayed on the right side of it; an ordered, arbitrarily deep queue that survives restarts is a
todo list, and calling it something else does not change that. The decision was made with that
stated, and SPEC §1 has been amended rather than left to contradict the code.

**The failure mode to watch for** is the one the parking expiry already exists to prevent: the
queue grows, stops being consumed, and becomes a backlog that is avoided rather than worked.
Pending intents deliberately have no expiry, so nothing clears them but you. If the popover
starts showing a queue you never pick from, the cheapest fix is a cap or an expiry, not more
queue features.

**Blocks now has two lists of short freeform strings** whose shortcuts differ by one modifier.
Keeping them distinguishable — in language, in the popover, and in what happens to them — is an
ongoing cost of this decision rather than a one-time piece of work.

## Alternatives considered

- **One slot, a single next intent.** Stays inside SPEC §1, gets most of the benefit. Rejected
  in favour of a real queue.
- **Auto-start the queued intent at the boundary**, no prompt. Rejected: with the break already
  gone it would let blocks run back-to-back with no human decision anywhere in the chain.
- **Reuse parked thoughts for planned work.** Rejected: opposite meanings, opposite lifetimes.
