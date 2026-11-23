#!/usr/bin/env python3
"""Release held (`unrecognized`) courses whose official source already settles them.

2026-11-23 사용자 결정: 공식 요일·교시(시각)가 있으면 운영 방식(비대면·원격·혼합·
콘텐츠·실습·집중 등)이 불명확해도 대면 수업으로 보고 그 시각으로 확정한다. 폐강
표기는 판단하지 않고 다른 강좌와 같은 규칙으로 처리한다. 공식 교시표는 반대 근거가
없는 한 그 학교 강좌 전체에 적용하고, 표에 없는 교시는 같은 슬롯 길이로 이어 계산한다.

1. Untimed: the official timetable prints no day/time at all (empty field),
   only `시간미지정강좌`, or only `집중수업` (한국기술교육대 prints `0`). That is the
   `unscheduled` meaning, so the course becomes `unscheduled` with no meetings.
2. Published clock or period, converted exactly like the already scheduled rows
   of the same dataset:
   - CNU: printed `요일HH:MM~HH:MM(강의실)` (`sourceEducation.actualDisplayedClocks`).
   - HUFS: `요일 n n (강의실)`, 서울 수강편람 134쪽 교시표(1교시 09:00, 60분 슬롯),
     0~13교시(13교시는 같은 60분 슬롯으로 이어 계산).
   - TUK: printed `요일[교시] HH:MM~HH:MM (강의실)` (`import_tuk.meetings`).
   - Hanyang: printed `요일(HH:MM-HH:MM)`.
   - Hoseo: 책자 p.152 교시표 0~14교시(n교시 = 09:00+60n분부터 60분).
   - KOREATECH: 공식 1A~13B 교시표(1교시 09:00, A·B 각 30분), 14교시까지 같은 칸.
   Dates reuse, per weekday, the exact date list the scheduled rows of the same
   dataset use; weekdays without scheduled rows get every week of the same span
   minus closures and public holidays.

Still held: rows whose official sources contradict each other (KOREATECH
MEC367-03·MCA333-02·BSM632-31) and Hanyang 의학과 rows whose own operating period
is not published.

    python3 tool/timetable/resolve_held_published_times.py
"""
import collections
import datetime
import importlib.util
import json
import re
from pathlib import Path

ROOT = Path('assets/timetable')
# Suspended universities keep their datasets out of the app bundle.
SUSPENDED_ROOT = Path('test/fixtures/suspended_assets/timetable')
UNTIMED_FILES = [
    'hufs-seoul', 'hufs-global', 'hoseo-unknown', 'hoseo-asan', 'hoseo-cheonan',
    'hanyang-seoul', 'hanyang-erica', 'chosun-unknown', 'tuk-first',
    'tuk-unknown', 'koreatech-unknown', 'hansung-main', 'cnu-unknown',
]
DAYS = '월화수목금토일'
CNU_HOLD = '수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.'
CNU_PLAN = ('학교 자체 2026-2 수업기간과 현재 공식 공개 요일·실제 시작/끝 시각·강의실의 정규 주간 예약 계획입니다. '
            '학교 정기휴업일과 12/8~11 보충기간, 공휴일은 예약을 제외하며 개별 보강·시험을 추정하지 않습니다.')
HUFS_HOLD = ' · 공개 운영 일정 확인 중: 자동 시간 생성 보류'
DECISION = '2026-11-23 사용자 결정: 공식 요일·시각이 있으면 운영 방식이 불명확해도 그 시각으로 확정'
# 2026 하반기 법정공휴일(대체공휴일 포함)
PUBLIC_HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03',
                   '2026-10-05', '2026-10-09', '2026-12-25'}
# 원문끼리 분반·시간이 서로 달라 보류한다.
CONFLICTING = {'koreatech/unknown/2026-2/MEC367-03'}
KOREATECH_CONFLICT = '원본 숫자 분반 중복 및 상충'
HANYANG_MEDICAL = 'medicalOwnCourseOperatingPeriodUnconfirmed'


def remarks(course):
    return ' '.join((course.get('departmentRemarks') or {}).values())


def untimed(course):
    src = (course.get('sourceSchedule') or '').strip()
    if course['sourceId'].startswith('koreatech/') and src == '0':
        return course['sourceId'] not in CONFLICTING
    parts = [p.strip() for p in src.split(',')] if src else []
    return all(p in ('시간미지정강좌', '집중수업') for p in parts)


