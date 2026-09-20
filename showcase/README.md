# Blocks showcase library

Open [the gallery](index.html) to browse and download everything.

- [Walkthrough with music](video/blocks-walkthrough.mp4) — 64.9 seconds, 1920 × 1200, 30 fps, H.264/AAC.
- [Silent walkthrough](video/blocks-walkthrough-silent.mp4).
- [Subtitles](video/blocks-walkthrough.srt) and [chapter timing](video/chapters.json).
- [MacBook with notch](screenshots/01-macbook-notch.png) and [external monitor](screenshots/02-external-monitor.png).
- [Screenshot contact sheet](contact-sheet.jpg).
- `screenshots/`: 12 editorial PNGs. Device images are 1920 × 1200; interaction captures are 1240 × 760.
- `native/`: seven reusable native assets, including 1600 × 2080 daily, weekly, and project report captures.

## What the walkthrough shows

A task is visibly typed into the native start field and started with a normal **25-minute** duration. Another task is typed into the quick-capture field while the timer runs. The current task is marked complete early using the app's completion action; its actual elapsed time is saved. The queued task then starts. Reports show the rolling seven-day view, today's view, the Studio project filter, and the session timeline.

The history is synthetic, with non-overlapping sessions for Studio, Writing, and Personal. The daily target is three hours for the demo; the shipping default remains unchanged. Captures are from September 20, 2026. The live demo completion is under a minute and is accurately shown that way in reports.

**Capture provenance:** Actual production SwiftUI views and `AppModel` run in an isolated native capture window, controlled through the UI. The surrounding editorial text and scene selector belong to the capture harness. This is not a recording of a human participant or an unmodified desktop session. Character-by-character typing and all task/report actions are real native interactions. Frames are sampled at up to 12 fps with original timing preserved, then encoded at 30 fps. The final edit removes waiting; it does not simulate 25 minutes passing. It has no recorded microphone audio.

Device frames and wallpaper are illustrative compositions containing native app captures. They demonstrate the notch and non-notch layouts; they are not photographs or hardware compatibility tests. Personal app data is never read or written.

Music reuses the existing project's **House Vibez — Lily J** asset, mixed quietly with an intro/outro fade. See [audio credits and license provenance](../launch-video/production/AUDIO-CREDITS.md). A silent export is included.

## Reproduce or update

From the repository root:

```sh
./showcase/run.sh
```

This builds an independent `.build/Blocks Showcase.app` and seeds `.build/showcase-data`. It does not install or replace Blocks. Choose **Record**, interact with the actual fields/buttons, switch scenes with the bottom toolbar, then **Stop recording**. **Snapshot** saves the content without the toolbar. Each recording gets a fresh `raw/take-*` directory. Quit the capture app when finished. The toolbar is a capture tool; native actions that open separate windows are outside its recorded area.

```sh
python3 showcase/encode-take.py showcase/raw/take-TIMESTAMP showcase/video/new-take.mp4
./showcase/export-native.sh
cp showcase/native/*.png launch-video/public/showcase/
cd launch-video
npx remotion still src/showcase/index.tsx MacBook ../showcase/screenshots/01-macbook-notch.png
npx remotion still src/showcase/index.tsx ExternalMonitor ../showcase/screenshots/02-external-monitor.png
cd ..
python3 showcase/render.py
```

The preserved source recording is `video/native-capture.mp4`. `production/edit.json` supplies the exact cuts and chapters; update them for a new take before rendering. `render.py` uses that preserved recording, not the raw capture directory. MP4 and raw frame outputs are ignored by Git; keep them with the gallery when sharing. The render scripts require the repository's existing Swift, Remotion, Python, and ffmpeg tooling. Production app source files were not changed for this showcase.
