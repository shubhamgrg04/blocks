#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
cat Sources/Blocks/Brand.swift scripts/icon.swift > .build/render-brand.swift
swift .build/render-brand.swift .build/Blocks.iconset
cp .build/Blocks.iconset/icon_512x512@2x.png Resources/Blocks.png
cat Sources/Blocks/Brand.swift scripts/brand-mark.swift > .build/render-mark.swift
swift .build/render-mark.swift Resources/Blocks-mark.png
