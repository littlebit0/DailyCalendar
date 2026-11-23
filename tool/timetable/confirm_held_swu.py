#!/usr/bin/env python3
"""Confirm SWU rows held for intensive, chapel or Bahrom operation (2026-11-23 decision).

Clock: the dataset's regular rows use periods 1-6 as 90-minute slots from
09:00 and periods 7-9 as 60-minute slots from 18:00 (Bahrom page: 8-9교시 =
19:00-20:50). Dates:
- Bahrom (바롬인성교육): only the row's own 교육기간 (bahrom.swu.ac.kr
  about2504_1, 차수 by 분반), skipping a '(m/d~m/d 교육 미운영)' week and holidays.
- Chapel (경건회) 01-05: the regular weekly pattern from 개강 9/16 (notice).
- 10-week intensive courses: the regular weekly pattern.
The regular pattern includes the makeup days on which another weekday's
classes are held (e.g. 12/8 holds Monday classes), read from the dataset's
regular rows.
Rows without a weekday ('방학중') and the separate chapel code whose '일1'
contradicts the official notice stay held.

    python3 tool/timetable/confirm_held_swu.py
"""
import collections
import datetime
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import held_confirm_common as common  # noqa: E402

PATH = 'assets/timetable/swu-main-2026-2.json'
DAYS = '월화수목금토일'
NOTE = common.DECISION + '.'
CHAPEL_START = '2026-09-16'
DROP_LINES = ('10주 집중이수 강좌입니다.', '합숙/캠프형 바롬인성교육은', '전체 경건회 회차별 운영일은 추가 확인 필요.')


def slot(period):
    if 1 <= period <= 6:
        return 540 + (period - 1) * 90, 540 + period * 90
    if 7 <= period <= 9:
        return 1080 + (period - 7) * 60, 1080 + (period - 6) * 60
    raise ValueError(period)


def meetings(text):
    schedule, _, rooms_text = text.partition(' / ')
    rooms = [r.strip() for r in rooms_text.replace('\r', '').split('\n') if r.strip()]
    items = []
    for group in schedule.split('/'):
        match = re.fullmatch(r'([월화수목금토일])([\d~,]+)', group.strip())
        if not match:
            raise ValueError(text)
        for block in match[2].split(','):
            first, _, last = block.partition('~')
            items.append((DAYS.index(match[1]) + 1, slot(int(first))[0], slot(int(last or first))[1]))
    if len(set(rooms)) == 1:
        room_of = [rooms[0]] * len(items)
    elif len(rooms) == len(items):
        room_of = rooms
    else:
        room_of = [''] * len(items)
    return common.merge({'weekday': w, 'startMinute': s, 'endMinute': e, 'classroom': r}
                        for (w, s, e), r in zip(items, room_of))


def bahrom_dates(remark, regular):
    match = re.search(r'교육기간: (\d{4}-\d{2}-\d{2}) ~ (\d{4}-\d{2}-\d{2})', remark)
    skip = re.search(r'\((\d+)/(\d+)~(\d+)/(\d+) 교육 미운영\)', remark)
    day, last = (datetime.date.fromisoformat(v) for v in match.groups())
    skipped = (datetime.date(day.year, int(skip[1]), int(skip[2])),
               datetime.date(day.year, int(skip[3]), int(skip[4]))) if skip else None
    out = {}
    while day <= last:
        iso, weekday = day.isoformat(), day.isoweekday()
        pattern = regular.get(weekday, [])
        # A date inside the regular range but missing from it is a holiday.
        holiday = pattern and pattern[0] <= iso <= pattern[-1] and iso not in pattern
        if not holiday and not (skipped and skipped[0] <= day <= skipped[1]):
            out.setdefault(weekday, []).append(iso)
        day += datetime.timedelta(days=1)
    return out


def regular_period(dataset):
    """The teaching period most scheduled rows carry (the term the dates use)."""
    periods = collections.Counter(json.dumps(c['period']) for c in dataset['courses']
                                  if c.get('scheduleStatus', 'scheduled') == 'scheduled' and c.get('period'))
    return json.loads(periods.most_common(1)[0][0])


def makeup_days(dataset, regular):
    """{native weekday: [makeup dates]} where a date holds another weekday's classes."""
    votes = collections.defaultdict(collections.Counter)
    for c in dataset['courses']:
        native = {s['weekday'] for s in c.get('sourceSnapshotSchedules') or []}
        if c.get('scheduleStatus', 'scheduled') != 'scheduled' or len(native) != 1:
            continue
        for s in c['schedules']:
            if s.get('date') and s['weekday'] not in native and s['date'] not in regular.get(s['weekday'], []):
                votes[s['date']][next(iter(native))] += 1
    out = collections.defaultdict(list)
    for date, counter in sorted(votes.items()):
        out[counter.most_common(1)[0][0]].append(date)
    return out


def main():
    dataset = common.load(PATH)
    regular = common.weekday_dates(dataset)
    term = regular_period(dataset)
    makeups = makeup_days(dataset, regular)
    held = []
    for course in dataset['courses']:
        if course.get('scheduleStatus') != 'unrecognized':
            continue
        remark = '\n'.join((course.get('departmentRemarks') or {}).values()) or course.get('remarks') or ''
        text = course['sourceSchedule']
        if text.startswith('방학중') or '공식 운영안내와 대조되지 않아' in remark:
            held.append(text)
            continue
        found = meetings(text)
        if course['courseName'] == '바롬인성교육':
            dates = bahrom_dates(remark, regular)
        else:
            dates = regular
        if course['courseName'] == '경건회':
            dates = {w: [d for d in v if d >= CHAPEL_START] for w, v in regular.items()}
        if course['courseName'] == '바롬인성교육':
            schedules = common.expand(found, dates)
        else:
            schedules = sorted(
                [{**m, 'weekday': datetime.date.fromisoformat(d).isoweekday(), 'date': d}
                 for m in found for d in dates.get(m['weekday'], []) + makeups.get(m['weekday'], [])
                 if course['courseName'] != '경건회' or d >= CHAPEL_START],
                key=lambda s: (s['date'], s['startMinute'], s['classroom']))
        course.setdefault('period', term)
        period = course['period']
        schedules = [s for s in schedules if period['startDate'] <= s['date'] <= period['endDate']]
        drop = [line for line in remark.split('\n') if line.startswith(DROP_LINES)]
        common.confirm(course, schedules, NOTE, drop)
    common.save(PATH, dataset, '서울여대 10주 집중이수·경건회·바롬인성교육 보류 강좌를 공식 교시·교육기간으로 확정(2026-11-23 사용자 결정)')
    print('held', held)


if __name__ == '__main__':
    main()
