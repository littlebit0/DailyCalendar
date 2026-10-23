# coding: utf-8
"""국립창원대 2026-2: 15A·15B 교시 시각이 없어 보류한 강좌에 공식 교시표를 적용한다.

근거: 학사안내 > 수업 > 수강신청 '3. 수업시간표' 표
https://www.changwon.ac.kr/haksa/cm/cntnts/cntntsView.do?mi=13242&cntntsId=3922
(2026-10-23 조회) '15 22:30~22:55 A … 22:55~23:20 B'.

보류 사유가 15A·15B 교시 시각 하나뿐인 강좌만 바꾼다. 다른 사유(집중이수·원격
혼합 등)가 함께 있는 강좌는 그대로 둔다. 날짜 규칙은 기존 정규 예약
(9/1~12/7, 법정휴일·11/24 임시휴강 예정·개별 시험일 제외, 11/19 1AB만 제외)과
같으며, 먼저 기존 정규 예약 전체를 같은 규칙으로 다시 만들어 일치하는지 확인한다.

사용: 저장소 루트에서 python3 tool/timetable/apply_changwon_period15.py
"""
import datetime as dt
import json
import re
from pathlib import Path

PATH = Path('assets/timetable/changwon-unknown-2026-2.json')
CLOCK_URL = ('https://www.changwon.ac.kr/haksa/cm/cntnts/cntntsView.do'
             '?mi=13242&cntntsId=3922')


def _clock():
    clock = {}
    for period in range(1, 10):  # 주간 30분 단위, 1교시 09:00
        start = 480 + period * 60
        clock[f'{period}A'] = (start, start + 30)
        clock[f'{period}B'] = (start + 30, start + 60)
    for period in range(10, 16):  # 야간 25분 단위, 10교시 18:20
        start = 1100 + (period - 10) * 50
        clock[f'{period}A'] = (start, start + 25)
        clock[f'{period}B'] = (start + 25, start + 50)
    return clock


CLOCK = _clock()
# 공식 표 원문 값과 맞는지 고정 확인.
assert CLOCK['1A'] == (540, 570) and CLOCK['9B'] == (1050, 1080)
assert CLOCK['10A'] == (1100, 1125) and CLOCK['14B'] == (1325, 1350)
assert CLOCK['15A'] == (1350, 1375) and CLOCK['15B'] == (1375, 1400)

# 2026 월력요항(국가 공휴일) 날짜. 기존 정규 예약과 같은 목록.
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-09-27',
            '2026-10-03', '2026-10-04', '2026-10-05', '2026-10-09',
            '2026-10-10', '2026-10-11'}
START, END = dt.date(2026, 9, 1), dt.date(2026, 12, 7)
TOKEN = re.compile(r'([월화수목금토일])(\d{1,2})([AB])(?:\(([^()]*)\))?')
PERIOD15 = 'current own period clock not published'


def blocks(text):
    parts, rooms = [], {}
    for m in TOKEN.finditer(text):
        weekday = '월화수목금토일'.index(m[1]) + 1
        if m[4]:
            rooms[weekday] = m[4]
        a, b = CLOCK[m[2] + m[3]]
        parts.append({'weekday': weekday, 'startMinute': a, 'endMinute': b,
                      'classroom': rooms.get(weekday, ''),
                      'nativePeriod': m[2] + m[3]})
    merged = []
    for p in parts:
        last = merged[-1] if merged else None
        if (last and last['weekday'] == p['weekday']
                and last['classroom'] == p['classroom']
                and last['endMinute'] == p['startMinute']):
            last['endMinute'] = p['endMinute']
            last['nativePeriods'].append(p['nativePeriod'])
        else:
            merged.append({**{k: p[k] for k in
                              ['weekday', 'startMinute', 'endMinute', 'classroom']},
                           'nativePeriods': [p['nativePeriod']]})
    return parts, merged


def exam_dates(fields):
    found = re.findall(r'2026\.(\d{1,2})\.(\d{1,2})', fields.get('시험일시', ''))
    return sorted({f'2026-{m.zfill(2)}-{d.zfill(2)}' for m, d in found})


def slots(merged, exams):
    result = []
    for block in merged:
        date = START
        while date <= END:
            iso = date.isoformat()
            if (date.isoweekday() == block['weekday'] and iso not in HOLIDAYS
                    and iso not in exams and iso != '2026-11-24'):
                a, b = block['startMinute'], block['endMinute']
                if iso == '2026-11-19':
                    a = max(a, 600)  # 공지된 1A·1B 임시휴강만 제외
                if a < b:
                    result.append({'weekday': block['weekday'], 'startMinute': a,
                                   'endMinute': b, 'classroom': block['classroom'],
                                   'date': iso})
            date += dt.timedelta(days=1)
    return result


def main():
    raw = PATH.read_text(encoding='utf-8')
    data = json.loads(raw)
    checked = changed = 0
    for c in data['courses']:
        review = c['sourceEducation'].get('regularReservationReview') or {}
        fields = c['sourceEducation'].get('currentPublicPlanFields') or {}
        if review.get('kind') == 'publicWeeklyReservation':
            # 규칙 재현 확인: 기존 정규 예약을 그대로 다시 만들어야 한다(순서 무관).
            key = lambda s: json.dumps(s, sort_keys=True)  # noqa: E731
            rebuilt = slots(review['nativeClockBlocks'],
                            review['individualPublishedExamDateHold'])
            assert sorted(map(key, rebuilt)) == sorted(map(key, c['schedules'])), c['sourceId']
            checked += 1
            continue
        reasons = review.get('holdReasons') or []
        if review.get('kind') != 'held' or not reasons or not all(
                r.startswith(PERIOD15) for r in reasons):
            continue
        parts, merged = blocks(c['sourceSchedule'])
        assert parts and all(p['classroom'] for p in parts), c['sourceId']
        exams = exam_dates(fields)
        assert exams == review['individualPublishedExamDateHold'], c['sourceId']
        # 이미 넣어 둔 공식 시험 약속(deliveryMode 표시)은 그대로 둔다.
        kept = [s for s in c['schedules'] if 'deliveryMode' in s]
        assert len(kept) == len(c['schedules']), c['sourceId']
        weekly = slots(merged, exams)
        assert weekly, c['sourceId']
        c['schedules'] = weekly + kept
        c['scheduleStatus'] = 'scheduled'
        dates = [s['date'] for s in c['schedules']]
        c['period'] = {'startDate': min(dates + [START.isoformat()]),
                       'endDate': max(dates + [END.isoformat()])}
        c['sourceClassroom'] = ' / '.join(dict.fromkeys(p['classroom'] for p in parts))
        review.update(kind='publicWeeklyReservation', holdReasons=[],
                      nativeClockBlocks=merged, period15ClockSourceUrl=CLOCK_URL)
        note = c['remarks'].split(' 예약보류: ')[0].replace(
            '15AB는추정하지 않았습니다.',
            '15A·15B는 학사안내 수강신청 수업시간표의 15A 22:30~22:55, '
            '15B 22:55~23:20을 적용했습니다.')
        if exams:
            note += ' 개별시험 원문날짜 보류: ' + ', '.join(exams)
        c['remarks'] = note
        c['departmentRemarks'] = {k: note for k in c['departmentRemarks']}
        changed += 1
    PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n',
                    encoding='utf-8')
    print(f'rule reproduced {checked} weekly reservations; applied 15AB to {changed}')


if __name__ == '__main__':
    main()
