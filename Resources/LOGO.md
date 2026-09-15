# Blocks logo

Three softly rounded bricks form a compact B. The shape is drawn once in `Sources/Blocks/Brand.swift` and reused everywhere: menu bar, wordmark, prompts, review, and application icon.

The macOS menu bar uses an 18-point template image that adapts to its background. The application icon places the same silhouette in pale lilac on cobalt. No generated raster artwork or alternate brand symbols are used.

`build.sh` regenerates `Resources/Blocks.png` and the ICNS from this shared vector source. The interface tokens live in `Sources/Blocks/Design.swift`.
