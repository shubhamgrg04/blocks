# 0001 — Remove the break

**Status:** accepted · 2026-09-14

## Context

Blocks was specified around a claim: deferral works *because* a sanctioned slot is guaranteed.
A stray impulse can be parked rather than acted on precisely because there is a known, soon
moment when it may be picked up. SPEC §1 called the break "the ingredient that already works"
and said everything else in the app existed to protect it.

The break was implemented as a timed, skippable takeover screen that opened with the parked
list, with skip unlocked after a two-second beat so the list was always seen before it could be
dismissed. SPEC §3 recorded this skippability as a known risk, and SPEC §9 listed it third among
known weaknesses: "skippable breaks erode the core mechanism."

In practice the break was not used the way it was specified. Its length had been retuned once
(to six minutes), and it was being skipped. The break screen was arriving as an interruption
at the end of a block rather than as relief — a second timer imposing time pressure on the one
interval that existed to relieve it.

## Decision

Remove the break entirely. A block now runs `idle → running → checking → idle`: at the
boundary the honesty check is answered, the block is logged, and Blocks returns to idle. There
is no interval between blocks and no screen between them.

Parked thoughts, which the break screen was the only place to see or resolve, move to the menu
bar popover: a list under the progress dots, each item with the same resolve control. 24-hour
expiry into the archive is unchanged.

## Consequences

The block record loses `breakSkipped`, and with it the reason completed blocks were logged late
— they are now committed at the honesty answer rather than deferred until a break ended. The
`onBreak` phase, the break length preference, and the two-second beat are gone. `Phase` decodes
unknown values as `idle` so a state file written by the old build cannot disable the app.

**What this costs, stated plainly:** parking worked because the list *came to you* at a
guaranteed moment. It now surfaces only if you open the popover. This is the far end of the
same axis SPEC §9 already flagged as the app's likeliest failure mode — skippable breaks
eroding the mechanism — and removing the break outright goes further than skipping ever did.

**The symptom to watch for:** parked thoughts stop feeling parked. The urge to act on a
distraction returns mid-block, or the parked list grows and is never opened, or captures simply
stop happening. If any of that appears, this decision is the first place to look, and the
cheapest thing to try is *not* restoring the timer but giving the parked list a guaranteed
moment again — surfacing it at the honesty check, without a duration attached.

## Alternatives considered

- **Keep the break, remove only its countdown.** An untimed break screen, dismissed manually,
  still opening with the parked list. Preserves the guaranteed moment and drops the time
  pressure. Rejected: the requirement was to remove the interval between blocks, not to retime
  it. This remains the natural fallback if the symptom above appears.
- **Put the parked list in the History window.** Keeps the popover minimal per SPEC §6. Rejected:
  it buries the live list two clicks deep inside a window named for retrospection.
- **Show the parked list as a review screen after the honesty check.** Rejected here as the
  break wearing a different hat — but see the fallback above, which is exactly this with the
  reasoning reversed.
