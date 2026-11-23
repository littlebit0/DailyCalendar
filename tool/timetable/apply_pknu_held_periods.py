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
예약처럼 비운다. 원문 강의시간이 없는 강좌는 그대로 둔다. 이미 scheduled인 강좌는
건드리지 않고, 재실행해도 바뀌지 않는다.

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
    same = f"{c['courseCode']}-{c['section']}" not in CHANGED_SINCE_JULY
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


def meetings(c, unit):
    rooms = c['sourceClassroom'] or ''
    room = '' if re.search(r'[,/]|\s', rooms.strip()) else rooms.strip()
    result = []
    d = START
    while d <= END:
        iso = d.isoformat()
        if iso not in HOLIDAYS:
            for p in c['sourceNativePeriods']:
                if p['weekday'] != d.isoweekday():
                    continue
                u = unit if p['weekday'] in TT else 50
                a, b = slot(u, p['period'])
                prev = result[-1] if result and result[-1]['date'] == iso else None
                if prev and prev['sourceMinuteUnit'] == u and 0 <= a - prev['endMinute'] < 60:
                    prev['endMinute'] = b
                else:
                    result.append({'weekday': p['weekday'], 'startMinute': a, 'endMinute': b,
                                   'classroom': room, 'sourcePeriod': p['period'],
                                   'sourceMinuteUnit': u, 'date': iso})
        d += dt.timedelta(days=1)
    return result


def note(text, unit_note):
    text = text.replace(HELD, CONFIRMED)
    return text.replace(STALE_TT, unit_note) if unit_note else text


def apply(data):
    changed = []
    for c in data['courses']:
        if c['scheduleStatus'] != 'unrecognized' or not c['sourceSchedule'] \
                or not c['sourceNativePeriods']:
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
