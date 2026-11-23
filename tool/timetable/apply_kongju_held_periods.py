"""Schedule held Kongju 2026-2 courses whose official rows print a weekday and period.

Clock: 2026-2 강의일람표 본책 (https://www.kongju.ac.kr/bbs/KNU/2128/655398/download.do),
"XIII. 강의시간" table 212 (0~9교시, 50분 수업 + 10분 휴식, 0교시 08:00) and the
night table 213 printed under it (평일 10~14교시 18:00~18:45, 18:50~19:35,
19:40~20:25, 20:30~21:15, 21:20~22:05). The book gives no other 10교시 clock, so
the weekday night row applies to every weekday 10+ period. Its Saturday row
(10교시 13:00) would put 토8,9,10 or 토10,11,12 before or over the same row's or
room's own day periods, so Saturday 10+ periods stay held as contradictory.

Held reasons that only said the operation (field/intensive/block, remote),
the published closure list, or the missing 10+ clock was uncertain are
scheduled. Rows with no printed period, conflicting row variants or Saturday
10+ periods are left as they are.

Contract-department rows (sourceId kongju/cheonan/...) print their own clock
(e.g. "08:30~11:20"); the ones held only for "사업주훈련예정" use that clock.

Slots run from a period's start to the next period's start; contiguous slots
on one day in one room merge. Dates are copied from the scheduled courses of
the same family and weekday (9/1~12/7 without holidays and the exam week).
Already scheduled courses are not touched. Idempotent.

    python3 tool/timetable/apply_kongju_held_periods.py
"""
import json
import re
from pathlib import Path

PATHS = sorted(Path('assets/timetable').glob('kongju-*-2026-2.json'))
WEEKDAYS = '월화수목금토'
NIGHT = {10: 1080, 11: 1130, 12: 1180, 13: 1230, 14: 1280}  # table 213 평일 row
CONVERTIBLE = {
    'individualFieldIntensiveOrBlockOperatingBoundsUnknown',
    'currentPublishedClosure',
    'normalDayPeriod10plusNotPublishedOrNightScopeUnknown',
    'remoteOrAsynchronousOperationNotActuallyAllocated',
    'unrecognizedLiteralPeriodSyntax',
    'actualRoomUnpublished',
}
HOLD = re.compile(r' 보류: [A-Za-z0-9]+(?:, [A-Za-z0-9]+)*')
NOTE = ' 공식 강의일람표의 요일·교시로 예약했습니다(운영 방식·폐강 여부는 판단하지 않음).'
NIGHT_NOTE = ' 10교시 이후는 같은 책 강의시간 표의 평일 야간 시각(10교시 18:00~18:45, 45분 수업·5분 휴식)을 따랐습니다.'
EMPLOYER_HELD = ' 사업주훈련예정·승인 여부에 따른 변경 가능으로 예약 보류.'
EMPLOYER_NOTE = ' 원문 비고 "사업주훈련예정"(승인 여부에 따라 변경 가능)이 있으나 원문 실제수업시간으로 예약했습니다.'


def lesson(period, weekday):
    """(start, lesson end, slot end) in minutes, or None when undefined."""
    if 0 <= period <= 9:
        start = 480 + 60 * period
        return start, start + 50, start + 60
    if weekday != 6 and period in NIGHT:
        start = NIGHT[period]
        return start, start + 45, NIGHT.get(period + 1, start + 50)
    return None


def parse_lines(raw):
    """[(weekday, sorted periods, line index)] or None; continuation lines inherit the weekday."""
    out, weekday, continued = [], None, False
    for i, line in enumerate(raw.split('\n')):
        s = re.sub(r'[\s/.]+', ',', line).strip(',')
        if not s:
            continue
        groups = {}
        for m in re.finditer(r'([월화수목금토])?([\d,~]+)', s):
            if m[1]:
                weekday = WEEKDAYS.index(m[1]) + 1
            elif weekday is None:
                return None
            else:
                continued = True
            for part in filter(None, m[2].split(',')):
                a, _, b = part.partition('~')
                groups.setdefault(weekday, set()).update(range(int(a), int(b or a) + 1))
        if ''.join(m[0] for m in re.finditer(r'([월화수목금토])?([\d,~]+)', s)) != s:
            return None
        out += [(wd, sorted(ps), i) for wd, ps in groups.items()]
    return (out or None), continued


