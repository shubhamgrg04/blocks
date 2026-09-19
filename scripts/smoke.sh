#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
SMOKE_DATA="$(mktemp -d)"
trap 'rm -rf "$SMOKE_DATA"' EXIT
swiftc -parse-as-library -I "$BIN_DIR/Modules" Sources/Blocks/AppModel.swift Sources/Blocks/Brand.swift Sources/Blocks/Design.swift Sources/Blocks/Hotkey.swift Sources/Blocks/StatusItem.swift Sources/Blocks/Surfaces.swift Sources/Blocks/Views.swift Sources/Blocks/NotchTimer.swift Sources/Blocks/Strips.swift Sources/Blocks/Reports.swift Sources/Blocks/Projects.swift scripts/smoke.swift "$BIN_DIR"/BlocksCore.build/*.o -o .build/blocks-feature-smoke
BLOCKS_TEST_DATA_DIRECTORY="$SMOKE_DATA" .build/blocks-feature-smoke