def strip_note(course, note, replacement=''):
    course['departmentRemarks'] = {
        k: (v.replace(note, replacement) if replacement else v.replace('\n' + note, '').replace(note, '')).strip()
        for k, v in (course.get('departmentRemarks') or {}).items()
    }


def cnu_meetings(course):
    clocks = (course.get('sourceEducation') or {}).get('actualDisplayedClocks') or []
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
    if not src:
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
            if periods != sorted(set(periods)) or not all(0 <= p <= 13 for p in periods):
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


def date_rule(data):
    """Per-weekday date lists exactly as the dataset's scheduled rows use them."""
    per = collections.defaultdict(collections.Counter)
    periods = collections.Counter()
    for c in data['courses']:
        if c['scheduleStatus'] != 'scheduled':
            continue
        if c.get('period'):
            periods[json.dumps(c['period'], sort_keys=True)] += 1
        by = collections.defaultdict(set)
        for m in c['schedules']:
            if 'date' in m:
                by[m['weekday']].add(m['date'])
        for w, s in by.items():
            per[w][tuple(sorted(s))] += 1
    modal = {w: list(cnt.most_common(1)[0][0]) for w, cnt in per.items()}
    period = json.loads(periods.most_common(1)[0][0]) if periods else None
    if not modal:
        raise ValueError(f"{data.get('universityId')}: no scheduled rows to copy dates from")
    first = datetime.date.fromisoformat(min(d for v in modal.values() for d in v))
    weekday_last = [datetime.date.fromisoformat(v[-1]) for w, v in modal.items() if w <= 5]
    closed = set()
    for v in modal.values():
        day, end = datetime.date.fromisoformat(v[0]), datetime.date.fromisoformat(v[-1])
        while day <= end:
            if day.isoformat() not in v:
                closed.add(day.isoformat())
            day += datetime.timedelta(7)
    if any(d.isoweekday() == 5 for d in weekday_last):
        fri = max(d for d in weekday_last if d.isoweekday() == 5)
    else:  # 금요일 확정 행이 없으면 마지막 평일이 있는 주의 금요일
        last = max(weekday_last)
        fri = last + datetime.timedelta(5 - last.isoweekday())
    # 확정 행이 없는 요일(주로 토·일): 같은 학기 주간에서 휴업일·공휴일을 뺀다.
    for w in range(1, 8):
        if w in modal:
            continue
        day = first + datetime.timedelta((w - first.isoweekday()) % 7)
        end = fri + datetime.timedelta(w - 5) if w > 5 else fri
        out = []
        while day <= end:
            # 앞 금요일과 다음 월요일이 모두 휴업(시험 주간 등)이면 그 주말도 뺀다.
            fri_before = day - datetime.timedelta(day.isoweekday() - 5)
            mon_after = day + datetime.timedelta(8 - day.isoweekday())
            gap = fri_before.isoformat() in closed and mon_after.isoformat() in closed
            if day.isoformat() not in closed | PUBLIC_HOLIDAYS and not gap:
                out.append(day.isoformat())
            day += datetime.timedelta(7)
        modal[w] = out
    return modal, period


def expand(weekly, rule):
    out = [{**m, 'date': d} for m in weekly for d in rule[m['weekday']]]
    out.sort(key=lambda m: m['date'])  # 같은 날은 원문 칸 순서 유지
    return out


