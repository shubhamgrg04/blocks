#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BIN_DIR="$(swift build -c release --show-bin-path)"
# Preview-only initializer is injected into a build copy; production sources stay unchanged.
python3 - <<'PY'
from pathlib import Path
s=Path('Sources/Blocks/Reports.swift').read_text()
s=s.replace('    private var calendar: Calendar', '''    init(model: AppModel, showcasePeriod: Int = 7, showcaseProject: String? = nil) {
        self.model = model
        _period = State(initialValue: showcasePeriod)
        _project = State(initialValue: showcaseProject)
    }
    private var calendar: Calendar''',1)
Path('.build/ShowcaseReports.swift').write_text(s)
PY
swiftc -parse-as-library -I "$BIN_DIR/Modules" Sources/Blocks/{AppModel,Brand,Design,Hotkey,StatusItem,Surfaces,Views,NotchTimer,Strips,Projects}.swift .build/ShowcaseReports.swift showcase/native.swift "$BIN_DIR"/BlocksCore.build/*.o -o .build/showcase-native
mkdir -p .build/showcase-static-data
cp .build/showcase-data/blocks.jsonl .build/showcase-static-data/blocks.jsonl
printf '%s' '{"phase":"idle","preferences":{"dailyFocusHours":3,"blockMinutes":25}}' > .build/showcase-static-data/state.json
BLOCKS_TEST_DATA_DIRECTORY="$PWD/.build/showcase-static-data" .build/showcase-native
