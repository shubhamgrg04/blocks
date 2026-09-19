# Competitive landscape

Research date: 2026-09-17. Sources: Product Hunt, Hacker News, App Store, vendor sites.
Reddit was not directly reachable from the research tooling; where Reddit is cited below it is
via secondary coverage of what r/macapps and r/productivity recommend, not threads read first-hand.

Blocks is four decisions stacked together. Almost every app below shares one or two of them.
None found shares all four.

1. **Menu bar timer, one intent per block** — commodity.
2. **Capture a distraction instead of acting on it** — rare. One direct match.
3. **Honesty check at the boundary** — effectively absent in timer apps.
4. **No break, no blocking, no monitoring, no accounts, no network, no TCC** — a crowded
   *claim*, but usually partial (most "private" timers still block apps, which needs permissions).

## 1. Menu bar pomodoro timers — the commodity layer

This is the saturated part. Differentiation here is design and price, not mechanism.

| App | Notes |
| --- | --- |
| [TomatoBar](https://onmymenubar.app/tomatobar/) | The reference free option. Open source, native Swift, ~2.8k stars, zero tracking, logs state transitions as JSON for post-processing. This is the app a technical user already has. |
| [Flumen](https://news.ycombinator.com/item?id=47069336) | Show HN, Feb 2026. Open source, menu bar, local SQLite, no telemetry, task shelving + project analytics. Built explicitly because others were "bloated, ugly, paywalled, or stored my data in the cloud" — the same complaint Blocks answers. |
| [PomodoroBar](https://pomodorobar.com/), [PomBar](https://pombar.app/), [Pommie](https://apps.apple.com/us/app/pommie-pomodoro-timer/id963504129?mt=12), [Be Focused](https://apps.apple.com/us/app/be-focused-pomodoro-timer/id973134470?mt=12) | Minimal menu bar timers with stats. Pommie adds timer profiles and system-wide shortcuts. |
| [Focus Timer](https://www.alternativeto.net/software/focus-timer/about/), [FocusNotch](https://alternativeto.net/software/focusnotch/about/), Pomodoro Timer Lite | All market on the same four words: offline, ad-free, no tracking, no registration. |
| [Show HN: Lightweight macOS menu bar Pomodoro](https://news.ycombinator.com/item?id=46087224) | Nov 2025, built in ~an hour with Claude Code after a subscription timer kept demanding license re-entry. Illustrates how low the floor is here. |

**Read:** the menu bar clock alone buys nothing. It is table stakes, and there is a free open-source
incumbent at every price point.

## 2. Capturing distractions — the one real overlap

| App | How close |
| --- | --- |
| [**Zone**](https://apps.apple.com/app/zone/id6739985370) ($7.99, macOS 14.1+) | **Closest competitor found.** Explicitly ships "a brand new way to log distractions while you are focusing" — click a cloud icon on the floating timer, log the intrusive thought, keep working; logged distractions resurface **during the break** for reflection or action. Developer collects no data. Differences from Blocks: capture is a click on the timer, not a system-wide hotkey from any app or fullscreen window; the captured distraction is surfaced *in a break*, and Blocks has no break; Zone is a calendar+todo app with a timer attached, Blocks is a block with one intent. |
| [Focus Bear](https://www.focusbear.io/) ($9.99/mo) | Asks at the end of a Focus Block what you achieved *and what the distractions were* — but retrospectively, not at the moment of impulse. Also a heavy cross-device blocker built for ADHD/AuDHD routines; the opposite of Blocks on permissions. |
| [Session](https://www.stayinsession.com/) | Intention prompt before a session, free-form notes during, a review at day's end. Notes are a general field, not a capture mechanism with its own lifetime. Syncs via Firebase and requires an email account — a direct privacy contrast. |
| [Worktivity](https://useworktivity.com/free-tools/distraction-blocker), [RescueTime](https://www.rescuetime.com/features/focus/solo), [Rize](https://rize.io) | "Distraction tracking" here means *automatic monitoring* of what pulled you away, not voluntary capture. Different philosophy: they observe you, Blocks asks you. |

**Adjacent threat — the quick-capture category.** Capture is also served, unbundled, by apps whose
whole job is a global hotkey to a text box: [SlashNote](https://slashnote.app/quick-capture/)
(registers at system level, fires over fullscreen), [Capture](https://www.capture.surf/) (⌥C to
Obsidian), [quick-capture](https://github.com/frezara/quick-capture), Drafts, Raycast, Alfred,
Things' ⌃Space. Someone who already runs one of these has ⌘/ covered — what they do not have is the
capture being *bound to a block* and expiring in seven days.

**Read:** Blocks' central move exists in the wild exactly once as a first-class feature (Zone), and
is elsewhere either retrospective (Focus Bear), generic (Session notes), automatic (RescueTime), or
unbundled (SlashNote et al.). The defensible part is not capture — it is capture with a lifetime,
tied to a block.

> **Amended 2026-09-19.** This originally read "…opposite a separate queue of intents". The queue
> was removed ([ADR 0004](adr/0004-remove-the-queue.md)), so the claim rests on the lifetime alone.

## 3. The honesty check — no direct competitor found

No macOS timer app found asks *"you said X — did you?"* at the boundary and counts **No** the same
as **Yes**. The nearest things are all social or daily, not per-block:

- [Complice](https://alternativeto.net/software/complice/about) and its successor **Intend**
  (Malcolm Ocean) — "intentions for today" instead of tasks, plus structured Reflections at day,
  week, month, year. Closest in *philosophy* (intention → honest review) but web-based, day-scoped,
  and subscription.
- [GoalsWon](https://www.goalswon.com/) — set goals in the morning, report at night what you did
  and didn't do, reviewed by a human coach.
- [Flow Club](https://flow.club) / Focusmate — declare an intention on camera, report back at the
  end to another person. Accountability outsourced to a witness.
- [Session](https://www.stayinsession.com/) — asks "what did you learn?" after a session. A
  reflection prompt, not a yes/no against a declared intent.

**Read:** this is the genuinely unclaimed ground. Everyone either skips the question, softens it
into journaling, or charges a subscription to have a person ask it. Nobody makes *No* costless.

## 4. Privacy / no-permissions positioning — crowded claim, thin practice

- [PaceBar](https://www.producthunt.com/products/pacebar) — menu bar, "no account, no telemetry, no
  cloud, everything stays on your Mac" as a day-one hard constraint. Nearest rhetorical neighbour,
  but it *passively reads* activity timing, idle time and app switches to compute a session-load
  score — monitoring, which Blocks refuses.
- [Focu](https://www.producthunt.com/products/focu) — "mindful productivity", local AI, privacy and
  data ownership as the pitch.
- [FocusNudge](https://www.producthunt.com/products/focusnudge) — set your intention in the menu bar
  with one click; nudges you when you switch to a distracting app. Shares "one declared intent",
  but enforces by watching app switches.
- [iPromise](https://www.producthunt.com/products/ipromise-ai-focus-buddy-for-deep-work),
  [Sixteen](https://www.producthunt.com/products/sixteen), [Invoko](https://www.producthunt.com/products/invoko)
  — the 2026 Product Hunt direction: local AI that reads your active window and nudges or locks.
- [Focus (heyfocus.com)](https://heyfocus.com/), [Cold Turkey], [Freedom],
  [Forest](https://forestapp.cc/) — the blocking/gamification mainstream. Opposite axis entirely.
- [Focused Task](https://github.com/RStankov/FocusedTask) — open-source Electron menu bar app,
  single-task focus + todos/bookmarks/notes. Overlaps on "one task in the menu bar", no timer ritual.
- [Hyperfocused](https://hyperfocused.app/) — menu bar, but it's a window manager + launcher +
  blocker. Unrelated mechanism, confusingly similar name.

**Read:** "local and private" is now a marketing default, not a differentiator. The 2026 trend is
the opposite of Blocks: local *AI* that watches the screen so it can intervene. Blocks' actual
distinction is that it has no idea what you are doing and asks instead — which is a *narrative*
difference, and has to be sold as one.

## Where Blocks sits

Unclaimed, in order of strength:

1. **The honesty check as the point of the app.** No competitor found. "What's counted is time
   served honestly, not work delivered" is a position nobody else holds.
2. **No break.** Every app here assumes a break; the market conversation is only about whether you
   may *skip* one (Super Productivity, Momentum Dash). Removing it outright is unusual.
3. ~~**Distraction vs. pending intent as opposing lists**, with different lifetimes (7 days vs.
   never expires vs. 30-day archive). Zone has the capture; nobody has the pair.~~
   **Withdrawn 2026-09-19** ([ADR 0004](adr/0004-remove-the-queue.md)). There is one list. What is
   left of the claim is the lifetime — Zone hands a captured thought back during the break; Blocks
   lets it expire — which is point 2's territory, not a fourth differentiator.
4. **Deferral over enforcement**, with literally zero permissions. Distinct, but it is the axis the
   market is currently moving *away* from, so it reads as a missing feature unless framed.

Weakest ground: the menu bar clock, "minimal", and "local/private" — all three are commodity, and
TomatoBar and Flumen give them away free with source.
