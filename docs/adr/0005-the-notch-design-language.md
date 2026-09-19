# 0005 — The notch is the design language

**Status:** accepted · 2026-09-19

## Context

Blocks has two visual registers. The app's own — rounded, light, lilac cards, a green accent,
springy buttons, the occasional encouraging line — and the notch timer's: black, flush with the
hardware, one height, no colour it does not need, no words it does not need.

The notch timer ([ADR 0003](0003-remove-the-ambient-bar.md)) was drawn to disappear into the
machine. In use, that register turned out to be the one that fits what Blocks is for. The bar
is legible at a glance, costs nothing to look at, and carries no tone. The app's other
surfaces, by comparison, are chatty: they greet you, they encourage you, and they take a large
centred panel to ask a one-line question.

The clearest case was capture. Writing a distraction down is the smallest interaction in the
app — a keystroke, a few words, gone — and it opened a 516×190 titled panel in the middle of
the screen, with a heading ("Write it down and let it go."), a full-size field, a Cancel button
and a Capture button. A dialog that size reads as an event. Capture is not an event; it is
meant to cost less attention than the distraction did.

## Decision

The notch timer's register is Blocks's design language, and surfaces move onto it one at a
time as they are touched. Its rules: black, borderless, no larger than the job; system white at
graded opacities instead of colour; labels over sentences; the keyboard named where the
keyboard is what you will use; motion only where it carries information.

Capture goes first. The panel is replaced by the **capture strip** — 460×44, black, one line,
positioned directly under the notch bar and centred on the notch itself: a pulsing dot, the
word `DISTRACTION`, the field, and the single key that is currently live (`esc` while empty,
`return` once there is something to keep). No heading, no buttons, no chrome.

The strip still activates Blocks, because it has to be typed into. It appears in the same place
whether or not the notch bar is showing, so the shortcut always puts it where the hand expects.

## Consequences

`PromptKind` loses `.capture`; capture no longer shares the prompt panel, and `FocusedTextField`
grows optional text, placeholder and font colours so a field can be drawn on black — including
the caret, which comes from the shared field editor and is invisible on black unless claimed.

The two registers now coexist, which is worse than either one alone. The intent, pause and
abandon prompts, the popover and the review window are all still in the old one. This is
accepted as the state of a migration rather than a resting place.

**What this costs, stated plainly:** the strip gives up the room to explain itself. The old
panel's heading told a first-time user what capture was *for* — that the point is to let the
thought go, not to file it. The strip says `DISTRACTION` and waits.

**The symptom to watch for:** captures that read like notes-to-self rather than things being
let go of, or a user who has the shortcut bound and never presses it. If either appears, the
answer is a one-time introduction to capture, not a bigger strip.

## Alternatives considered

- **Restyle the existing panel in black** and keep its size and structure. Rejected: the
  objection is the size and the ceremony, not the palette.
- **Put capture inside the notch bar itself**, expanding the bar to hold a field. Rejected: the
  bar is deliberately click-through and non-activating, and typing into it would mean taking
  keyboard focus away from the work it is timing — the one thing the bar promises not to do.
- **Convert every surface to the new register in one pass.** Rejected: the popover and review
  window carry real density (lists, reports, tags), and redrawing them blind, in the same change
  as the capture strip, would be a redesign with nothing learned in between.
