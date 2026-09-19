# Positioning

The differentiation pitch for Blocks. Derived from [landscape.md](landscape.md); that file has the
evidence, this one has the argument. Audience: prospective users — Show HN readers, Product Hunt
visitors, the top of the README.

## The one line

**The keyboard-first focus buddy: the app that helps you get things done consistently, without
ever taking your hands off the keyboard or taking control away from you.**

Supporting line, where there is room for two: *every other focus app assumes you can't be
trusted. Blocks assumes you can.*

### What "keyboard-first" has to mean to be a claim

Not "has shortcuts" — every app has shortcuts. The claim is that **the mouse is never required
for the loop the product is about**: ⇧⌘/ starts a session over any app or fullscreen window with
the field already focused, ↑↓ and Return start a session on something you captured earlier or
pause and abandon the one already running, ⌘/ captures a distraction in
under three seconds and returns you to where you were, ⇧⌘E buys another twenty-five minutes when
the clock runs out, and ⌘1/⌘2/⌘3 move between Reports, Tasks and Archive. Nothing in a session
requires aiming at anything.

The corollary is that nothing else is allowed into that path *unanswered*. The session length is a
setting, stated rather than asked: one keystroke run, one decision, and the decision is what you are
working on.

That is also why there is no character and no audio in the product. A mascot is something to
look at and a track picker is something to fiddle with; both are mouse work dressed as
personality. The buddy is the app doing its job and getting out of the way.

### And "consistently" is the outcome being sold

Not a heroic day — tomorrow, and the day after. Every session is its own task, so the record is a
count of days you turned up rather than a scoreboard for one piece of work you keep returning to,
and the reports count time served rather than work delivered. Nothing accumulates that a bad day
can break, which is exactly what makes the next day cheap.

## The wedge

The focus app market has settled on a single theory of the problem: *you are weak, so we will make
the bad thing impossible.* Blockers lock sites. Monitors watch your app switches. The 2026 wave
puts a local AI on your active window so it can nudge you back. Every one of these is a machine
built to work around you.

They all share an unexamined premise — that the distraction must be **stopped**. Blocks is built on
a different one: a distraction is not an enemy, it's an unfinished thought, and it only has power
over you because you're afraid of losing it. Write it down and it stops pulling. That's the whole
mechanism. **⌘/, six words, return, back to work.** Deferral, not enforcement.

This is why Blocks needs no permissions. It isn't a privacy feature that got bolted on. It's that
an app which asks instead of watching has nothing to ask permission *for*.

## Six claims no competitor makes

**1. A walked-away session still counts as what it was.**
Nothing here is scored. An abandoned session keeps the minutes it actually earned, a reset is
written down with its reason, and there are no streaks to protect — so a bad day costs you a
smaller bar and nothing else.

Every competitor makes honesty cost something. Session asks "what did you learn?" — journaling.
Focus Bear asks what you achieved — a performance review. GoalsWon and Flow Club outsource the
question to a paid human. Each of those turns the log into a thing you would rather look good
in, and an aspirational log is worth nothing a week later.

Blocks counts time served honestly, not work delivered. (It used to *ask* — "you said
`<intent>`; did you?" — and that question has since been retired: a mandatory prompt at the
boundary is itself a thing to dread. The property it protected, a record no one has a reason to
flatter, is kept by never scoring anything.)

**2. The clock runs out and asks for nothing.**
At zero, every other timer does something to you: a sound, a full-screen card, a break you have to
dismiss, a question. Blocks changes two words in the menu bar and offers twenty-five more minutes
for five minutes. Take them with ⇧⌘E and it is the *same* session, longer — not a second one, so
nothing in the record implies you failed to finish the first. Say nothing and it files itself.
The boundary is the one moment every focus app turns hostile, and it is the cheapest place to be
kind.

**3. One task, one session.**
A task here is the thing you sat down to do, not a folder that collects attempts at it. Apps that
let you rerun a task hand you a per-task tally you start performing for — four sessions on "write
the proposal" reads as either diligence or failure, and neither reading is any use. A session that
needs longer is extended; a session started tomorrow is tomorrow's task.

