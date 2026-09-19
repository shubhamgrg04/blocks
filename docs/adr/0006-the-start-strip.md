# 0006 — The start strip

**Status:** accepted · 2026-09-19 · applies [ADR 0005](0005-the-notch-design-language.md); reverses part of SPEC §1

## Context

[ADR 0005](0005-the-notch-design-language.md) adopted the notch timer's register as Blocks's
design language and moved capture onto it first, leaving the rest of the app in the older one
and calling that "the state of a migration rather than a resting place." Starting a session is
the next surface, and the most used.

The old start prompt was a 520pt panel centred on the screen: a 22pt heading, a full-size
field, a row of project pills, a hint line, and Cancel/Begin buttons. Like the capture panel it
replaced ceremony for what is one keystroke and a handful of words.

Two things had also gone missing from the start moment.

**Distractions had only one exit.** [ADR 0004](0004-remove-the-queue.md) removed the queue and
said, of the symptom to watch for: "the fix is to let a *captured* item be started as a session
— giving the one list two exits." With the queue gone, a thought written down mid-session that
turns out to be the next real piece of work had to be retyped from memory, because the list was
only visible in the popover and the only thing you could do there was resolve it.

**Session length had no expression at the start moment at all.** SPEC §1 is explicit that this
was deliberate: "The start prompt offers no length control at all — it asks what the session is
for and nothing else," with the note that three named lengths on ⌘1/⌘2/⌘3 were tried and
removed as "a second decision at the start moment, in the way of the one keystroke that
matters." That reasoning is sound about a *question*. It is not sound about a *statement*: the
thing actually in the way was being asked to choose, not being told what the choice already is.

## Decision

Replace the start prompt with the **start strip**, in the same register as capture: 460pt wide,
black, borderless, hung under the notch.

- **The field is the whole top line**, focused, free text, exactly as before.
- **The distractions captured along the way are offered beneath it**, filtered as you type,
  arrowable with ↑↓, four rows visible and the rest scrolled to. Starting one takes it off the
  live list the way resolving does — archived with disposition `resolved`, restorable, never
  destroyed — because acting on a written-down thought is the other way of being finished with
  it. This is ADR 0004's named fallback, taken up deliberately.
- **Two chips sit on a footer row**, below the field rather than in front of it: the session
  length and the project. The length chip *states* the default from Settings rather than asking
  — it reads `25m` with nothing chosen — and opening it picks a different length for this
  session only. Nothing written here touches preferences; Settings still owns the default, and
  the menu says so with a direct route to it. A chip carrying a choice lights up, so a session
  that is not the usual length is visible at a glance.
- **The project chip** offers existing projects, most recently used first. Naming a new one
  borrows the field itself for a few seconds — the label changes to `NEW PROJECT`, Return
  assigns it and gives the intent text back, Escape backs out — rather than opening a second
  surface with a second caret.

The strip grows downward as its list changes, because the top edge is where it hangs from the
notch and a strip that climbed the screen as you typed would be a strip you had to follow.

## Consequences

`PromptKind` loses `.intent`; what is left are the two prompts that ask for a sentence of
explanation, which is more than a strip should hold. `ProjectPills` and its pill button style
are gone with the prompt that was their only caller. Both strips now share one panel in
`Surfaces` — they are never wanted at once, and one window means one place that knows where a
strip goes and how it is dismissed.

`Engine.start` gains `minutes:` and `resolving:`. Neither writes to preferences, and `minutes`
is clamped to the same 1–180 that Settings enforces rather than refused.

**What this costs, stated plainly:** SPEC §1's claim was that Blocks asks one question at the
start moment and the answer is what you are about to do. There are now three things on that
surface. The defence is that two of them are already answered and can be ignored entirely by
typing and pressing Return — but that is a defence of a design, and the earlier decision was
made after the named-lengths version was *tried* and found to be in the way.

**The symptom to watch for:** the length chip being touched often. A default that gets
overridden most days is not a default, and the honest fix then is to change what Settings says,
not to keep adjusting it at the door. If starting a session starts taking visibly longer than
it used to — a pause at the footer rather than a typed line and Return — this decision is the
first place to look, and the cheapest reversal is to drop the length chip and keep the rest.

Also worth watching: distractions being captured *in order to* start them later, which would
make the list a queue again by the back door and put [ADR 0004](0004-remove-the-queue.md) back
on the table.

## Alternatives considered

- **Keep the length in Settings only**, and move just the field and the distraction list onto
  the strip. Rejected by the requirement, but it remains the cheapest reversal if the symptom
  above appears — the strip is designed so the chip can be removed without touching the rest.
- **Put the length on ⌘1/⌘2/⌘3 as named kinds again.** Rejected: that is precisely the version
  that was tried and removed, and it makes the length a question with three answers rather than
  a statement with an override.
- **A separate project-naming popover**, as the old prompt had. Rejected: a second caret on a
  surface this small is a focus fight, and borrowing the one field costs nothing and reads as
  the same object changing its mind.
- **Filling the field from a distraction without resolving it**, leaving it on the live list.
  Rejected: it leaves an item you just spent a session on sitting in a list of things you
  decided not to do.
