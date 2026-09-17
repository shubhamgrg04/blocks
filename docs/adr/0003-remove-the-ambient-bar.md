# 0003 — Remove the ambient bar

**Status:** accepted · 2026-09-17

## Context

SPEC §5 rested on a claim: time blindness is a *perception* problem, not an information
problem, and so the answer had to be perceived rather than read. The ambient bar was that
answer — a thin bar shrinking as a block's time passed, drawn inset under the notch on a
built-in display and along the bottom edge of every other one. The same section named the
alternative and rejected it: "a menu bar countdown fails because it must be looked at, and
looking at it is precisely what doesn't happen."

In practice the bar was not what got looked at. The remaining time was reachable only by
clicking the menu bar icon and reading it off the popover — two deliberate acts to answer the
question the app exists to answer. The menu bar title was already specified to carry the
countdown, but it was written as a SwiftUI `Label` inside a `MenuBarExtra`, which the status bar
renders as a template image: the text never appeared.

## Decision

Remove the ambient bar entirely — both geometries, the borderless windows, and the multi-display
rebuild that kept them aligned — and make the menu bar clock the app's only time surface.

Blocks owns an `NSStatusItem` directly rather than declaring a `MenuBarExtra`, with the popover
hosted in an `NSPopover`. The title is an `NSAttributedString` assigned on every tick, so the
countdown is a value Blocks sets rather than a view SwiftUI may decline to re-render, and so it
can carry colour — which the warning now depends on.

The clock has three shapes: the icon alone when idle, bare digits while a block runs, and the
pause glyph beside greyed digits when paused. In the last thirty seconds the digits turn a
steady orange. The Glass sound at thirty seconds is unchanged.

## Consequences

SPEC §5 is rewritten as a concession rather than a redefinition. Blocks no longer claims to
answer time blindness by perception: the countdown is a number you look at, and the mechanism
that now carries the weight is the boundary and the honesty check arriving whether or not you
looked.

**What this costs, stated plainly:** the ambient bar was the only signal that worked *without
being looked at*. Everything left — the digits, the colour change — requires a glance, and the
one channel that does not is the Glass sound, which a muted Mac silences. The app has traded
the thing it was designed around for the thing its spec predicted would fail.

**The symptom to watch for:** the boundary starting to feel abrupt again. If the honesty check
arrives as a surprise, or blocks routinely run past the point where attention had already gone,
this decision is the first place to look. The cheapest thing to try is *not* rebuilding the
notch geometry but giving the warning a second non-visual channel, or letting the last thirty
seconds change something already in peripheral vision.

## Alternatives considered

- **Keep the bottom-edge bar, drop only the notch capsule.** Rejected: a bar surviving only on
  external displays is a worse version of the feature rather than a smaller one, and it keeps
  all of the multi-screen window machinery for a fraction of the benefit.
- **Keep `MenuBarExtra` with a bare `Text` label.** Would likely render the digits, and is far
  less code. Rejected: SwiftUI renders the status bar label as a template image, which strips
  the colour the thirty-second warning needs, and leaves the refresh behaviour that hid the
  countdown in the first place as something to hope about rather than control.
- **Claim the menu bar countdown is itself ambient, being always in peripheral vision.**
  Rejected as redefining the word until the decision and the spec both fit. SPEC §5 already
  argued the opposite, and the honest response to a spec contradicted by a decision is to change
  the spec.
