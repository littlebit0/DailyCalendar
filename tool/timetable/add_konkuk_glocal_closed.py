"""Add the GLOCAL 2026-2 rows the timetable marks 폐강 (clse_fg != '0').

`import_konkuk.py` used to drop them; per the 2026-11-23 user decision closed
rows stay in the catalog and follow the same rules as any other row. The rows
come from the same public 강의시간표 조회 (`/wsugang/core?attribute=timeList`,
hakgi=B01012, no login). Their opening-unit names come from the dataset itself:
an open row of the same `open_sust` code names its department.

Usage: python3 tool/timetable/add_konkuk_glocal_closed.py <all-rows.json>
(`all-rows.json`: {lec_no: row} with the GLOCAL_FIELDS of fetch_konkuk.py.)
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from import_konkuk import glocal_courses  # noqa: E402

PATH = Path('assets/timetable/konkuk-glocal-2026-2.json')

rows = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
raw = PATH.read_text(encoding='utf-8')
data = json.loads(raw)
by_code = {c['courseCode']: c for c in data['courses']}
names = {'127936': '교양학부', '127267': '교직과'}
for number, row in rows.items():
    course = by_code.get(number)
    if row['clse_fg'] == '0' and course and course['departments']:
        known = names.setdefault(row['open_sust'], course['departments'][0])
        if known != course['departments'][0] and row['open_sust'] not in ('127936', '127267'):
            raise ValueError(f'Opening unit {row["open_sust"]} has two names')
closed = {n: {'row': r, 'scopes': []} for n, r in rows.items()
          if r['clse_fg'] != '0' and n not in by_code}
added = glocal_courses({'complete': True, 'unitNames': names, 'offerings': closed})
missing = [c['courseCode'] for c in added if not c.get('departments')]
if missing:
    raise ValueError('Closed rows without an opening unit name: ' + ', '.join(missing))
data['courses'] = sorted(data['courses'] + added, key=lambda c: c['courseCode'])
PATH.write_text(
    json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    + ('\n' if raw.endswith('\n') else ''),
    encoding='utf-8',
)
counts = {}
for c in added:
    counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
print('added closed', len(added), counts)
