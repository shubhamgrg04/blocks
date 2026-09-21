<div align="center">

# Blocks

**Stay on the keyboard. Get the important thing done.**

A keyboard-first focus tool for macOS. Pick one task, give it your attention, and save everything else for later.

<img src="showcase/screenshots/01-macbook-notch.png" alt="Blocks keeps the focus timer beside the MacBook notch, with the current task and to-do queue in a compact popup" width="960">

</div>

**1. Pick one thing.** Press `⇧⌘/` from any app. Type your task or choose one with `↑` / `↓`, then press Return to start focusing.

<img src="Resources/Previews/start.png" alt="The keyboard-driven start popup with a task field, queued tasks, duration, and project" width="460">

**2. Save the distraction.** Press `⌘/`, jot down what came to mind, and press Return. It goes into To do while your current timer keeps running.

<img src="Resources/Previews/capture.png" alt="The quick-capture field: Add a task for later" width="460">

**3. Finish and move forward.** Press `⇧⌘/` again to open session controls. Use `↑` / `↓` and Return to complete the task, pause, or add more time. Escape takes you back to your work.

<img src="Resources/Previews/session.png" alt="Session controls with Mark task complete selected, followed by pause and extend actions, navigable with arrows and Return" width="460">

The timer stays in your notch, a floating bar, or the menu bar. A gentle tone and completion animation let you know when time is up; click **+25m** to keep going. Review your focus time by day or project when you’re ready.

Everything stays on your Mac. No account required.

## Get started

Requires **macOS 14+** and Apple’s Command Line Tools.

```sh
git clone https://github.com/shubhamgrg04/blocks.git
cd blocks
./build.sh
```

The script builds, signs, installs, and launches Blocks. The first build may ask you to authenticate to create its local signing identity. Quit Blocks before rebuilding.

For development, run `./test.sh` and `./scripts/smoke.sh`. See the [product spec](SPEC.md) and [screenshot gallery](showcase/README.md) for more detail.

<sub>Hero image uses native app captures with sample data and an illustrative device frame.</sub>