def periodic_blocks(raw, room_raw, hours):
    """(exact blocks, slot blocks) or None when the row cannot be read without guessing."""
    parsed = parse_lines(raw)
    if not parsed or not parsed[0]:
        return None
    groups, continued = parsed
    if continued and str(sum(len(ps) for _, ps, _ in groups)) != str(hours).strip():
        return None
    # The room cell is kept verbatim, as in the scheduled rows (no per-line room split).
    room = room_raw
    exact, slots = [], []
    for wd, periods, _ in groups:
        runs = []
        for p in periods:
            if lesson(p, wd) is None:
                return None
            if runs and p == runs[-1][-1] + 1:
                runs[-1].append(p)
            else:
                runs.append([p])
        for ps in runs:
            first, last = lesson(ps[0], wd), lesson(ps[-1], wd)
            exact.append({'weekday': wd, 'startMinute': first[0], 'endMinute': last[1], 'nativePeriods': ps})
            slots.append([wd, first[0], last[2], room])
    merged = []
    for wd, start, end, room in sorted(slots, key=lambda s: (s[0], s[1])):
        p = merged[-1] if merged else None
        if p and p[0] == wd and p[3] == room and start - p[2] < 60:
            p[2] = max(p[2], end)
        else:
            merged.append([wd, start, end, room])
    return exact, merged


def meetings(blocks, dates):
    return sorted(({'date': d, 'weekday': wd, 'startMinute': s, 'endMinute': e, 'classroom': r}
                   for wd, s, e, r in blocks for d in dates[wd]),
                  key=lambda m: (m['date'], m['startMinute']))


def weekday_dates(datasets, family):
    dates = {}
    for data in datasets:
        for c in data['courses']:
            if c['scheduleStatus'] != 'scheduled' or not c['sourceId'].startswith(family):
                continue
            for wd in {s['weekday'] for s in c['schedules']}:
                ds = sorted({s['date'] for s in c['schedules'] if s['weekday'] == wd})
                assert dates.setdefault(wd, ds) == ds, (c['sourceId'], wd)
    return dates


def reword(c, old, new):
    c['remarks'] = c['remarks'].replace(old, new, 1)
    for d, text in (c.get('departmentRemarks') or {}).items():
        c['departmentRemarks'][d] = text.replace(old, new, 1)


def convert_public(c, dates):
    """Return None when scheduled, else why the course stays held."""
    meta = c['sourceEducationalMetadata']
    reasons = meta.get('holdReasons') or []
    if not set(reasons) <= CONVERTIBLE:
        return 'reason:' + ','.join(sorted(set(reasons) - CONVERTIBLE))
    variants = {(v['periodRaw'], v['roomRaw'], v['hours']) for v in meta['originalPublishedRowVariants']}
    if len(variants) != 1:
        return 'variantConflict'
    raw, room, hours = variants.pop()
    parsed = periodic_blocks(raw, room, hours)
    if not parsed:
        return 'saturday10plus' if re.search(r'토[^월화수목금]*1\d', raw) else 'unreadable'
    exact, blocks = parsed
    m = HOLD.search(c['remarks'])
    note = NOTE + (NIGHT_NOTE if any(max(b['nativePeriods']) >= 10 for b in exact) else '')
    if m:
        reword(c, m[0], note)
    c['scheduleStatus'] = 'scheduled'
    c['schedules'] = meetings(blocks, dates)
    meta['exactSourcePeriodicBlocks'] = exact
    meta['holdReasons'] = []
    meta['resolvedHoldReasons'] = reasons
    return None


def convert_contract(c, dates):
    o = c['metadata']['originalEducationalFields']
    if EMPLOYER_HELD not in c['remarks'] or not o.get('startTime') or not o.get('endTime'):
        return 'reason:contract'
    wd = WEEKDAYS.index(o['rawPeriod'][0]) + 1
    minute = lambda t: int(t[:2]) * 60 + int(t[3:])
    c['schedules'] = meetings([[wd, minute(o['startTime']), minute(o['endTime']), o['room']]], dates)
    c['scheduleStatus'] = 'scheduled'
    reword(c, EMPLOYER_HELD, EMPLOYER_NOTE)
    return None


def apply(datasets):
    public = weekday_dates(datasets, 'kongju/current-public/')
    contract = weekday_dates(datasets, 'kongju/cheonan/')
    stats = {}
    for data in datasets:
        for c in data['courses']:
            if c['scheduleStatus'] != 'unrecognized':
                continue
            if c['sourceId'].startswith('kongju/current-public/'):
                held = convert_public(c, public)
            else:
                held = convert_contract(c, contract)
            key = held or 'scheduled'
            stats[key] = stats.get(key, 0) + 1
    return stats


def main():
    datasets = {p: json.loads(p.read_text(encoding='utf-8')) for p in PATHS}
    before = {p: json.dumps(d, ensure_ascii=False, separators=(',', ':')) for p, d in datasets.items()}
    print(apply(list(datasets.values())))
    for path, data in datasets.items():
        text = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
        if text != before[path]:
            path.write_text(text, encoding='utf-8')


if __name__ == '__main__':
    main()
