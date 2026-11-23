#!/usr/bin/env python3
"""Confirm Sookmyung rows held for BL/intensive/individual operation (2026-11-23 decision).

The public course list gives weekdays and HH:mm-HH:mm with the room, e.g.
'월수16:30-17:45(명신관505)'; those clocks are used as written. Dates follow
the dataset's regular reservation pattern (the same dates every other course
on that weekday uses). A row with no 강의시간 whose 수강유의사항 names live
weeks and a clock ('1,7,14주차 실시간 수업: (목) 19:00~19:50') gets only those
weeks (week n = the n-th 7 days from 개강 9/1); a weekly row whose note names
its weeks ('비연속형 1~7주, 14주') keeps only those weeks. Other rows with no
published time stay held.

    python3 tool/timetable/confirm_held_sookmyung.py
"""
import datetime
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import held_confirm_common as common  # noqa: E402

PATHS = ['assets/timetable/sookmyung-first-2026-2.json', 'assets/timetable/sookmyung-second-2026-2.json',
         'assets/timetable/sookmyung-unknown-2026-2.json']
DAYS = '월화수목금토일'
NOTE = common.DECISION + '.'
OPENING = datetime.date(2026, 9, 1)
LIVE = re.compile(r'(\d+(?:,\d+)*)주차 실시간 수업: \(([월화수목금토일])\) (\d{1,2}):(\d{2})~(\d{1,2}):(\d{2})')
LINE = re.compile(r'([월화수목금토일]+)(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})\(([^()]*)\)')


def meetings(text):
    found = []
    for line in text.split('\n'):
        match = LINE.fullmatch(line.strip())
        if not match:
            raise ValueError(text)
        start = int(match[2]) * 60 + int(match[3])
        end = int(match[4]) * 60 + int(match[5])
        for day in match[1]:
            found.append({'weekday': DAYS.index(day) + 1, 'startMinute': start,
                          'endMinute': end, 'classroom': match[6]})
    return common.merge(found, join=False)


def week_of(date):
    return (datetime.date.fromisoformat(date) - OPENING).days // 7 + 1


def listed_weeks(course):
    """Weeks named by a '비연속형 1~7주, 14주' note, or None."""
    notes = {r['values'].get('수강유의사항', '') for r in course['metadata']['originalEducationalRecords']}
    found = {m[1] for note in notes for m in re.finditer(r'비연속형 ((?:\d+(?:~\d+)?주[, ]*)+)', note)}
    if len(found) != 1:
        return None
    weeks = set()
    for part in found.pop().replace('주', '').strip(', ').split(','):
        first, _, last = part.strip().partition('~')
        weeks |= set(range(int(first), int(last or first) + 1))
    return weeks


def live_weeks(course):
    notes = {r['values'].get('수강유의사항', '') for r in course['metadata']['originalEducationalRecords']}
    found = {m.groups() for note in notes for m in LIVE.finditer(note)}
    if len(found) != 1:
        return None
    weeks, day, sh, sm, eh, em = found.pop()
    weekday = DAYS.index(day) + 1
    schedules = []
    for week in map(int, weeks.split(',')):
        date = OPENING + datetime.timedelta(days=7 * (week - 1) + (weekday - OPENING.isoweekday()) % 7)
        schedules.append({'weekday': weekday, 'startMinute': int(sh) * 60 + int(sm),
                          'endMinute': int(eh) * 60 + int(em), 'classroom': '', 'date': date.isoformat()})
    return schedules


def main():
    for path in PATHS:
        dataset = common.load(path)
        dates = common.weekday_dates(dataset)
        held = 0
        for course in dataset['courses']:
            if course.get('scheduleStatus') != 'unrecognized':
                continue
            if (course.get('sourceSchedule') or '').strip():
                schedules = common.expand(meetings(course['sourceSchedule']), dates)
                weeks = listed_weeks(course)
                if weeks:
                    schedules = [s for s in schedules if week_of(s['date']) in weeks]
            else:
                schedules = live_weeks(course)
                if not schedules:
                    held += 1
                    continue
            reason = re.findall(r' 예약 보류: [^.]*\.', course.get('remarks') or '')
            common.confirm(course, schedules, NOTE, reason)
            course['metadata']['holdReasons'] = []
        common.save(path, dataset, '숙명여대 BL·집중이수·개별 운영 보류 강좌를 공개 요일·시각으로 확정(2026-11-23 사용자 결정)')
        print(path, 'held', held)


if __name__ == '__main__':
    main()
