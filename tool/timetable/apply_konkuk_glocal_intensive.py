"""Schedule Konkuk GLOCAL 집중이수 offerings whose public syllabus confirms the weeks.

The GLOCAL timetable publishes 집중이수 weeks (e.g. 8주(1-8주)) but no dates, so
`import_konkuk.py` holds them as `unrecognized`. The public 강의계획서
(`/wsugang/core?attribute=lectPlan`, no login) gives each week's dates. An
offering is scheduled only when its syllabus marks every week outside the
published range as no class and no week inside it as no class; its weekly
meetings are then limited to that range with a course `period`. Contradicting
syllabi stay `unrecognized`.

Usage: python3 tool/timetable/apply_konkuk_glocal_intensive.py <plan-check.json>
(`plan-check.json`: {lec_no: {ok, start, end, weeks}} built from the saved
syllabi; see the PR for the collection.)
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from import_konkuk import glocal_meetings  # noqa: E402

PATH = Path('assets/timetable/konkuk-glocal-2026-2.json')
PLAN_URL = 'https://kupis.kku.ac.kr/wsugang/core?attribute=lectPlan'

checks = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
raw = PATH.read_text(encoding='utf-8')
data = json.loads(raw)
changed = 0
for course in data['courses']:
    check = checks.get(course['courseCode'])
    if course['scheduleStatus'] != 'unrecognized' or not check or not check['ok']:
        continue
    status, meetings = glocal_meetings(course['sourceSchedule'])
    if status != 'scheduled':
        raise ValueError('Unparsed GLOCAL schedule ' + course['courseCode'])
    a, b = check['weeks']
    course['scheduleStatus'] = 'scheduled'
    course['schedules'] = meetings
    course['sourceClassroom'] = ' / '.join(dict.fromkeys(
        m['classroom'] for m in meetings if m['classroom']))
    course['period'] = {'startDate': check['start'], 'endDate': check['end']}
    note = (f'공개 강의계획서({PLAN_URL}) 주차별 계획: {a}-{b}주'
            f' {check["start"]}~{check["end"]}만 수업, 나머지 주차 미진행')
    for department in course.get('departmentRemarks', {}):
        remark = course['departmentRemarks'][department]
        course['departmentRemarks'][department] = (remark + ' · ' if remark else '') + note
    changed += 1
PATH.write_text(
    json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    + ('\n' if raw.endswith('\n') else ''),
    encoding='utf-8',
)
print('scheduled', changed)
