# coding: utf-8
"""경희대 2026-2 서울·국제: 운영 방식 검토로 보류한 강좌를 원문 시각으로 확정한다.

근거: 수강신청 개설강좌 원문 수업시간(`sourceSchedule`)이 '화 10:30-11:45 (멀301)'처럼
요일과 HH:mm 시각을 직접 적는다. 교시 변환이 없으므로 교시표가 필요 없다.
2026-11-23 사용자 결정: 공식 요일·시각이 있으면 운영 방식(원격·집중·온라인 선택 등)이
불명확해도 대면으로 보고 확정한다. 원문에 시각이 없으면 unscheduled(시간 미정) 유지.

날짜 규칙은 기존 정규 예약과 같다: 9/1~12/21의 해당 요일, 추석 9/24~26·개천절 10/3·
대체공휴일 10/5·한글날 10/9, 중간시험 10/20~26, 기말시험 12/15~ 제외. 비고에 원문
'학교 수업 계획: N주 / M/D ~ M/D / 시험·휴일…' 줄이 있으면 그 기간도 제외한다.
같은 요일 여러 줄은 기존 자료처럼 합치지 않고 줄마다 구간을 만든다.
'온라인강의 열 선택'만으로 철회했던 강좌는 철회 전 정규 예약(v1, 개별 강의계획서 주차
예외 반영, 원문 요일·시각·강의실과 일치할 때만)을 되살린다.
먼저 기존 scheduled 강좌 전체를 같은 규칙으로 다시 만들어 일치 건수를 확인한다
(개별 강의계획서 예외가 반영된 강좌는 다르므로 전부 일치하지는 않는다).

사용: 저장소 루트에서 python3 tool/timetable/apply_khu_official_times.py
"""
import datetime as dt
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path

PATHS = [Path(f'assets/timetable/khu-{c}-2026-2.json') for c in ('seoul', 'global')]
SLOT = re.compile(
    r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05',
            '2026-10-09'}
PLAN = re.compile(
    r'학교 수업 계획: \d+주 / (\d{1,2})/(\d{1,2}) ~ (\d{1,2})/(\d{1,2}) / ([^\n]*)')
PLAN_EXCEPTION = re.compile(
    r'시험|고사|추석|공휴일|연휴|휴강|휴일|midterm|final|exam|no\s*class|holiday|vacation',
    re.I)
OLD_HELD = ('강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 '
            '중입니다. 시간표 자동 배치는 보류됩니다.')
OLD_ONLINE = '날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다.'
NEW_HELD = ('공식 요일·시각 기준 확정(운영 방식 미표기는 대면으로 간주). 학교 중간시험'
            '(10/20~26)·기말시험(12/15~21)·공휴일은 제외했습니다.')
NEW_ONLINE = ('날짜별 실시간/녹화 배정은 미공개이나 공식 요일·시각 기준으로 확정했습니다'
              '(운영 방식 미표기는 대면으로 간주). 학교 시험·공휴일과 원문 계획의 시험·휴일 '
              '주차는 제외했습니다.')
NEW_UNSCHEDULED = '원문에 요일·시각이 없어 시간 미정 강좌로 둡니다.'
NEW_NO_WEEKDAY = '원문 수업시간에 요일이 없어 시간표 배치를 보류합니다.'
CLOCK = re.compile(r'\d{1,2}:\d{2}')
PRIOR_DIR = 'work/university-research/catalog-c/ordinary-weekly-held-audit-20261008'


def slots(source):
    lines = [line.strip() for line in source.split('\n')]
    matches = [SLOT.fullmatch(line) for line in lines]
    if not lines or not all(matches):
        raise ValueError(source)
    return matches


def plan_exclusions(course):
    out = []
    for remark in course['departmentRemarks'].values():
        for m in PLAN.finditer(remark):
            if PLAN_EXCEPTION.search(m[5]):
                out.append((f'2026-{int(m[1]):02d}-{int(m[2]):02d}',
                            f'2026-{int(m[3]):02d}-{int(m[4]):02d}'))
    return out


def meetings(course, use_plan=True):
    found = slots(course['sourceSchedule'])
    excluded = plan_exclusions(course) if use_plan else []
    start = dt.date.fromisoformat(course['period']['startDate'])
    end = dt.date.fromisoformat(course['period']['endDate'])
    out = []
    day = start
    while day <= end:
        iso = day.isoformat()
        skip = (iso in HOLIDAYS or '2026-10-20' <= iso <= '2026-10-26'
                or iso >= '2026-12-15' or any(a <= iso <= b for a, b in excluded))
        if not skip:
            for m in found:
                if '월화수목금토일'.index(m[1]) + 1 == day.isoweekday():
                    out.append({'date': iso, 'weekday': day.isoweekday(),
                                'startMinute': int(m[2]) * 60 + int(m[3]),
                                'endMinute': int(m[4]) * 60 + int(m[5]),
                                'classroom': m[6].strip()})
        day += dt.timedelta(days=1)
    return sorted(out, key=lambda s: (s['date'], s['startMinute']))


