"""Schedule Konkuk GLOCAL 집중이수 offerings on the weeks the timetable publishes.

The GLOCAL timetable gives each 집중이수 offering its day, time and week range
(e.g. `집중이수제: 8주(1-8주)`) but no dates, so `import_konkuk.py` holds them as
`unrecognized`. Per the 2026-11-23 user decision the timetable's own week range
is used as-is (not the syllabus weeks). Week dates come from the 2026-2 week
table shared by every public 강의계획서 (`/wsugang/core?attribute=lectPlan`,
no login): week 1 = 2026-08-31..09-06, week n starts 7*(n-1) days later. Weekly
meetings are limited to that range with a course `period`.

Seoul offerings whose timetable slot is `00` with e-러닝 have no published time
and become `unscheduled` (the same as the other Seoul e-러닝 rows).

Usage: python3 tool/timetable/apply_konkuk_glocal_intensive.py
"""
import datetime
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from import_konkuk import glocal_meetings  # noqa: E402

GLOCAL = Path('assets/timetable/konkuk-glocal-2026-2.json')
SEOUL = Path('assets/timetable/konkuk-seoul-2026-2.json')
PLAN_URL = 'https://kupis.kku.ac.kr/wsugang/core?attribute=lectPlan'
WEEK1 = datetime.date(2026, 8, 31)
WEEKS = re.compile(r'집중이수제: (\d+)주\((\d+)-(\d+)주\)')
OLD_NOTE = re.compile(r' · 공개 강의계획서\([^)]*\) 주차별 계획: .*$')


def week_range(a, b):
    start = WEEK1 + datetime.timedelta(days=7 * (a - 1))
    end = WEEK1 + datetime.timedelta(days=7 * (b - 1) + 6)
    return start.isoformat(), end.isoformat()


assert week_range(1, 8) == ('2026-08-31', '2026-10-25')
assert week_range(9, 16) == ('2026-10-26', '2026-12-20')


def load(path):
    raw = path.read_text(encoding='utf-8')
    return raw, json.loads(raw)


def save(path, raw, data):
    path.write_text(
        json.dumps(data, ensure_ascii=False, separators=(',', ':'))
        + ('\n' if raw.endswith('\n') else ''),
        encoding='utf-8',
    )


raw, data = load(GLOCAL)
changed = 0
for course in data['courses']:
    remarks = course.get('departmentRemarks', {})
    found = {WEEKS.search(r).groups() for r in remarks.values() if WEEKS.search(r)}
    if not found:
        continue
    if len(found) != 1:
        raise ValueError('Conflicting 집중이수 weeks ' + course['courseCode'])
    count, a, b = map(int, found.pop())
    if count != b - a + 1:
        raise ValueError('Inconsistent 집중이수 weeks ' + course['courseCode'])
    status, meetings = glocal_meetings(course['sourceSchedule'])
    if status != 'scheduled':
        raise ValueError('Unparsed GLOCAL schedule ' + course['courseCode'])
    start, end = week_range(a, b)
    course['scheduleStatus'] = 'scheduled'
    course['schedules'] = meetings
    course['sourceClassroom'] = ' / '.join(dict.fromkeys(
        m['classroom'] for m in meetings if m['classroom']))
    course['period'] = {'startDate': start, 'endDate': end}
    note = (f'강의시간표 집중이수 {a}-{b}주({start}~{end})만 수업'
            f' · 주차 날짜는 공개 강의계획서({PLAN_URL}) 주차표 기준')
    for department, remark in remarks.items():
        remark = OLD_NOTE.sub('', remark)
        remarks[department] = remark + ' · ' + note
    changed += 1
save(GLOCAL, raw, data)

raw, data = load(SEOUL)
untimed = 0
for course in data['courses']:
    if (course['scheduleStatus'] == 'unrecognized'
            and re.fullmatch(r'[월화수목금토일]00\(.*\)\(e-러닝\)', course['sourceSchedule'])):
        course['scheduleStatus'] = 'unscheduled'
        course['schedules'] = []
        untimed += 1
save(SEOUL, raw, data)
print('glocal intensive scheduled', changed, '· seoul untimed e-러닝', untimed)