**4. One length, and it is not a question.**
25 minutes, changeable in Settings, and that is the whole of it. The market splits between apps
that fix the interval as ideology and apps that hand you a slider, a ratio and a long-break rule.
Blocks does neither: the length is a setting you touch a few times a year, so the keystroke run
from shortcut to running session never pauses to ask how long.

> **Amended 2026-09-19** ([ADR 0006](adr/0006-the-start-strip.md)). The start strip now carries a
> length chip at its bottom left. It is still not a question: it *states* the 25 that Settings
> already decided, and the run from shortcut to Return goes past it untouched. Overriding it is
> for the one session and never reaches the default. The distinction the app is defending is
> stated rather than asked — and the thing to watch is whether the chip gets touched most days,
> which would mean the default is wrong rather than that the chip is useful.

**5. There is no break.**
The entire market argues about whether you may *skip* a break. Blocks removed it. A block ends and
you're at idle — you decide what happens next, because you're an adult and the app doesn't know
whether you're tired.

This also closes the one gap in the nearest competitor. Zone ($7.99) is the only other app that
lets you capture an intrusive thought mid-session — and then hands it back to you *during the break*,
which just moves the distraction five minutes later. Blocks' captured distractions sit in the popover and
expire themselves after seven days. Most were never worth doing. The list proves it.

**6. One list, and only one thing you may write down mid-session.**
A **distraction** is something deliberately not done — ⌘/, expires in seven days. That is the whole
vocabulary. The start shortcut does nothing while a session runs, because lining up the next piece
of work is a way of stopping that looks like productivity.

> **Amended 2026-09-19** ([ADR 0004](adr/0004-remove-the-queue.md)). This point used to be "two
> lists that mean opposite things": a distraction on ⌘/, a pending intent on ⇧⌘/, one Shift apart
> with opposite fates. The distinction was real and the queue still had to go — a second thing you
> may do mid-session is a second reason to stop, and the user had to tell the two apart at exactly
> the moment they had least attention to spare. The claim is now narrower and truer: every other
> app has an undifferentiated notes field, and Blocks has a list of things you decided not to do.

## The objection, answered

**"It doesn't block anything, so what stops me?"**

Nothing. That's the design.

A blocker teaches you that you can only work when supervised, and it fails the moment you're on a
machine it isn't installed on. Blocks trains the move you actually need — noticing an impulse,
naming it, and letting it go — which works everywhere, forever, including on your phone in a
meeting. You are not buying a fence. You are practising something.

And the record is honest, so after a week you know something no blocker can tell you: what actually
pulls at you, and how little of it survived seven days.

## Who this is for

For: people who don't want to be managed by their software, who want the history to be true even
when it's unflattering, and who want one app that does one thing and then gets out of the way.

Not for: anyone who wants to be stopped. If enforcement is what works for you, Cold Turkey and
Freedom are good, and Blocks is not competing with them.

## Ready copy

**Show HN title**
Show HN: Blocks – a keyboard-first macOS focus timer that never needs the mouse

**Show HN opening**
> Every focus app I tried was built to stop me: blockers, app monitors, and lately a local AI
> reading my active window. I wanted the opposite, and I wanted it to stay out of my hands' way.
> Blocks runs entirely from the keyboard: ⇧⌘/ starts a session from any app with the field
> already focused and nothing to decide but what you are working on, ⌘/ captures a distraction in
> three seconds and puts you back where you were, and when the clock runs out ⇧⌘E adds another
> twenty-five minutes to the same session instead of starting a new one. No mascot, no music library, no blocking, no monitoring, no accounts, no network, no
> permissions. Everything is plain JSONL in Application Support.

**Product Hunt tagline**
The keyboard-first focus buddy. Start, capture, extend — hands never leave the keys.

**README first line**
The keyboard-first focus buddy for macOS.

**The 10-second version, spoken**
It's a timer you never touch the mouse for. ⇧⌘/ from anywhere, type what the time is for,
and go — sessions are 25 minutes unless you change that in Settings. When something pulls at you, you hit ⌘/ and write it
down instead of doing it — that's what makes it safe to not do it now. When it runs out it says
"Done" and offers another twenty-five minutes; ignore it and it saves itself. No blocking, no
tracking, no account.
