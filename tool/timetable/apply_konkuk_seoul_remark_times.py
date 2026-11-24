"""Schedule Konkuk Seoul 융합대학 offerings whose timetable remark gives the time.

The Seoul 종합강의시간표 (`/sugang/search?attribute=lectListOuter`, no login)
leaves the 강의시간 column empty for 실감미디어 융합전공 courses taught at
partner universities, but its 비고 column states the host university's time,
e.g. `*교강사: 김은비 / 강의요시: 금 15:00~17:50`. Per the 2026-11-23 user
decisions an official HH:mm time is used as-is (no 교시 conversion) and an
unclear delivery mode (e.g. e-러닝(실시간+녹화)) is treated as in person.
`강의요시: 온라인` rows have no time and stay `unscheduled`.

Searched without a time (2026-11-23): the public 강의계획서 of every other
unscheduled Seoul row (`/sugang/search?attribute=lectPlan&pYear=2026&pTerm=
B01012&pSbjtId=<no>`) and GLOCAL row (`kupis.kku.ac.kr/wsugang/core?attribute=
lectPlan`) only give office hours or exam times.

Usage: python3 tool/timetable/apply_konkuk_seoul_remark_times.py
"""
import json
import re
from pathlib import Path

SEOUL = Path('assets/timetable/konkuk-seoul-2026-2.json')
DAYS = '월화수목금토일'
TIME = re.compile(r'강의요시: ([월화수목금토일]) (\d{2}):(\d{2})~(\d{2}):(\d{2})')
NOTE = ('종합강의시간표 비고의 강의요시(주관 대학 시각) 그대로 확정'
        ' · 운영 방식 미표기·e-러닝 혼합은 대면으로 간주')


def meeting(remark):
    found = TIME.findall(remark)
    if len(found) != 1:
        raise ValueError('Expected one 강의요시 time: ' + remark)
    day, sh, sm, eh, em = found[0]
    start, end = int(sh) * 60 + int(sm), int(eh) * 60 + int(em)
    if not start < end:
        raise ValueError('Invalid 강의요시 range: ' + remark)
    return {'weekday': DAYS.index(day) + 1, 'startMinute': start,
            'endMinute': end, 'classroom': ''}


assert meeting('강의요시: 금 15:00~17:50') == {
    'weekday': 5, 'startMinute': 900, 'endMinute': 1070, 'classroom': ''}

raw = SEOUL.read_text(encoding='utf-8')
data = json.loads(raw)
changed = 0
for course in data['courses']:
    remarks = course.get('departmentRemarks', {})
    timed = {d: r for d, r in remarks.items() if TIME.search(r)}
    if not timed or course['sourceSchedule'] or course['scheduleStatus'] == 'unrecognized':
        continue
    meetings = [meeting(r) for r in timed.values()]
    if any(m != meetings[0] for m in meetings):
        raise ValueError('Conflicting 강의요시 ' + course['courseCode'])
    course['scheduleStatus'] = 'scheduled'
    course['schedules'] = meetings[:1]
    for department in timed:
        if NOTE not in remarks[department]:
            remarks[department] += ' · ' + NOTE
    changed += 1
SEOUL.write_text(
    json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    + ('\n' if raw.endswith('\n') else ''),
    encoding='utf-8',
)
print('seoul remark times scheduled', changed)