def _load_tuk():
    spec = importlib.util.spec_from_file_location('import_tuk', Path(__file__).with_name('import_tuk.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


TUK_DROP = ('미반영 사유:', '부분 시간표:')


def tuk_weekly(course):
    return _load_tuk().meetings(course.get('sourceSchedule') or '') or None


def _drop_tuk_lines(text):
    return '\n'.join(line for line in text.split('\n') if not line.startswith(TUK_DROP))


def tuk_finish(course):
    course['departmentRemarks'] = {k: _drop_tuk_lines(v) for k, v in course['departmentRemarks'].items()}
    if 'remarks' in course:
        course['remarks'] = _drop_tuk_lines(course['remarks'])
    if 'individualBlockingReasons' in course:
        course['individualBlockingReasons'] = []
    if 'sourceEducation' in course:
        course['sourceEducation'] = {**course['sourceEducation'],
                                     'projection': 'publishedRegularTimetable', 'heldOnlineScope': []}


def tuk_partial(course):
    """Scheduled rows that left out their online slots: publish every slot."""
    text = json.dumps(course.get('departmentRemarks'), ensure_ascii=False) + course.get('remarks', '')
    return '부분 시간표:' in text


HANYANG_SLOT = re.compile(r'^([월화수목금토일])\((\d\d):(\d\d)-(\d\d):(\d\d)\)$')


def _hanyang_room(text):
    text = text.strip()
    return '' if not text or text.startswith('비지정(') else text


def hanyang_weekly(course):
    held = ((course.get('metadata') or {}).get('reservationProjection') or {}).get('heldReasons', [])
    if HANYANG_MEDICAL in held:
        return None  # 의학과 자체 수업기간 근거 없음: 학부 날짜를 쓰지 않는다
    parts = [p.strip() for p in (course.get('sourceSchedule') or '').split(',')]
    rooms = (course.get('sourceClassroom') or '').split(',')
    if len(rooms) != len(parts):
        # 강의실 칸 수가 시간 칸 수와 다르면 실제 강의실 이름만 모아 모든 구간에 적는다.
        real = list(dict.fromkeys(r for r in map(_hanyang_room, rooms) if r))
        rooms = [', '.join(real)] * len(parts)
    out = []
    for part, room in zip(parts, rooms):
        if part == '시간미지정강좌':
            continue
        m = HANYANG_SLOT.match(part)
        if not m:
            return None
        start, end = int(m[2]) * 60 + int(m[3]), int(m[4]) * 60 + int(m[5])
        if not 0 <= start < end <= 1440:
            raise ValueError(course['sourceId'])
        out.append({'weekday': DAYS.index(m[1]) + 1, 'startMinute': start,
                    'endMinute': end, 'classroom': _hanyang_room(room)})
    return out or None


def hanyang_finish(course):
    meta = course.get('metadata') or {}
    rp = meta.get('reservationProjection')
    if rp is not None:
        meta['reservationProjection'] = {**rp, 'eligible': True, 'heldReasons': [],
                                         'resolvedDerivedHoldReasons': rp.get('heldReasons', []),
                                         'sourceSemanticReview': DECISION}


HOSEO_PART = re.compile(r'^([월화수목금토일])(\d+)(?:~(\d+))?$')


def hoseo_weekly(course):
    parts = [p.strip() for p in (course.get('sourceSchedule') or '').split(',') if p.strip()]
    room = course.get('sourceClassroom') or ''
    rooms = [r.strip() for r in room.split(' / ')] if room else ['']
    if len(parts) == 1 and len(rooms) > 1:
        label = ' / '.join(f'강의실{i + 1}: {r}' for i, r in enumerate(rooms))
    elif len(rooms) == 1:
        label = rooms[0]
    else:
        label = ''  # 여러 시간·여러 강의실은 짝을 원문이 밝히지 않는다(기존 확정 행과 같은 규칙)
    out = []
    for part in parts:
        m = HOSEO_PART.match(part)
        if not m:
            return None
        a, b = int(m[2]), int(m[3] or m[2])
        if not 0 <= a <= b <= 14:
            return None
        start, end = 540 + 60 * a, 600 + 60 * b
        weekday = DAYS.index(m[1]) + 1
        prev = next((x for x in out if x['weekday'] == weekday and x['classroom'] == label
                     and 0 <= start - x['endMinute'] < 60), None)
        if prev:
            prev['endMinute'] = end
        else:
            out.append({'weekday': weekday, 'startMinute': start, 'endMinute': end, 'classroom': label})
    return out or None


KOREATECH_TOKEN = re.compile(r'^([월화수목금토일])?(\d\d)([AB])(?:~(\d\d)([AB]))?$')
KOREATECH_PERIOD_NOTE = (' 교시 시각: 1교시 09:00 시작·교시당 60분(A·B 각 30분)을 학사운영에 관한 규칙 제53조(50분+휴식 10분)와 '
                         '메카트로닉스공학부·산업경영학부 공식 시간표의 1A~13B=09:00~22:00 표기에 맞춰 적용했고, '
                         '강의실은 공개되지 않아 비워 두었습니다.')


def _koreatech_minute(period, half, end):
    start = 540 + 60 * (period - 1) + (30 if half == 'B' else 0)
    return start + 30 if end else start


def koreatech_weekly(course):
    if course['sourceId'] in CONFLICTING or KOREATECH_CONFLICT in course.get('remarks', ''):
        return None
    body = re.sub(r'\([^()]*\)$', '', (course.get('sourceSchedule') or '').strip())
    out, day = [], None
    for token in body.split(','):
        m = KOREATECH_TOKEN.match(token.strip())
        if not m:
            return None
        day = m[1] or day
        if day is None:
            return None
        a, ah = int(m[2]), m[3]
        b, bh = (int(m[4]), m[5]) if m[4] else (a, ah)
        if not (1 <= a <= 14 and 1 <= b <= 14):
            return None
        start, end = _koreatech_minute(a, ah, False), _koreatech_minute(b, bh, True)
        if start >= end:
            return None
        out.append({'weekday': DAYS.index(day) + 1, 'startMinute': start, 'endMinute': end, 'classroom': ''})
    return out


def koreatech_finish(course):
    if 'remarks' in course:
        course['remarks'] = re.sub(r' 예약 보류: [^.]*\.?$', '', course['remarks']).rstrip() + KOREATECH_PERIOD_NOTE


def recount(data):
    counts = {}
    for c in data['courses']:
        counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
    if 'courseScheduleStatusCounts' in data:
        data['courseScheduleStatusCounts'] = counts
    if isinstance(data.get('counts'), dict):
        data['counts'] = {k: counts.get(k, 0) for k in data['counts']}
    return counts


def dataset_path(name, root=None, suspended=None):
    for base in (root or ROOT, suspended or SUSPENDED_ROOT):
        path = Path(base) / f'{name}-2026-2.json'
        if path.exists():
            return path
    raise FileNotFoundError(f'{name}-2026-2.json')


def process(name, timed=None, note=None, replacement='', path=None, rule_from=None):
    """`timed` returns dated meetings; a (weekly, finish, partial) tuple uses the dataset date rule."""
    path = path or dataset_path(name)
    data = json.loads(path.read_text(encoding='utf-8'))
    changed = {'unscheduled': 0, 'scheduled': 0}
    weekly = finish = partial = None
    if isinstance(timed, tuple):
        weekly, finish, partial = timed
        timed = None
    rule = period = None
    for course in data['courses']:
        held = course['scheduleStatus'] == 'unrecognized'
        if not held and not (partial and course['scheduleStatus'] == 'scheduled' and partial(course)):
            continue
        meetings = None
        if weekly:
            slots = weekly(course)
            if slots:
                if rule is None:
                    rule, period = date_rule(rule_from or data)
                meetings = expand(slots, rule)
                if period and not course.get('period'):
                    course['period'] = period
        elif timed:
            meetings = timed(course)
        if meetings:
            course['schedules'] = meetings
            course['scheduleStatus'] = 'scheduled'
            changed['scheduled'] += 1
            if finish:
                finish(course)
        elif held and name in UNTIMED_FILES and untimed(course):
            course['scheduleStatus'] = 'unscheduled'
            changed['unscheduled'] += 1
        else:
            continue
        if note:
            strip_note(course, note, replacement)
    counts = recount(data)
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(name, changed, counts)


def main(root=None, suspended=None):
    jobs = [('cnu-unknown', cnu_meetings, CNU_HOLD, CNU_PLAN)]
    jobs += [(name, hufs_meetings, HUFS_HOLD, '') for name in ('hufs-seoul', 'hufs-global')]
    jobs += [(name, (tuk_weekly, tuk_finish, tuk_partial), None, '') for name in ('tuk-first', 'tuk-unknown')]
    jobs += [(name, (hanyang_weekly, hanyang_finish, None), None, '') for name in ('hanyang-seoul', 'hanyang-erica')]
    jobs += [(name, (hoseo_weekly, None, None), None, '') for name in ('hoseo-unknown', 'hoseo-asan', 'hoseo-cheonan')]
    jobs += [('koreatech-unknown', (koreatech_weekly, koreatech_finish, None), None, '')]
    done = {name for name, *_ in jobs}
    jobs += [(name, None, None, '') for name in UNTIMED_FILES if name not in done]
    # Resolve every input before writing any, so a missing file never leaves a partial batch.
    paths = {name: dataset_path(name, root, suspended) for name, *_ in jobs}
    # 같은 학교 학사일정: 확정 행이 가장 많은 hoseo-unknown의 요일별 날짜를 세 캠퍼스에 쓴다.
    hoseo = json.loads(paths['hoseo-unknown'].read_text(encoding='utf-8'))
    for name, timed, note, replacement in jobs:
        process(name, timed, note, replacement, paths[name],
                rule_from=hoseo if name.startswith('hoseo') else None)


if __name__ == '__main__':
    main()
