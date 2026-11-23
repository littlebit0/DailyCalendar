#!/usr/bin/env python3
"""국립군산대 2026-2: 숫자 교시가 공식 원문에 있는데 보류한 강좌를 정규 예약한다.

2026-11-23 사용자 결정: 공식 요일·교시가 있으면 운영 방식([원격강의]·
[집중강의(산업체)] 등)이 불명확해도 대면 수업으로 보고 그 교시로 확정한다.
공식 교시표에 없는 교시(11~13교시, 토요일)는 같은 표의 슬롯 길이로 이어 계산한다.

교시표: 대학 공식 수업시간 안내 1~10교시(1교시 09:10, 50분 수업+10분 쉬는 시간).
슬롯은 시작~다음 교시 시작 직전 60분이라 p교시 = 09:10 + 60분 x (p-1).
원표: https://www.kunsan.ac.kr/board/view.kunsan?boardId=BBS_0000009&dataSid=1384672&menuCd=DOM_000000105001002000
날짜: 같은 공지 (붙임1) 수강신청 안내 p.2 학사력. 8/31 개강, 중간고사 10/19~10/23,
보강일 12/7(월←10/5)·12/8(화←금 9/25)·12/9(수←금 10/9)·12/10(목←9/24), 기말 12/11~.
월~금 날짜는 기존 정규 예약과 같은 집합이고(실행 때 대조), 토요일은 같은 규칙에
공휴일 9/26(추석 연휴)·10/3(개천절)만 뺀다.

남기는 것: 원문자 교시(①…, 공식 정의 없음)와 시간이 빈 강좌. 이미 scheduled인
강좌는 건드리지 않고, 재실행해도 바뀌지 않는다.

    python3 tool/timetable/apply_kunsan_held_periods.py
"""
import datetime
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATHS = [ROOT / f'assets/timetable/kunsan-{c}-2026-2.json' for c in ('unknown', 'saemangeum')]
DAYS = '월화수목금토일'
CIRCLED = re.compile('[①-⑳]')
FIRST_START, SLOT = 550, 60  # 1교시 09:10, 60분 슬롯


def _weekly(weekday, first, last, skip=()):
    d = datetime.date.fromisoformat(first)
    d += datetime.timedelta(days=(weekday - d.isoweekday()) % 7)
    out = []
    while d.isoformat() <= last:
        s = d.isoformat()
        if s not in skip:
            out.append(s)
        d += datetime.timedelta(days=7)
    return out


_CLOSED = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09',
           '2026-10-19', '2026-10-20', '2026-10-21', '2026-10-22', '2026-10-23',
           '2026-12-08', '2026-12-09'}  # 12/8·12/9는 금요일 보강일
# 원래 요일 -> 수업 날짜(보강일 포함). 금요일 수업은 12/8(화)·12/9(수)에 보강한다.
DATES = {w: _weekly(w, '2026-08-31', '2026-12-10', _CLOSED) for w in range(1, 7)}
DATES[5] += ['2026-12-08', '2026-12-09']
PERIOD = {'startDate': '2026-08-31', 'endDate': '2026-12-17'}
SEMESTER_NOTE = ('학교의 이번 학기는8월31일~12월17일입니다. 반영된 정규 수업·지정 보강 예약 범위는'
                 '12월10일까지이며, 중간·기말 시험 일정은 정규 교시로 별도 생성하지 않았습니다.'
                 '12월10일을 이 과목의 실제 조기 종강으로 의미하지 않습니다.')
HELD_REASONS = ('원격·혼합 운영의 실제 동시 출석 방식 미확인',
                '집중·현장 수업의 실제 날짜·출석 시각 미확인',
                '공식 현재 교시 시각표는 1~10교시만 제시')
NOTE = '공식 요일·교시로 정규 예약했습니다(운영 방식 세부는 판단하지 않음).'
NOTE11 = ' 11교시 이후는 1~10교시와 같은 60분 슬롯으로 이어 계산했습니다(11교시 19:10).'


