"""#570: schedule held Kongju courses whose official 2026-2 강의일람표 rows state the
weekday/period explicitly. Same generation rules as build_whole_ordinary_candidate.py
(periods 0-9 from official table 212, 9/1-12/7, holidays/midterms excluded).
Run from the worktree root."""
import json, re, datetime, sys
from pathlib import Path

HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}
START, END = datetime.date(2026, 9, 1), datetime.date(2026, 12, 7)
EXAMS = (datetime.date(2026, 10, 20), datetime.date(2026, 10, 26))
BASE = ('공개 정규 주간 예약 계획이며 실제 개별 출석일 확정 자료가 아닙니다. 학기 내 변경/보강/실제 시험시간은 개별 확인 필요. '
        '원문 9자리 과목번호를 그대로 보존하며 별도 학수번호/분반 정의는 미확인입니다.')
NOTE = {
    'sameNativeSourceVariantsClockRoomOrTeacherConflict':
        ' 같은 과목번호의 원문 행들이 담당교수만 다르고 요일·교시·강의실은 같아 그 교시로 예약했습니다.',
    'unrecognizedLiteralPeriodSyntax':
        ' 원문 교시의 마침표 구분(예: 수7.8.9)을 쉼표와 같은 교시 나열로 읽어 예약했습니다.',
}


def parse_line(text):
    s = re.sub(r'\s', '', text).replace('.', ',')
    matches = list(re.finditer(r'([월화수목금토일])([^월화수목금토일]*)', s))
    assert matches and matches[0].start() == 0, text
    blocks = []
    for m in matches:
        periods = sorted({int(p) for p in m[2].strip(',/').split(',') if p})
        assert periods and all(p <= 9 for p in periods), text
        runs = []
        for p in periods:
            if runs and p == runs[-1][-1] + 1:
                runs[-1].append(p)
            else:
                runs.append([p])
        for ps in runs:
            blocks.append({'weekday': '월화수목금토일'.index(m[1]) + 1, 'startMinute': (8 + ps[0]) * 60,
                           'endMinute': (8 + ps[-1]) * 60 + 50, 'nativePeriods': ps})
    return blocks


def resolvable(c):
    meta = c.get('sourceEducationalMetadata') or {}
    reasons = meta.get('holdReasons') or []
    if c['scheduleStatus'] != 'unrecognized' or len(reasons) != 1:
        return None
    variants = meta['originalPublishedRowVariants']
    if reasons[0] == 'sameNativeSourceVariantsClockRoomOrTeacherConflict':
        keys = {(v['courseTitle'], v['credits'], v['periodRaw'], v['roomRaw']) for v in variants}
        return reasons[0] if len(keys) == 1 else None
    if reasons[0] == 'unrecognizedLiteralPeriodSyntax' and len(variants) == 1:
        raw = variants[0]['periodRaw']
        if re.fullmatch(r'[월화수목금\d\s,./]+', raw) and '.' in raw and not re.search(r'1\d', raw):
            return reasons[0]
    return None


def resolve(c, reason):
    v = c['sourceEducationalMetadata']['originalPublishedRowVariants'][0]
    lines = v['periodRaw'].split('\n')
    rooms = v['roomRaw'].split('\n')
    assert len(rooms) in (1, len(lines)), c['sourceId']
    blocks, schedules = [], []
    for i, line in enumerate(lines):
        room = rooms[i] if len(rooms) == len(lines) else v['roomRaw']
        for b in parse_line(line):
            blocks.append(b)
            day = START
            while day <= END:
                date = day.isoformat()
                if (date not in HOLIDAYS and not EXAMS[0] <= day <= EXAMS[1]
                        and day.isoweekday() == b['weekday']):
                    schedules.append({'date': date, 'weekday': b['weekday'], 'startMinute': b['startMinute'],
                                      'endMinute': b['endMinute'], 'classroom': room})
                day += datetime.timedelta(days=1)
    schedules.sort(key=lambda s: (s['date'], s['startMinute']))
    note = BASE + NOTE[reason]
    c['scheduleStatus'] = 'scheduled'
    c['schedules'] = schedules
    c['remarks'] = note
    c['departmentRemarks'] = {d: note for d in c.get('departmentRemarks', {})}
    meta = c['sourceEducationalMetadata']
    meta['exactSourcePeriodicBlocks'] = blocks
    meta['holdReasons'] = []
    meta['resolvedHoldReasons'] = [reason]


done = []
for campus in ['cheonan', 'singwan', 'yesan', 'unknown']:
    path = Path(f'assets/timetable/kongju-{campus}-2026-2.json')
    raw = path.read_text(encoding='utf-8')
    data = json.loads(raw)
    for c in data['courses']:
        reason = resolvable(c)
        if reason:
            resolve(c, reason)
            done.append((c['sourceId'], reason, len(c['schedules'])))
    out = json.dumps(data, ensure_ascii=False, indent=2) + ('\n' if raw.endswith('\n') else '')
    path.write_text(out, encoding='utf-8')
for d in done:
    print(*d)
print('resolved', len(done))
