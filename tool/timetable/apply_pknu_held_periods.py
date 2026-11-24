#!/usr/bin/env python3
"""국립부경대 2026-2: 공식 요일·교시가 있는 보류 강좌를 정규 예약으로 확정한다.

2026-11-23 사용자 결정: 공식 요일·교시가 있으면 운영 방식(혼합·원격·현장실습 등)이
불명확해도 대면 수업으로 보고 그 교시로 확정한다.

교시표: 학사 규정 '강의시간 운영표'(2026-01-21 개정)
https://www.pknu.ac.kr/rule/searchBylawsAndGuidelineView.do?bbsId=2&no=703587
  전일 50분: 0교시 08:00부터 1시간 간격, 14교시 22:00~22:50.
  화·목 75분: 1교시 09:00부터 90분 간격, 9교시 21:00~22:15.
슬롯 = 기존 정규 예약과 같음(50분 교시 60분, 75분 교시 90분, 연속 교시 합침).

수업 단위(50/75)는 기존 정규 예약처럼 같은 학기 공식 7/30 개설표
(https://www.pknu.ac.kr/boardDownload.do?no=80552)의 '수업 단위'를 쓴다. 단:
  - 화·목이 없는 강좌는 운영표상 50분만 있으므로 50분. 개설표가 75분이면 원문끼리
    모순이라 보류한다.
  - 75분은 화·목에만 있으므로 화·목 외 요일이 섞인 75분 강좌는 보류한다.
  - 화·목 강좌의 현재 교시가 7/30 개설표와 다르면, 현재 공표 시수(이론+실습
    시간×50분)와 맞는 단위가 하나뿐일 때만 그 단위를 쓰고 아니면 보류한다.
강의실은 원문 그대로이며, 여러 강의실이 적혀 교시별 대응이 없으면 기존 정규
예약처럼 비운다. 이미 scheduled인 강좌는 건드리지 않고, 재실행해도 바뀌지 않는다.

2차 재검토(2026-11-23 사용자 반려: 다른 공식 자료로 끝까지 찾기, 모순은 최신 자료):
  - 100763-101 '월3 수2', 102690-104 '화4 수5': 7/30 개설표가 75분 단위를 적었고 현재
    공개 계획서(10/7)도 같은 요일·교시이며 3-3-0 시수(150분)는 75분 두 교시와만 맞는다.
    운영표의 75분 교시 시각을 월·수에도 그대로 적용한다.
  - 현재 계획서에 시간이 없는 대연 8강좌: 같은 학기 공식 7/30 개설표의 요일·교시·강의실
    (JULY_ONLY)로 확정한다. 현재 자료는 시간을 비웠을 뿐 다른 시각을 적지 않았다.
  - OCU/KCU 146강좌: 2026-2 강의편람(boardDownload.do?no=80551) p.9 '수업 방법: OCU/KCU
    컨소시엄 홈페이지에서 원격수업으로 운영' → 실시간 수업 시각이 없어 시간 미정.
  - (표준)현장실습II~V, 창업실습·창업현장실습1~3: 같은 편람 p.26·p.28이 4~20주 기업 실습,
    창업동아리 활동·실제 창업(160~480시간)으로 정해 주간 수업 시각이 없어 시간 미정.

    python3 tool/timetable/apply_pknu_held_periods.py
"""
import datetime as dt
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = [ROOT / f'assets/timetable/pknu-{c}-2026-2.json' for c in ('daeyeon', 'unknown')]
CLOCK_URL = 'https://www.pknu.ac.kr/rule/searchBylawsAndGuidelineView.do?bbsId=2&no=703587'
UNIT_URL = 'https://www.pknu.ac.kr/boardDownload.do?no=80552'
# candidate-audit.json excludedHolidays와 같음. 정규 계획 9/1~12/7.
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}
START, END = dt.date(2026, 9, 1), dt.date(2026, 12, 7)
DAYS = {**{d: i + 1 for i, d in enumerate('월화수목금토일')},
        **{d: i + 1 for i, d in enumerate(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])}}
TT = {2, 4}
# 7/30 개설표 이후 요일·교시가 바뀐 17강좌(같은 학기 단위 검토 candidate-audit.json
# changedTime17). 이 강좌들은 7/30 단위를 그대로 옮기지 않는다.
CHANGED_SINCE_JULY = {
    '100524-103', '102543-102', '102854-101', '103798-102', '105209-101', '106631-101',
    '109700-116', '109700-125', '109881-101', '111931-101', '112981-101', '113545-101',
    '113718-501', '114175-101', '114251-101', '114520-101', '114528-101'}
