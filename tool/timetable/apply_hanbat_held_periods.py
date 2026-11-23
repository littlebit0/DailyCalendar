#!/usr/bin/env python3
"""국립한밭대 2026-2: 공식 요일·교시가 있는 보류 강좌를 정규 예약으로 확정한다.

2026-11-23 사용자 결정: 공식 요일·교시가 있으면 운영 방식(현장실습·봉사 등)이나
폐강 표기와 관계없이 그 교시로 확정한다. 표에 없는 교시는 같은 표의 슬롯 길이로
이어 계산한다.

교시표: 학사종합안내 > 수업및수강 > 수업 '월~금요일/토요일 수업시간표'
https://www.hanbat.ac.kr/kor/sub05_030301.do (2026-11-23 조회)
  월~금 주간 1~9교시 09:00부터 50분 수업·60분 간격, 야간 10교시 18:40,
  11교시 19:35, 12교시 20:30, 13교시 21:30~22:20.
  토요일 1~5교시 09:00부터 60분 간격, 6교시 14:00부터 55분 간격, 13교시 20:25~21:15.
슬롯 끝은 기존 정규 예약과 같다(다음 교시 시작, 마지막 교시는 직전 슬롯 길이).
14교시 이후는 13교시 슬롯(55분)으로 이어 계산한다. 월~금 15교시는 이어 계산하면
24:15에 끝나 하루 범위(24:00)를 넘으므로 보류한다.

보류 유지: 원문 시간 없음(None), 분수 교시('수2.5', 공식 규칙 없음), 하루를 넘는
교시. 교시 묶음과 강의실 수가 맞지 않으면 기존 정규 예약처럼 강의실을 비운다. 이미 scheduled인 강좌는 건드리지 않는다. 재실행해도
바뀌지 않는다.

    python3 tool/timetable/apply_hanbat_held_periods.py
"""
import datetime as dt
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = [ROOT / f'assets/timetable/hanbat-{c}-2026-2.json' for c in ('daejeon', 'sejong')]
CLOCK_URL = 'https://www.hanbat.ac.kr/kor/sub05_030301.do'
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}
START, END = dt.date(2026, 9, 1), dt.date(2026, 12, 14)
DAYS = '월화수목금토일'


# 기존 정규 예약과 같은 슬롯: 주간 60분, 9교시는 18:00까지(야간 전 휴식 제외),
# 야간 12교시 20:30~21:30, 13교시 21:30~22:25. 14·15교시는 55분씩 이어 계산.
WEEK = {p: (480 + 60 * p, 540 + 60 * p) for p in range(1, 10)}
WEEK.update({10: (1120, 1175), 11: (1175, 1230), 12: (1230, 1290), 13: (1290, 1345),
             14: (1345, 1400), 15: (1400, 1455)})
SAT = {p: (480 + 60 * p, 540 + 60 * p) for p in range(1, 6)}
SAT.update({p: (840 + 55 * (p - 6), 895 + 55 * (p - 6)) for p in range(6, 16)})
assert WEEK[9] == (1020, 1080) and WEEK[13] == (1290, 1345) and WEEK[14] == (1345, 1400)
assert SAT[6] == (840, 895) and SAT[13] == (1225, 1280)

HELD_PREFIX = ' 예약 보류: '
NOTE = (' 공식 요일·교시로 정규 예약했습니다(운영 방식·폐강 여부는 판단하지 않음, 이전 보류 사유: {}).')
NOTE14 = ' 14교시 이후는 공식 교시표의 13교시 슬롯(55분)으로 이어 계산했습니다.'


def spans(schedule, room_text):
    """원문 교시 문자열 → 교시별 구간. 확정할 수 없으면 (None, 사유)."""
    text = (schedule or '').replace(' ', '')
    if not text or text == 'None':
        return None, 'no-time'
    if '.' in text:
        return None, '분수 교시 공식 규칙 없음'
    matches = list(re.finditer(r'([월화수목금토일])([^월화수목금토일]+)', text))
    if not matches or ''.join(m[0] for m in matches) != text:
        return None, '교시 표기 미확인'
    rooms = (room_text or '').split(',') if room_text else ['']
    if len(rooms) not in (1, len(matches)):
        rooms = ['']  # 기존 정규 예약과 같이 대응이 불명한 강의실은 비워 둔다.
    out = []
    for j, m in enumerate(matches):
        day = DAYS.index(m[1]) + 1
        room = rooms[0 if len(rooms) == 1 else j]
        ps = m[2].strip(',').split(',')
        if day == 7 or not all(p.isdigit() for p in ps):
            return None, '교시 표기 미확인'
        clock = SAT if day == 6 else WEEK
        for p in map(int, ps):
            if p not in clock or clock[p][1] > 1440:
                return None, '이어 계산한 교시가 24:00을 넘음'
            out.append({'weekday': day, 'startMinute': clock[p][0],
                        'endMinute': clock[p][1], 'classroom': room, 'period': p})
    return out, ''


def meetings(parts):
    """기존 정규 예약 규칙: 날짜별로 펼친 뒤 같은 날·강의실 60분 미만 간격은 합침."""
    result = []
    d = START
    while d <= END:
        iso = d.isoformat()
        if iso not in HOLIDAYS:
            for s in parts:
                if s['weekday'] != d.isoweekday():
                    continue
                m = {k: s[k] for k in ('weekday', 'startMinute', 'endMinute', 'classroom')}
                m['date'] = iso
                prev = next((x for x in reversed(result) if x['date'] == iso
                             and x['classroom'] == m['classroom']), None)
                if prev and 0 <= m['startMinute'] - prev['endMinute'] < 60 \
                        and m['startMinute'] >= prev['startMinute']:
                    prev['endMinute'] = m['endMinute']
                else:
                    result.append(m)
        d += dt.timedelta(days=1)
    return result


def apply(data):
    changed = []
    for c in data['courses']:
        if c['scheduleStatus'] == 'scheduled':
            # 규칙 재현 확인: 기존 정규 예약도 같은 결과여야 한다.
            parts, _ = spans(c['sourceSchedule'], c['sourceClassroom'])
            assert parts and meetings(parts) == c['schedules'], c['sourceId']
            continue
        if c['scheduleStatus'] != 'unrecognized':
            continue
        parts, _ = spans(c['sourceSchedule'], c['sourceClassroom'])
        if not parts:
            continue
        c['schedules'] = meetings(parts)
        assert c['schedules'], c['sourceId']
        c['scheduleStatus'] = 'scheduled'
        meta = c['metadata']
        reason = meta.get('heldReason', '')
        meta['formerHeldReason'] = reason
        meta['heldReason'] = ''
        meta['clockSourceUrl'] = CLOCK_URL
        note = c['remarks'].split(HELD_PREFIX)[0] + NOTE.format(reason or '없음')
        if any(p['period'] >= 14 for p in parts):
            note += NOTE14
        c['remarks'] = note
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
