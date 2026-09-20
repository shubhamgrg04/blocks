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
state = {'phase': 'idle', 'preferences': {'dailyFocusHours': 5, 'blockMinutes': 25},
         'parked': [{'id': str(uuid.uuid4()), 'at': stamp(now - datetime.timedelta(hours=h)), 'text': text, 'resolved': False}
                    for h, text in [(3, 'Find a new Sunday playlist'), (2, 'Reply to Priya about the launch date'), (1, 'Look up that book on typography')]]}
(folder / 'state.json').write_text(json.dumps(state))
# One task, one session: every record carries its own task and its own words.
intents = [
    'Explore a new direction', 'Refine the details', 'Make something worth sharing',
    'Sketch the settings pass', 'Read the ADR properly', 'Reply to the long email',
    'Outline chapter three', 'Trim the landing copy', 'Fix the notch alignment',
    'Plan the week', 'Draft the release notes', 'Sort the reference photos',
    'Rework the opening line', 'Answer the design question', 'Tidy the project tags',
    'Write the migration note', 'Rehearse the walkthrough', 'Price the new plan',
    'Clear the review queue', 'Name the three lengths', 'Storyboard the demo',
]
records = []
for days, count in [(6, 2), (5, 4), (4, 3), (3, 1), (2, 5), (1, 3), (0, 3)]:
    for index in range(count):
        start = now - datetime.timedelta(days=days, hours=index + 1)
        minutes = [25, 60, 45][len(records) % 3]
        records.append({'id': str(uuid.uuid4()), 'taskID': str(uuid.uuid4()), 'start': stamp(start),
                        'end': stamp(start + datetime.timedelta(minutes=minutes)),
                        'intent': intents[len(records) % len(intents)],
                        'project': ['Blocks', 'Writing', 'Personal'][index % 3],
                        'plannedSeconds': minutes * 60, 'focusedSeconds': minutes * 60,
                        'outcome': 'completed', 'check': None, 'pauses': [], 'parked': []})
(folder / 'blocks.jsonl').write_text('\n'.join(json.dumps(record) for record in records) + '\n')
PY
swiftc -parse-as-library -I "$BIN_DIR/Modules" Sources/Blocks/AppModel.swift Sources/Blocks/Brand.swift Sources/Blocks/Design.swift Sources/Blocks/Hotkey.swift Sources/Blocks/StatusItem.swift Sources/Blocks/Surfaces.swift Sources/Blocks/Views.swift Sources/Blocks/NotchTimer.swift Sources/Blocks/Strips.swift Sources/Blocks/Reports.swift Sources/Blocks/Projects.swift scripts/preview.swift "$BIN_DIR"/BlocksCore.build/*.o -o .build/design-preview
BLOCKS_TEST_DATA_DIRECTORY="$PWD/.build/design-preview-data" .build/design-preview
