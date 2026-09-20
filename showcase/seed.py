"""Synthetic, non-overlapping focus history. Never reads personal app data."""
import datetime as dt, json, uuid
from pathlib import Path
root = Path('.build/showcase-data'); root.mkdir(parents=True, exist_ok=True)
now = dt.datetime.now().astimezone()
stamp = lambda d: d.astimezone(dt.timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z')
projects = {
    'Studio': ['Map the onboarding journey', 'Sketch the welcome screen', 'Refine the empty states', 'Review the interaction details'],
    'Writing': ['Outline the launch story', 'Edit the product introduction', 'Draft the weekly newsletter', 'Find a stronger opening'],
    'Personal': ['Plan the week ahead', 'Read a chapter', 'Organize design references', 'Make room for next week'],
}
records=[]
for day in range(7):
    start = (now-dt.timedelta(days=day)).replace(hour=7,minute=0,second=0,microsecond=0)
    for n, minutes in enumerate(([45,25,50,25,30], [25,50,25,45], [50,25,45,25,25,30], [25,45,25], [50,50,25,25,30], [25,45,25,25], [45,25,50])[day]):
        project=list(projects)[(n+day)%3]
        end=start+dt.timedelta(minutes=minutes)
        if end>now: break
        records.append(dict(id=str(uuid.uuid4()), taskID=str(uuid.uuid4()), start=stamp(start),end=stamp(end),intent=projects[project][(n+day)%4],project=project,plannedSeconds=minutes*60,focusedSeconds=minutes*60,outcome='completed',pauses=[],parked=[]))
        start=end+dt.timedelta(minutes=12)
(root/'state.json').write_text(json.dumps({'phase':'idle','preferences':{'dailyFocusHours':3,'blockMinutes':25}}))
(root/'blocks.jsonl').write_text('\n'.join(map(json.dumps,records))+'\n')
print(f'Seeded {len(records)} synthetic sessions in {root}')
