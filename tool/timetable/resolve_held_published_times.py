#!/usr/bin/env python3
"""Release held (`unrecognized`) courses whose official source already settles them.

Only two evidence-backed cases change; everything else stays `unrecognized`:

1. Untimed: the official timetable prints no day/time at all (empty field) or
   prints only `시간미지정강좌`. That is the `unscheduled` meaning (the school
   publishes no time; 한국기술교육대 prints `0`), so the course becomes
   `unscheduled` with no meetings.
   Closed courses (remark `폐강`) stay held.
2. Published clock, no delivery-mode ambiguity:
   - CNU: the public course list prints `요일HH:MM~HH:MM(강의실)`
     (`sourceEducation.actualDisplayedClocks`). Held rows whose lesson method
     (`LSN_METHOD_CD_NM`) is empty — the same fields as the already scheduled
     rows — become weekly meetings at the printed clock.
   - HUFS: period rows `요일 n n (강의실)` without a mode note, converted with
     the official period table already used for the scheduled rows (서울 수강편람
     134쪽: 교시 시작 60분 간격, 1교시 09:00, 0~12교시; 슬롯 = 수업 50분 + 쉬는
     시간 10분). Periods outside 0~12 stay held.

    python3 tool/timetable/resolve_held_published_times.py
"""
import datetime
import json
import re
from pathlib import Path

ROOT = Path('assets/timetable')
UNTIMED_FILES = [
    'hufs-seoul', 'hufs-global', 'hoseo-unknown', 'hoseo-asan', 'hoseo-cheonan',
    'hanyang-seoul', 'hanyang-erica', 'chosun-unknown', 'tuk-first',
    'tuk-unknown', 'koreatech-unknown', 'hansung-main',
]
DAYS = '월화수목금토일'
CNU_HOLD = '수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.'
CNU_PLAN = ('학교 자체 2026-2 수업기간과 현재 공식 공개 요일·실제 시작/끝 시각·강의실의 정규 주간 예약 계획입니다. '
            '학교 정기휴업일과 12/8~11 보충기간, 공휴일은 예약을 제외하며 개별 보강·시험을 추정하지 않습니다.')
HUFS_HOLD = ' · 공개 운영 일정 확인 중: 자동 시간 생성 보류'
HUFS_MODE = ('비대면', '원격', '사이버', '실시간', '혼합', '블렌디드', '플립', 'MOOC', '13교시')


def remarks(course):
    return ' '.join((course.get('departmentRemarks') or {}).values())


# 한국기술교육대 편람은 수업 시각이 없는 강좌의 강의시간을 '0'으로 적는다.
# MEC367-03은 편람·정정 내역이 서로 달라 보류한다.
ZERO_HOUR_HELD = {'koreatech/unknown/2026-2/MEC367-03'}


def untimed(course):
    src = (course.get('sourceSchedule') or '').strip()
    if course['sourceId'].startswith('koreatech/') and src == '0':
        return course['sourceId'] not in ZERO_HOUR_HELD
    parts = [p.strip() for p in src.split(',')] if src else []
    return all(p == '시간미지정강좌' for p in parts) and '현재 폐강' not in remarks(course)


def strip_note(course, note, replacement=''):
    course['departmentRemarks'] = {
        k: (v.replace(note, replacement) if replacement else v.replace('\n' + note, '').replace(note, '')).strip()
        for k, v in (course.get('departmentRemarks') or {}).items()
    }


def cnu_meetings(course):
    edu = course.get('sourceEducation') or {}
    fields = edu.get('originalEducationFields') or {}
    if fields.get('LSN_METHOD_CD_NM') or fields.get('CLOSE_YN') != '0':
        return None
    if fields.get('CNCL_LT_YN') or '폐강' in remarks(course):
        return None
    clocks = edu.get('actualDisplayedClocks') or []
    if not clocks:
        return None
    out = []
    for c in clocks:
        if not (1 <= c['weekday'] <= 7 and 0 <= c['startMinute'] < c['endMinute'] <= 1440):
            raise ValueError(course['sourceId'])
        out.append({'weekday': c['weekday'], 'startMinute': c['startMinute'],
                    'endMinute': c['endMinute'], 'classroom': c['location']})
    course['period'] = {'startDate': '2026-09-01', 'endDate': '2026-12-18'}
    return dated(course, out, CNU_CLOSED, datetime.date(2026, 12, 18))