def prior_reservations():
    """온라인강의 열 때문에 철회한 58강좌의 이전 정규 예약(v1, 강의계획서 주차 예외 반영)."""
    manifest = Path('test/fixtures/source_audits/manifest.json').read_bytes()
    cache = Path(tempfile.gettempdir()) / (
        'daily-source-fixtures-' + hashlib.sha256(manifest).hexdigest())
    if not (cache / '.ready').exists():
        subprocess.run(['python3', 'tool/prepare_test_fixtures.py', '--output', str(cache)],
                       check=True)
    out = {}
    for campus in ('seoul', 'global'):
        data = json.loads((cache / PRIOR_DIR /
                           f'khu-{campus}-2026-2.ordinary-reservation-research-v1-20261008.json')
                          .read_text(encoding='utf-8'))
        out.update({c['sourceId']: c['schedules'] for c in data['courses']})
    return out


def restored(course, prior):
    """이전 예약의 모든 구간이 현재 원문 요일·시각·강의실과 같을 때만 되살린다."""
    old = prior.get(course['sourceId']) or []
    native = {('월화수목금토일'.index(m[1]) + 1, int(m[2]) * 60 + int(m[3]),
               int(m[4]) * 60 + int(m[5]), m[6].strip())
              for m in slots(course['sourceSchedule'])}
    if old and all((s['weekday'], s['startMinute'], s['endMinute'], s['classroom']) in native
                   for s in old):
        return [dict(s) for s in old]
    return None


def existing(course):
    return sorted(({k: v for k, v in s.items() if k != 'deliveryMode'}
                   for s in course['schedules']),
                  key=lambda s: (s['date'], s['startMinute']))


def replace_remarks(course, pairs):
    course['departmentRemarks'] = {
        key: _apply(value, pairs) for key, value in course['departmentRemarks'].items()}


def _apply(text, pairs):
    for old, new in pairs:
        text = text.replace(old, new)
    return text


def main():
    report = {}
    prior = prior_reservations()
    for path in PATHS:
        raw = path.read_text(encoding='utf-8')
        data = json.loads(raw)
        courses = data['courses']
        # 기존 정규 예약과 같은 규칙인지 확인: 원문 계획 제외를 더해도 기존 일치가 깨지지 않아야 한다.
        base = plan = 0
        for c in courses:
            if c['scheduleStatus'] != 'scheduled':
                continue
            try:
                current = existing(c)
                b = meetings(c, use_plan=False) == current
                p = meetings(c) == current
            except ValueError:
                continue
            assert p or not b, c['sourceId']
            base += b
            plan += p
        confirmed = kept_unrecognized = kept_unscheduled = restored_count = 0
        for c in courses:
            if c['scheduleStatus'] == 'unrecognized':
                try:
                    previous = restored(c, prior)
                    c['schedules'] = previous or meetings(c)
                    restored_count += previous is not None
                except ValueError:
                    assert not re.search('[월화수목금토일]', c['sourceSchedule']), c['sourceId']
                    replace_remarks(c, [(OLD_HELD, NEW_NO_WEEKDAY)])
                    kept_unrecognized += 1
                    continue
                assert c['schedules'], c['sourceId']
                c['scheduleStatus'] = 'scheduled'
                replace_remarks(c, [(OLD_HELD, NEW_HELD), (OLD_ONLINE, NEW_ONLINE)])
                confirmed += 1
            elif c['scheduleStatus'] == 'scheduled':
                # 이미 확정된 강좌에 남은 옛 보류 문장은 사실과 달라 뺀다(뒤 설명이 이미 있음).
                replace_remarks(c, [(OLD_HELD + '\n', ''), (OLD_HELD, NEW_HELD)])
            elif c['scheduleStatus'] == 'unscheduled':
                # 시각(HH:mm)이 있는 숨은 보류는 없어야 한다. 생기면 규칙을 다시 본다.
                assert not CLOCK.search(c['sourceSchedule']), c['sourceId']
                replace_remarks(c, [(OLD_HELD, NEW_UNSCHEDULED)])
                kept_unscheduled += 1
        for c in courses:
            text = '\n'.join(c['departmentRemarks'].values())
            assert OLD_HELD not in text and OLD_ONLINE not in text, c['sourceId']
        if confirmed or 'periodEvidence' not in data:  # 재실행은 첫 적용 기록을 지우지 않는다.
            data['periodEvidence'] = {
                'rule': '원문 sourceSchedule의 요일·HH:mm을 그대로 사용(교시 변환 없음)',
                'decision': '2026-11-23 사용자 결정: 운영 방식 미표기는 대면으로 간주',
                'existingScheduledReproduced': plan,
                'confirmedFromUnrecognized': confirmed,
                'priorReservationRestored': restored_count,
                'priorReservationSource': PRIOR_DIR,
            }
        report[path.name] = {
            'existingReproducedBase': base, 'existingReproducedWithPlan': plan,
            'confirmed': confirmed, 'priorRestored': restored_count,
            'unrecognizedLeft': kept_unrecognized,
            'unscheduledLeft': kept_unscheduled}
        out = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
        path.write_text(out + ('\n' if raw.endswith('\n') else ''), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=1))


if __name__ == '__main__':
    main()