ALL_DAY_75 = {'100763-101', '102690-104'}
# 7/30 개설표(no=80552) 원문: 단위, [(요일, 교시들, 강의실)]. 104717-104만 7/30 가상캠퍼스(혼합).
JULY_ONLY = {
    '104453-101': (75, [(2, [2, 3], 'C25-408')]),
    '107350-101': (75, [(4, [2, 3], 'C25-408')]),
    '107814-101': (50, [(4, [5, 6, 7, 8], 'B14-217')]),
    '113093-101': (50, [(5, [5], 'C21-335C'), (5, [6, 7, 8], 'C21-128')]),
    '103798-102': (50, [(4, [6, 7], 'C23-302')]),
    '111303-103': (50, [(2, [4, 5, 6, 7, 8, 9], 'C22-109'), (5, [4, 5, 6, 7, 8, 9], 'C22-109')]),
    '104717-104': (50, [(4, [2, 3, 4], 'C21-128')]),
}
NO_CLOCK = {'112636-101', '112638-101', '112639-101', '112665-101',
            '109404-101', '112157-101', '112158-101', '112159-101'}
GUIDE_URL = 'https://www.pknu.ac.kr/boardDownload.do?no=80551'
NO_CLOCK_NOTE = (' 2026-2 강의편람(no=80551)에 따라 주간 수업 시각이 없는 강좌로 시간 미정 처리'
                 '({}).')
JULY_NOTE = ' 현재 계획서에 시간이 없어 같은 학기 7/30 공식 개설표의 요일·교시·강의실로 확정했습니다.'
HELD = '일정 미생성: '
CONFIRMED = '공식 요일·교시로 정규 예약(운영 방식 세부는 판단하지 않음), 이전 보류 사유: '
STALE_TT = '현재 단위 불명확한 화/목은 일정으로 치환하지 않았습니다.'
UNIT_NOTE = '화/목은 {}분 단위({})를 적용했습니다.'


def slot(unit, period):
    if unit == 50:
        return 480 + 60 * period, 540 + 60 * period
    return 540 + 90 * (period - 1), 630 + 90 * (period - 1)


def native_periods(text):
    """'화7,8 수8' / 'Tue.1 Thu.1' → [{'weekday', 'period'}]."""
    out = []
    for day, nums in re.findall(r'([월화수목금토일]|Mon|Tue|Wed|Thu|Fri|Sat|Sun)\.?\s*([\d,]+)', text):
        out += [{'weekday': DAYS[day], 'period': int(n)} for n in nums.split(',') if n]
    return out


def hours_minutes(scheme):
    m = re.fullmatch(r'[\d.]+-([\d.]+)-([\d.]+)', scheme or '')
    return round((float(m[1]) + float(m[2])) * 50) if m else None


def choose_unit(c):
    """(unit, 근거) 또는 (None, 보류 사유). sourceSnapshotMinuteUnit = 7/30 개설표 단위."""
    periods = c['sourceNativePeriods']
    days = {p['weekday'] for p in periods}
    july_unit = int(c['sourceSnapshotMinuteUnit']) if c.get('sourceSnapshotMinuteUnit') else None
    key = f"{c['courseCode']}-{c['section']}"
    if key in ALL_DAY_75:
        return 75, '7/30 개설표 75분 단위, 현재 계획서 교시·3시간 시수와 일치'
    same = key not in CHANGED_SINCE_JULY
    if not days & TT:
        if july_unit == 75:
            return None, '7/30 개설표 75분 단위가 화·목 외 요일과 모순'
        return 50, '전일 50분'
    if same and july_unit:
        if july_unit == 75 and not days <= TT:
            return None, '7/30 개설표 75분 단위가 화·목 외 요일과 모순'
        return july_unit, '7/30 개설표 수업 단위'
    expected = hours_minutes(c['sourceCurrentEducation'].get('PNT_THEO_PRAC'))
    fits = [u for u in (50, 75) if (u == 50 or days <= TT)
            and expected == sum(u if p['weekday'] in TT else 50 for p in periods)]
    if len(fits) == 1:
        return fits[0], '현재 공표 시수와 맞는 유일한 단위'
    return None, '화·목 50/75분 단위를 원문으로 정할 수 없음'