def hufs_meetings(course):
    src = (course.get('sourceSchedule') or '').strip()
    if not src or any(m in remarks(course) for m in HUFS_MODE):
        return None
    blocks = list(re.finditer(r'([^()]+)\(([^()]*)\)', src))
    if ' '.join(b[0].strip() for b in blocks) != src:
        return None
    out = []
    for block in blocks:
        times, room = block[1].strip(), block[2].strip()
        groups = list(re.finditer(r'([월화수목금토일])\s+((?:\d+\s*)+)', times))
        if ' '.join(g[0].strip() for g in groups) != times:
            return None
        for g in groups:
            periods = [int(v) for v in g[2].split()]
            if periods != sorted(set(periods)) or not all(0 <= p <= 12 for p in periods):
                return None
            prev = None
            for p in periods:
                start = 540 + 60 * (p - 1)
                if prev and prev['endMinute'] == start:
                    prev['endMinute'] = start + 60
                else:
                    prev = {'weekday': DAYS.index(g[1]) + 1, 'startMinute': start,
                            'endMinute': start + 60, 'classroom': room}
                    out.append(prev)
    return dated(course, out, HUFS_CLOSED, datetime.date(2026, 12, 7))


# Same rule as the scheduled HUFS rows: every week in the course `period`
# (9/1~12/7), skipping the school closure days the existing rows skip.
HUFS_CLOSED = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}


# Same rule as the scheduled CNU rows (their remark): 9/1~12/18, skipping
# 공휴일·정기휴업일 and the 12/8~11 보충기간.
CNU_CLOSED = HUFS_CLOSED | {'2026-12-08', '2026-12-09', '2026-12-10', '2026-12-11'}


def dated(course, weekly, closed, last):
    period = course.get('period') or {}
    start = datetime.date.fromisoformat(period['startDate'])
    # HUFS term-periods.json note: regular derived dates end Dec 7 (보강·기말 주간 제외)
    end = min(datetime.date.fromisoformat(period['endDate']), last)
    out = []
    day = start
    while day <= end:
        iso = day.isoformat()
        if iso not in closed:
            for m in weekly:
                if m['weekday'] == day.isoweekday():
                    out.append({**m, 'date': iso})
        day += datetime.timedelta(days=1)
    return out


def recount(data):
    counts = {}
    for c in data['courses']:
        counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
    if 'courseScheduleStatusCounts' in data:
        data['courseScheduleStatusCounts'] = counts
    return counts


def process(name, timed=None, note=None, replacement=''):
    path = ROOT / f'{name}-2026-2.json'
    data = json.loads(path.read_text())
    changed = {'unscheduled': 0, 'scheduled': 0}
    for course in data['courses']:
        if course['scheduleStatus'] != 'unrecognized':
            continue
        meetings = timed(course) if timed else None
        if meetings:
            course['schedules'] = meetings
            course['scheduleStatus'] = 'scheduled'
            changed['scheduled'] += 1
        elif name in UNTIMED_FILES and untimed(course):
            course['scheduleStatus'] = 'unscheduled'
            changed['unscheduled'] += 1
        else:
            continue
        if note:
            strip_note(course, note, replacement)
    counts = recount(data)
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')))
    print(name, changed, counts)


def main():
    process('cnu-unknown', cnu_meetings, CNU_HOLD, CNU_PLAN)
    for name in ('hufs-seoul', 'hufs-global'):
        process(name, hufs_meetings, HUFS_HOLD)
    for name in UNTIMED_FILES:
        if not name.startswith('hufs'):
            process(name)


if __name__ == '__main__':
    main()
