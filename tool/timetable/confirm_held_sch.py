#!/usr/bin/env python3
"""Confirm SCH rows held for periods 10-15, weekends or missing rooms (2026-11-23 decision).

Official period table (2023 요람 p.65, department timetable notice): period 1
at 09:00, 60-minute periods, 30-minute A/B halves (pA = start, pB = start+30).
Periods 10-15 and Saturday/Sunday continue the same table (15 = 23:00-24:00).
Dates follow the dataset's regular weekly pattern. Rows without a weekday stay
held.

    python3 tool/timetable/confirm_held_sch.py
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import held_confirm_common as common  # noqa: E402

PATH = 'assets/timetable/sch-unknown-2026-2.json'
DAYS = '월화수목금토일'
# Closure dates the dataset's reservation plan already excludes (Chuseok 9/24-27).
EXCLUDED = {'2026-09-27'}
NOTE = common.DECISION + '. 10교시 이후·토·일은 공식 교시표와 같은 60분 교시로 이어 계산.'


def start_of(period, half=''):
    return 480 + period * 60 + (30 if half == 'B' else 0)


def item_range(item):
    match = re.fullmatch(r'(\d+)([AB])-(\d+)([AB])', item)
    if match:
        p, h, q, k = int(match[1]), match[2], int(match[3]), match[4]
        return start_of(p, h), start_of(q, k) + 30
    if re.fullmatch(r'\d+', item):
        return start_of(int(item)), start_of(int(item)) + 60
    raise ValueError(item)


def meetings(text, rooms_text):
    groups = []
    for group in text.split('/'):
        match = re.fullmatch(r'([월화수목금토일])(.+)', group)
        if not match:
            raise ValueError(text)
        groups.append((DAYS.index(match[1]) + 1, match[2].split(',')))
    items = [(w, it, gi) for gi, (w, its) in enumerate(groups) for it in its]
    rooms = rooms_text.split('/') if rooms_text else ['']
    if len(rooms) == len(items):
        room_of = lambda index, gi: rooms[index]
    elif len(rooms) == len(groups):
        room_of = lambda index, gi: rooms[gi]
    elif len(rooms) == 1:
        room_of = lambda index, gi: rooms[0]
    else:
        # Room-to-period split is not published; keep every listed room.
        room_of = lambda index, gi: ', '.join(rooms)
    by_time = {}
    for index, (weekday, item, gi) in enumerate(items):
        start, end = item_range(item)
        if not 0 <= start < end <= 1440:
            raise ValueError(text)
        by_time.setdefault((weekday, start, end), []).append(room_of(index, gi))
    return common.merge({'weekday': w, 'startMinute': s, 'endMinute': e,
                         'classroom': ', '.join(dict.fromkeys(r))}
                        for (w, s, e), r in by_time.items())


def main():
    dataset = common.load(PATH)
    dates = common.weekday_dates(dataset)
    held = []
    for course in dataset['courses']:
        if course.get('scheduleStatus') != 'unrecognized':
            continue
        try:
            found = meetings(course['sourceSchedule'], course.get('sourceClassroom') or '')
        except ValueError:
            held.append(course['sourceSchedule'])
            continue
        period = course.get('period') or {}
        schedules = [s for s in common.expand(found, dates)
                     if period.get('startDate', '') <= s['date'] <= period.get('endDate', '9999')
                     and s['date'] not in EXCLUDED]
        common.confirm(course, schedules, NOTE)
    common.save(PATH, dataset, '순천향대 10~15교시·토·일·강의실 미기재 보류 강좌를 공식 60분 교시로 확정(2026-11-23 사용자 결정)')
    print('held', held)


if __name__ == '__main__':
    main()
