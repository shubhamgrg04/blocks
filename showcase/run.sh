#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
python3 showcase/seed.py
APP="$PWD/.build/Blocks Showcase.app"
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>BlocksShowcase</string><key>CFBundleIdentifier</key><string>local.blocks.showcase</string><key>CFBundleName</key><string>Blocks Showcase</string></dict></plist>
PLIST
swiftc -parse-as-library -I "$BIN_DIR/Modules" Sources/Blocks/{AppModel,Brand,Design,Hotkey,StatusItem,Surfaces,Views,NotchTimer,Strips,Reports,Projects}.swift showcase/Showcase.swift "$BIN_DIR"/BlocksCore.build/*.o -o "$APP/Contents/MacOS/BlocksShowcase"
BLOCKS_TEST_DATA_DIRECTORY="$PWD/.build/showcase-data" "$APP/Contents/MacOS/BlocksShowcase"
