#!/usr/bin/env python3
"""국립창원대 2026-2: 운영 방식 때문에 보류한 강좌를 공식 교시로 정규 예약한다.

2026-11-23 사용자 결정: 공식 요일·교시가 있으면 운영 방식(블렌디드·집중이수·
원격 혼합·개별 운영 근거)이 불명확해도 대면 수업으로 보고 그 교시로 확정한다.

교시표: 학사안내 > 수업 > 수강신청 '3. 수업시간표'
https://www.changwon.ac.kr/haksa/cm/cntnts/cntntsView.do?mi=13242&cntntsId=3922
(1A~9B 30분, 10A~15B 25분). 교시 계산·날짜 규칙·강의실 대응은
apply_changwon_period15.py와 같은 함수를 쓴다(기존 정규 예약 재현 확인 포함).
강의실은 원문 그대로다(빈 칸·99999 포함, 다른 요일 강의실을 끌어오지 않음).
이미 scheduled인 강좌는 건드리지 않고, 재실행해도 바뀌지 않는다.

    python3 tool/timetable/apply_changwon_held_periods.py
"""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location(
    'period15', ROOT / 'tool/timetable/apply_changwon_period15.py')
period15 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(period15)

PATH = ROOT / period15.PATH
HELD_PREFIX = ' 예약보류: '
NOTE = (' 공식 요일·교시로 정규 예약했습니다(운영 방식 세부는 판단하지 않음, '
        '이전 보류 사유: {}).')
NOTE15 = ('15AB는추정하지 않았습니다.',
          '15A·15B는 학사안내 수강신청 수업시간표의 15A 22:30~22:55, '
          '15B 22:55~23:20을 적용했습니다.')


def apply(data):
    changed = []
    for c in data['courses']:
        review = c['sourceEducation'].get('regularReservationReview') or {}
        if c['scheduleStatus'] != 'unrecognized' or review.get('kind') != 'held':
            continue
        parts, merged = period15.blocks(c['sourceSchedule'])
        if not parts:
            continue
        exams = period15.exam_dates(c['sourceEducation'].get('currentPublicPlanFields') or {})
        kept = [s for s in c['schedules'] if 'deliveryMode' in s]
        weekly = period15.slots(merged, exams)
        assert weekly and len(kept) == len(c['schedules']), c['sourceId']
        c['schedules'] = weekly + kept
        c['scheduleStatus'] = 'scheduled'
        dates = [s['date'] for s in c['schedules']]
        c['period'] = {'startDate': min(dates + [period15.START.isoformat()]),
                       'endDate': max(dates + [period15.END.isoformat()])}
        reasons = review.get('holdReasons') or []
        review.update(kind='publicWeeklyReservation', holdReasons=[],
                      formerHoldReasons=reasons, nativeClockBlocks=merged,
                      individualPublishedExamDateHold=exams,
                      clockSourceUrl=period15.CLOCK_URL)
        note = c['remarks'].split(HELD_PREFIX)[0]
        if any(p['nativePeriod'].startswith('15') for p in parts):
            note = note.replace(*NOTE15)
        note += NOTE.format('; '.join(reasons))
        if exams:
            note += ' 개별시험 원문날짜 보류: ' + ', '.join(exams)
        c['remarks'] = note
        c['departmentRemarks'] = {k: note for k in c['departmentRemarks']}
        changed.append(c['sourceId'])
    return changed


def main():
    raw = PATH.read_text(encoding='utf-8')
    data = json.loads(raw)
    changed = apply(data)
    out = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    if out != raw:
        PATH.write_text(out, encoding='utf-8')
    print('confirmed', len(changed))


if __name__ == '__main__':
    main()
