#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
mkdir -p .build/design-preview-data
python3 - <<'PY'
import json, uuid, datetime
from pathlib import Path
folder = Path('.build/design-preview-data')
now = datetime.datetime.now(datetime.timezone.utc)
stamp = lambda date: date.isoformat(timespec='seconds').replace('+00:00', 'Z')
state = {'phase': 'idle', 'preferences': {'dailyTarget': 9, 'blockMinutes': 25},
         'pending': [{'id': str(uuid.uuid4()), 'at': stamp(now), 'text': text} for text in ['Sketch the onboarding flow', 'Write a first draft']],
         'parked': [{'id': str(uuid.uuid4()), 'at': stamp(now), 'text': 'Find a new Sunday playlist', 'resolved': False}]}
(folder / 'state.json').write_text(json.dumps(state))
records = []
for days, count in [(6, 2), (5, 4), (4, 3), (3, 1), (2, 5), (1, 3), (0, 3)]:
    for index in range(count):
        start = now - datetime.timedelta(days=days, hours=index + 1)
        records.append({'id': str(uuid.uuid4()), 'start': stamp(start), 'end': stamp(start + datetime.timedelta(minutes=25)), 'intent': ['Explore a new direction', 'Refine the details', 'Make something worth sharing'][index % 3], 'plannedSeconds': 1500, 'outcome': 'completed', 'check': ['yes', 'partly', 'no'][index % 3], 'pauses': [], 'parked': []})
(folder / 'blocks.jsonl').write_text('\n'.join(json.dumps(record) for record in records) + '\n')
PY
swiftc -parse-as-library -I "$BIN_DIR/Modules" Sources/Blocks/AppModel.swift Sources/Blocks/Brand.swift Sources/Blocks/Design.swift Sources/Blocks/Hotkey.swift Sources/Blocks/StatusItem.swift Sources/Blocks/Surfaces.swift Sources/Blocks/Views.swift scripts/preview.swift "$BIN_DIR"/BlocksCore.build/*.o -o .build/design-preview
BLOCKS_TEST_DATA_DIRECTORY="$PWD/.build/design-preview-data" .build/design-preview
