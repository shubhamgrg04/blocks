# Blocks logo

The native macOS `timer` symbol is the Blocks brand mark, matching the menu bar and session controls. The old three-brick B is retired.

`Sources/Blocks/Brand.swift` renders the same timer in mint (`0.65, 0.84, 0.77`). `Resources/Blocks-mark.png` is the transparent mark for the README and video. `Resources/Blocks.png` is the app icon, with the timer on the dark product canvas.

Run `./scripts/brand.sh` to regenerate both assets. The app build also renders its icon from the same source. The video asset sync copies `Blocks-mark.png`; it does not keep a separate logo design.
