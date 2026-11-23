"""Schedule held GKNU 2026-2 courses whose official period numbers run past 9.

Official clock: https://www.gknu.ac.kr/main/html.do?menu_idx=134 (수업시간,
"50분 수업"): 0교시 08:00~08:50 ... 10A교시 18:00~18:50, one period per hour.
The importer only scheduled periods 0-9; 11-13교시 are not printed, so they
continue the same 60-minute slot (period n starts at (8+n):00).

Slots run from a period's start to the next period's start (break included),
contiguous periods form one block, and meeting dates are copied from the
dataset's own scheduled courses on the same weekday. Already scheduled courses
and courses without a printed weekday/period are left alone. Idempotent.

    python3 tool/timetable/apply_gknu_held_periods.py
"""
import json
import re
from pathlib import Path

PATHS = sorted(Path('assets/timetable').glob('gknu-*-2026-2.json'))
WEEKDAYS = '월화수목금토'
HELD = ' 야간 교시의 실제 종료 시각 미확인으로 예약 보류.'
NOTE = (' 10교시는 공식 수업시간표(menu_idx=134)의 18:00~18:50이고, 표에 없는 11~13교시는'
        ' 같은 60분 간격으로 이어 계산했습니다.')
SOURCE = re.compile(r'^([월화수목금토])(\d+(?:,\d+)*)\[([^\]]*)\]$')


def weekday_dates(courses):
    dates = {}
    for c in courses:
        if c['scheduleStatus'] != 'scheduled':
            continue
        for wd in {s['weekday'] for s in c['schedules']}:
            ds = sorted({s['date'] for s in c['schedules'] if s['weekday'] == wd})
            assert dates.setdefault(wd, ds) == ds, (c['sourceId'], wd)
    return dates


def slots(source):
    m = SOURCE.match(source)
    if not m:
        return None
    periods = sorted({int(p) for p in m[2].split(',')})
    if periods != list(range(periods[0], periods[-1] + 1)):
        return None
    return WEEKDAYS.index(m[1]) + 1, (8 + periods[0]) * 60, (9 + periods[-1]) * 60, m[3]


def apply(data, dates):
    changed = 0
    for c in data['courses']:
        if c['scheduleStatus'] != 'unrecognized':
            continue
        parsed = slots(c['sourceSchedule'])
        if not parsed:
            continue
        wd, start, end, room = parsed
        c['schedules'] = [{'date': d, 'weekday': wd, 'startMinute': start, 'endMinute': end,
                           'classroom': room} for d in dates[wd]]
        c['scheduleStatus'] = 'scheduled'
        c['remarks'] = c['remarks'].replace(HELD, '') + NOTE
        c['metadata']['clockSupported'] = True
        changed += 1
    return changed


def main():
    datasets = {p: json.loads(p.read_text(encoding='utf-8')) for p in PATHS}
    dates = {}
    for data in datasets.values():
        for wd, ds in weekday_dates(data['courses']).items():
            assert dates.setdefault(wd, ds) == ds, wd
    for path, data in datasets.items():
        n = apply(data, dates)
        if n:
            path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
        print(path, 'scheduled', n)


if __name__ == '__main__':
    main()