def blocks(raw):
    """'월3 4,수1 [인문관-1105]' -> (강의실, [(요일, 시작, 끝)]). 숫자 교시만 받는다."""
    m = re.fullmatch(r'(.+?) \[([^\]]+)\]', raw or '')
    if not m or CIRCLED.search(raw):
        return None
    periods = {}
    for part in m[1].split(','):
        pm = re.fullmatch(r'([월화수목금토일])(\d+(?: \d+)*)', part.strip())
        if not pm:
            return None
        periods.setdefault(DAYS.index(pm[1]) + 1, set()).update(int(p) for p in pm[2].split())
    out = []
    for w, ps in sorted(periods.items()):
        for p in sorted(ps):
            start = FIRST_START + SLOT * (p - 1)
            if out and out[-1][0] == w and start - out[-1][2] < 60:
                out[-1] = (w, out[-1][1], start + SLOT)
            else:
                out.append((w, start, start + SLOT))
    return m[2], out


def meetings(room, segs):
    rows = []
    for w, start, end in segs:
        for date in DATES[w]:
            rows.append({'weekday': datetime.date.fromisoformat(date).isoweekday(),
                         'startMinute': start, 'endMinute': end, 'classroom': room,
                         'date': date,
                         # 기존 예약과 같다: 원문 '[실시간강의]'만 실시간, 나머지는 대면으로 본다.
                         'deliveryMode': 'liveOnline' if room == '실시간강의' else 'inPerson'})
    return sorted(rows, key=lambda r: (r['date'], r['startMinute']))


def _clean(text):
    lines = text.split('\n')
    first = ' / '.join(p for p in lines[0].split(' / ') if p not in HELD_REASONS)
    return '\n'.join(([first] if first else []) + lines[1:])


def apply(data):
    changed = []
    for c in data['courses']:
        if c['scheduleStatus'] != 'unrecognized':
            continue
        parsed = blocks(c['sourceSchedule'])
        if not parsed:
            continue
        room, segs = parsed
        assert room == c['sourceClassroom'], c['sourceId']
        late = any(end > FIRST_START + SLOT * 10 for _, _, end in segs)
        c['schedules'] = meetings(room, segs)
        c['scheduleStatus'] = 'scheduled'
        c['period'] = dict(PERIOD)
        note = NOTE + (NOTE11 if late else '') + '\n' + SEMESTER_NOTE
        c['remarks'] = _clean(c['remarks']) + '\n' + note
        c['departmentRemarks'] = {k: v + '\n' + note for k, v in c['departmentRemarks'].items()}
        c['sourceEducation'].update(
            projection='publishedRegularTimetable',
            datedPlanProof='kunsan-operating-date-next-audit-20261008.json',
            heldPeriodDecision='2026-11-23 user decision: official weekday/period confirmed as in-person',
            officialSemesterPeriod=dict(PERIOD), generatedOrdinaryMakeupDateScopeEnd='2026-12-10',
            courseEarlyEndConfirmed=False,
            semesterBoundaryProof='kunsan-current-calendar-operating-review-20261008.json:개강08/31+종강12/17')
        if late:
            c['sourceEducation']['clockProof'] = ('official numeric1–10 09:10 start, 60-minute slots; '
                                                  'periods 11+ continued with the same slot length')
        changed.append(c['sourceId'])
    data['counts'] = {s: sum(c['scheduleStatus'] == s for c in data['courses'])
                      for s in ('scheduled', 'unrecognized', 'unscheduled')}
    return changed


def check_existing(datasets):
    """월~금 날짜·교시 규칙이 기존 정규 예약과 같은지 대조한다."""
    for data in datasets:
        for c in data['courses']:
            parsed = c['scheduleStatus'] == 'scheduled' and blocks(c['sourceSchedule'])
            if parsed and all(w <= 5 for w, _, _ in parsed[1]) and '부분' not in c['remarks']:
                assert meetings(*parsed) == c['schedules'], c['sourceId']


def main():
    raws = [p.read_text(encoding='utf-8') for p in PATHS]
    datasets = [json.loads(r) for r in raws]
    check_existing(datasets)
    changed = [sid for d in datasets for sid in apply(d)]
    # 두 캠퍼스 파일은 같은 학교 전체 보류 목록을 함께 두므로, 정규 예약한 강좌만 뺀다.
    done = {(c['courseCode'], c['section'], c['sourceSchedule'])
            for d in datasets for c in d['courses'] if c['sourceId'] in changed}
    for d in datasets:
        d['individualBlocked'] = [b for b in d['individualBlocked']
                                  if (b['courseCode'], b['section'], b['sourceSchedule']) not in done]
    for path, raw, data in zip(PATHS, raws, datasets):
        out = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
        if out != raw:
            path.write_text(out, encoding='utf-8')
    print('confirmed', len(changed))


if __name__ == '__main__':
    main()
