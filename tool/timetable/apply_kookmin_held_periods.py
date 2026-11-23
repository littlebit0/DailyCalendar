#!/usr/bin/env python3
"""Confirm Kookmin held courses whose official catalog publishes HH:mm clocks.

2026-11-23 decision: an official weekday and clock is the teaching time even
when the operation mode (blended, field training, social service) is unclear.
Published clocks are used as-is and merged with import_kookmin.meetings_for, so
the result matches every other scheduled Kookmin course. Courses whose official
sources contradict each other stay unrecognized. Re-running changes nothing.

2026-11-23 decision: a section the official catalog still lists with closed=true
(폐강) is kept like any other row. --snapshot takes a fresh public traversal
(fetch_college_scope.py records + commoncodes/all) and adds those undergraduate
rows through import_kookmin.convert. Sections missing from the catalog are not
added. Without --snapshot only the held-clock step runs.

    python3 tool/timetable/apply_kookmin_held_periods.py \
        [--snapshot DIR containing college-scope.json and commoncodes.json]
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / 'assets/timetable/kookmin-main-2026-2.json'
_spec = importlib.util.spec_from_file_location(
    'import_kookmin', ROOT / 'tool/timetable/import_kookmin.py')
import_kookmin = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(import_kookmin)

BLOCK_NOTE = ('실제 적용 수업일·기간 확인 필요: 진행 방식도 확인 전에는 '
              '공개 시각을 학기 전체에 반복하지 않음')
CONFIRMED_NOTE = '공식 요일·시각으로 확정(운영 방식 세부는 미게시)'
# The syllabus start (18:30) contradicts the catalog clock (18:00), so it stays held.
CONTRADICTED = {'1659202-51'}
# Stale instructions written while the course was held; the facts before them stay.
STALE_CLAUSES = ['; API14~17로 Zoom3시간 생성 금지']
LINE = re.compile(r'^([월화수목금토일])요일 (\d{2}):(\d{2})~(\d{2}):(\d{2})$')
DAY_NAMES = {label: name for label, name in zip(
    import_kookmin.DAY_LABELS, import_kookmin.DAYS)}


def meetings(course):
    room = course['sourceClassroom']
    if '\n' in room:
        raise ValueError(f"{course['sourceId']}: several rooms need per-meeting proof")
    times = []
    for line in course['sourceSchedule'].split('\n'):
        match = LINE.match(line)
        if not match:
            raise ValueError(f"{course['sourceId']}: unexpected clock {line!r}")
        day, sh, sm, eh, em = match.groups()
        start, end = int(sh) * 60 + int(sm), int(eh) * 60 + int(em)
        times.append({'dayOfWeek': DAY_NAMES[day], 'classRoomName': room,
                      'start': {'hour': int(sh), 'minute': int(sm)},
                      'end': {'hour': int(eh), 'minute': int(em)},
                      'minutes': end - start})
    return import_kookmin.meetings_for({'schedule': {'lectureTimes': times}})


CLOSED_NOTE = '공식 개설강좌 조회에 폐강(closed) 표기로 게시된 분반'


def closed_courses(records, dictionary):
    rows = [dict(row, closed=False) for row in records
            if row['standardDeptCode'] == '20000' and row['closed']]
    courses, _ = import_kookmin.convert(rows, dictionary, [])
    for course in courses:
        for department, text in course['departmentRemarks'].items():
            course['departmentRemarks'][department] = '\n'.join(filter(None, [text, CLOSED_NOTE]))
    return courses


def add_closed(data, courses):
    present = {course['sourceId'] for course in data['courses']}
    added = [course for course in courses if course['sourceId'] not in present]
    data['courses'].extend(added)
    return [course['sourceId'] for course in added]


def apply(data):
    changed = []
    for course in data['courses']:
        key = f"{course['courseCode']}-{course['section']}"
        if course['scheduleStatus'] != 'unrecognized' or key in CONTRADICTED:
            continue
        course['schedules'] = meetings(course)
        course['scheduleStatus'] = 'scheduled'
        for department, text in course['departmentRemarks'].items():
            for clause in STALE_CLAUSES:
                text = text.replace(clause, '')
            course['departmentRemarks'][department] = text.replace(BLOCK_NOTE, CONFIRMED_NOTE)
        changed.append(key)
    return changed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--snapshot', type=Path)
    args = parser.parse_args()
    data = json.loads(ASSET.read_text(encoding='utf-8'))
    added = []
    if args.snapshot:
        records = json.loads((args.snapshot / 'college-scope.json').read_text(encoding='utf-8'))['records']
        dictionary = json.loads((args.snapshot / 'commoncodes.json').read_text(encoding='utf-8'))
        added = add_closed(data, closed_courses(records, dictionary))
        print('closed sections added', len(added))
    changed = apply(data)
    if changed or added:
        ASSET.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')),
                         encoding='utf-8')
    print('confirmed', len(changed), changed)


if __name__ == '__main__':
    main()