def meetings(c, unit, parts=None):
    """parts: [(요일, 교시, 강의실)]. 없으면 현재 원문 교시와 단일 강의실."""
    rooms = c['sourceClassroom'] or ''
    room = '' if re.search(r'[,/]|\s', rooms.strip()) else rooms.strip()
    if parts is None:
        parts = [(p['weekday'], p['period'], room) for p in c['sourceNativePeriods']]
    all_days = f"{c['courseCode']}-{c['section']}" in ALL_DAY_75
    result = []
    d = START
    while d <= END:
        iso = d.isoformat()
        if iso not in HOLIDAYS:
            for day, period, where in parts:
                if day != d.isoweekday():
                    continue
                u = unit if day in TT or all_days else 50
                a, b = slot(u, period)
                prev = result[-1] if result and result[-1]['date'] == iso else None
                if prev and prev['sourceMinuteUnit'] == u and prev['classroom'] == where \
                        and 0 <= a - prev['endMinute'] < 60:
                    prev['endMinute'] = b
                else:
                    result.append({'weekday': day, 'startMinute': a, 'endMinute': b,
                                   'classroom': where, 'sourcePeriod': period,
                                   'sourceMinuteUnit': u, 'date': iso})
        d += dt.timedelta(days=1)
    return result


def note(text, unit_note):
    text = text.replace(HELD, CONFIRMED)
    return text.replace(STALE_TT, unit_note) if unit_note else text


def no_clock_reason(c):
    key = f"{c['courseCode']}-{c['section']}"
    if c['section'].startswith('9') and c['courseCode'][0] in 'UK' \
            and c.get('sourceSnapshotCampus') == '가상캠퍼스':
        return 'OCU/KCU 컨소시엄 원격수업, p.9'
    if key in NO_CLOCK:
        return '현장실습·창업실습 기간제 실습, p.26·p.28'
    return None


def apply_second_pass(c):
    """2차 재검토: 7/30 개설표로 확정하거나, 편람상 시각 없는 강좌를 시간 미정으로."""
    key = f"{c['courseCode']}-{c['section']}"
    if key in JULY_ONLY:
        unit, blocks = JULY_ONLY[key]
        parts = [(day, p, room) for day, ps, room in blocks for p in ps]
        c['schedules'] = meetings(c, unit, parts)
        c['scheduleStatus'] = 'scheduled'
        c['dateProofKind'] = 'published ordinary weekday plan excluding holidays; not attendance confirmation'
        c['remarks'] = note(c['remarks'], '') + JULY_NOTE
        c['departmentRemarks'] = {k: note(v, '') + JULY_NOTE for k, v in c['departmentRemarks'].items()}
        c['heldPeriodConfirmation'] = {'clockSourceUrl': CLOCK_URL, 'unitSourceUrl': UNIT_URL,
                                       'unit': unit, 'unitBasis': '7/30 개설표 수업 단위',
                                       'julyOpeningBlocks': [[d, ps, r] for d, ps, r in blocks]}
        return True
    why = no_clock_reason(c)
    if why:
        c['scheduleStatus'] = 'unscheduled'
        c['remarks'] += NO_CLOCK_NOTE.format(why)
        c['departmentRemarks'] = {k: v + NO_CLOCK_NOTE.format(why)
                                  for k, v in c['departmentRemarks'].items()}
        c['heldPeriodConfirmation'] = {'noClockSourceUrl': GUIDE_URL, 'basis': why}
        return True
    return False


def apply(data):
    changed = []
    for c in data['courses']:
        if c['scheduleStatus'] != 'unrecognized':
            continue
        if not c['sourceSchedule'] or not c['sourceNativePeriods']:
            if apply_second_pass(c):
                changed.append(c['sourceId'])
            continue
        assert native_periods(c['sourceSchedule']) == c['sourceNativePeriods'], c['sourceId']
        unit, why = choose_unit(c)
        if unit is None:
            continue
        clock = slot(unit, max(p['period'] for p in c['sourceNativePeriods']))
        if clock[1] > 1440:
            continue
        c['schedules'] = meetings(c, unit)
        assert c['schedules'], c['sourceId']
        c['scheduleStatus'] = 'scheduled'
        c['dateProofKind'] = 'published ordinary weekday plan excluding holidays; not attendance confirmation'
        days = {p['weekday'] for p in c['sourceNativePeriods']}
        unit_note = UNIT_NOTE.format(unit, why) if days & TT else ''
        c['remarks'] = note(c['remarks'], unit_note)
        c['departmentRemarks'] = {k: note(v, unit_note) for k, v in c['departmentRemarks'].items()}
        c['heldPeriodConfirmation'] = {'clockSourceUrl': CLOCK_URL, 'unitSourceUrl': UNIT_URL,
                                       'unit': unit, 'unitBasis': why}
        changed.append(c['sourceId'])
    return changed


def main():
    for path in ASSETS:
        raw = path.read_text(encoding='utf-8')
        data = json.loads(raw)
        changed = apply(data)
        out = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
        if out != raw:
            path.write_text(out, encoding='utf-8')
        print(path.name, 'confirmed', len(changed))


if __name__ == '__main__':
    main()
