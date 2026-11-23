#!/usr/bin/env python3
"""Sogang 2026-2 PHY4201-01 특수연구 / PHY4204-01 졸업프로젝트: clock from the public syllabus.

The official 개설교과목 조회 (zcmw9016) prints only "[R404]" as 수업시간/강의실 for both
rows, and the 비고 says "매주 화 16:30 콜로키움 수강". The public 확장강의계획서 opened from
that screen's 강의계획서 조회 button (checked 2026-11-23) prints 「수업시간 화 16:30-18:00」 for
both courses, and the 물리학과 「2026학년도 2학기 콜로퀴엄 일정 안내」 (2026-09-01,
https://physics.sogang.ac.kr/physics/6757/subview.do) says 「일시 매주 화요일 16:30 / 장소
R404」. The rows become weekly Tuesday 16:30-18:00 meetings in R404 over the dataset's own
term 9/1~12/21, skipping the same school exam weeks and holidays as every other weekly
reservation in this asset (sogang_official_recheck_test.dart `excluded`).

    python3 tool/timetable/patch_sogang_phy_syllabus_clock.py

Re-running is a no-op once the rows are scheduled.
"""
import datetime as dt
import json
from pathlib import Path

ASSET = Path('assets/timetable/sogang-unknown-2026-2.json')
IDS = ('PHY4201-01', 'PHY4204-01')
START, END, ROOM = 16 * 60 + 30, 18 * 60, 'R404'
TERM = (dt.date(2026, 9, 1), dt.date(2026, 12, 21))
# School-wide non-class days used by every weekly reservation in this asset.
EXCLUDED = {'2026-09-18', '2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05',
            '2026-10-09', '2026-11-20'}
EXCLUDED |= {f'2026-10-{d}' for d in range(20, 27)} | {f'2026-12-{d}' for d in range(15, 22)}
COLLOQUIUM = 'https://physics.sogang.ac.kr/physics/6757/subview.do'
NOTE = ('2026-11-23 공개 강의계획서 재확인: 개설교과목 조회(zcmw9016)의 수업시간/강의실은 "[R404]"뿐이지만 '
        '같은 화면 강의계획서 조회의 확장강의계획서(2026년도 2학기)가 「수업시간 화 16:30-18:00」을 적고, '
        f'물리학과 「2026학년도 2학기 콜로퀴엄 일정 안내」(2026-09-01, {COLLOQUIUM})가 「일시 매주 화요일 16:30 / 장소 R404」를 '
        '적습니다. 비고 "매주 화 16:30 콜로키움 수강"과 맞으므로 화 16:30~18:00 R404 정규 주간 예약으로 둡니다. '
        '자체 개강 9/1~12/21 범위에서 학교 중간시험 10/20~26·기말시험 12/15~21·공휴일은 뺍니다. '
        '계획서 강의실 칸(추후공고·해당 연구실) 대신 공식 조회의 R404를 씁니다.')


def tuesdays():
    d = TERM[0]
    while d <= TERM[1]:
        if d.isoweekday() == 2 and d.isoformat() not in EXCLUDED:
            yield d.isoformat()
        d += dt.timedelta(days=1)


def patch(data):
    changed = 0
    for c in data['courses']:
        if f"{c['courseCode']}-{c['section']}" not in IDS or c['scheduleStatus'] == 'scheduled':
            continue
        native = c['sourceEducationalMetadata']
        if (c['scheduleStatus'], native['meetingText']) != ('unrecognized', '[R404]') \
                or '매주 화 16:30 콜로키움' not in native['remarks']:
            raise ValueError(f"{c['sourceId']}: official row changed, re-check the syllabus")
        c['scheduleStatus'] = 'scheduled'
        c['schedules'] = [{'date': d, 'weekday': 2, 'startMinute': START, 'endMinute': END,
                           'classroom': ROOM} for d in tuesdays()]
        c['period'] = {'startDate': TERM[0].isoformat(), 'endDate': TERM[1].isoformat()}
        c['syllabusClockEvidence'] = {'checkedAt': '2026-11-23', 'clockExcerpt': '수업시간 화 16:30-18:00',
                                      'colloquiumNotice': COLLOQUIUM,
                                      'colloquiumExcerpt': '일시 매주 화요일 16:30 / 장소 R404'}
        c['remarks'] = NOTE
        c.pop('holdReasons', None)
        changed += 1
    return changed


def main():
    data = json.loads(ASSET.read_text(encoding='utf-8'))
    changed = patch(data)
    ASSET.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(f'patched {changed}')


if __name__ == '__main__':
    main()
