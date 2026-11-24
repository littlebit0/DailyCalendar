#!/usr/bin/env python3
"""Confirm SSU rows held for 대면+녹화 and operating review (2026-11-23 decision).

The public course list prints weekday(s), HH:mm-HH:mm and '(room-professor)',
e.g. '토 12:00-13:15 (숭덕경상관 02111-이서진)'. Clocks are kept as written and
the room drops the trailing professor name, as in the dataset's regular rows.
Dates follow the dataset's regular weekly pattern. Rows whose official list
has no time at all (사회봉사: 'no in-class lessons', 현장실습: term date range only,
recorded/숭실사이버대 courses with no public syllabus clock) become
'unscheduled' (time not set), per the 2026-11-23 instruction.

    python3 tool/timetable/confirm_held_ssu.py
"""
import collections
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import held_confirm_common as common  # noqa: E402

PATH = 'assets/timetable/ssu-main-2026-2.json'
DAYS = '월화수목금토일'
NOTE = common.DECISION + '.'
DROP = ('현재 공개 강의의 수강 조건을 보존했습니다. 개별 수업 운영 검토 전으로 자동 시간표 추가는 아직 지원하지 않습니다.',)
UNTIMED_NOTE = ('2026-11-23 사용자 지시: 공식 강의시간표·공지·강의계획서 어디에도 수업 요일·시각이 없어 '
                '시간 미정 강좌로 둡니다.')
BLOCK = re.compile(r'((?:[월화수목금토일] )+)(\d{2}):(\d{2})-(\d{2}):(\d{2}) \((.*?)\)(?= [월화수목금토일] |\s*$)')
KEEP = '현재 공개 강의의 수강 조건을 보존했습니다.'


def meetings(text):
    text = text.strip()
    found, position = [], 0
    for match in BLOCK.finditer(text):
        if text[position:match.start()].strip():
            raise ValueError(text)
        position = match.end()
        room = re.sub(r'-[^-()]*$', '', match[6]).strip()
        start = int(match[2]) * 60 + int(match[3])
        end = int(match[4]) * 60 + int(match[5])
        for day in match[1].split():
            found.append({'weekday': DAYS.index(day) + 1, 'startMinute': start,
                          'endMinute': end, 'classroom': room})
    if not found or text[position:].strip():
        raise ValueError(text)
    # Same-time rooms stay separate meetings, as in the dataset's regular rows.
    unique = []
    for m in found:
        if m not in unique:
            unique.append(m)
    return unique


def regular_period(dataset):
    """The teaching period most scheduled rows carry (the term the dates use)."""
    periods = collections.Counter(json.dumps(c['period']) for c in dataset['courses']
                                  if c.get('scheduleStatus', 'scheduled') == 'scheduled' and c.get('period'))
    return json.loads(periods.most_common(1)[0][0])


def main():
    dataset = common.load(PATH)
    dates = common.weekday_dates(dataset)
    period = regular_period(dataset)
    held = 0
    for course in dataset['courses']:
        if course.get('scheduleStatus') != 'unrecognized':
            continue
        if not (course.get('sourceSchedule') or '').strip():
            course['scheduleStatus'] = 'unscheduled'
            course['departmentRemarks'] = {k: '\n'.join(l for l in v.replace(DROP[0], '').split('\n') if l.strip())
                                           + '\n' + UNTIMED_NOTE
                                           for k, v in course['departmentRemarks'].items()}
            held += 1
            continue
        found = meetings(course['sourceSchedule'])
        # Date order, then source order within a day (like the regular rows).
        schedules = [{**m, 'date': d} for d in sorted({d for v in dates.values() for d in v})
                     for m in found if d in dates[m['weekday']]]
        common.confirm(course, schedules, NOTE, DROP)
        course.setdefault('period', period)
    common.save(PATH, dataset, '숭실대 대면+녹화·운영 검토 보류 강좌를 공개 요일·시각으로 확정(2026-11-23 사용자 결정)')
    print('untimed', held)


if __name__ == '__main__':
    main()
