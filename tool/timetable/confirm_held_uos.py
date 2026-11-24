#!/usr/bin/env python3
"""Confirm UOS rows held for periods 13-15 or operating mode (2026-11-23 decision).

Official day table: period 1 at 09:00, 50-minute class + 10-minute break
(60-minute slot) up to period 10 at 18:00
(https://www.uos.ac.kr/kor/html/uaInfo/result/order/order.do). Periods 11-15
continue the same 60-minute slot (15 = 23:00-24:00). Rooms listed for the same
slot are kept together in one meeting. Concentrated (A형) bootcamp courses use
the latest official source, notice seq=9898 (2026-09-21 「인공지능 부트캠프 중급과정
실제 운영 시간표」): Monday-Friday 11-13교시 on the listed dates only, which needs
dated meetings (schemaVersion 2).

    python3 tool/timetable/confirm_held_uos.py
"""
import datetime
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import held_confirm_common as common  # noqa: E402

PATH = 'assets/timetable/uos-main-2026-2.json'
DAYS = '월화수목금토일'
NOTE = common.DECISION + '. 11교시 이후는 공식 교시표와 같은 60분 슬롯으로 이어 계산.'
NOTICE = 'https://www.uos.ac.kr/korNotice/view.do?list_id=FA2&seq=9898&menuid=2000005009003000000&identified=anonymous'
FIRST = ['2026-09-28', '2026-09-29', '2026-09-30', '2026-10-01', '2026-10-02', '2026-10-06', '2026-10-07',
         '2026-10-08', '2026-10-12', '2026-10-13', '2026-10-14', '2026-10-15', '2026-10-16', '2026-10-19',
         '2026-10-20']  # 10/5 대체휴일, 10/9 한글날 제외
SECOND = ['2026-11-%02d' % d for d in (2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 16, 17, 18, 19, 20)]
BOOTCAMP = {'92105': ('33-607', FIRST), '92106': ('33-605', FIRST), '92107': ('33-404', SECOND),
            '92108': ('33-605', SECOND), '92109': ('33-607', SECOND)}
BOOTCAMP_NOTE = ('2026-11-23 사용자 결정: 최신 공식 공지(학사공지 seq=9898, 2026-09-21 실제 운영 시간표)의 '
                 '날짜·11~13교시(19:00~22:00 슬롯)로 확정.')
DROP = ('실제 출석일·수업시각 별도 확인 필요: 시간표 추가 불가',
        '학교 원본 수업시간의 시각 미확인: 시간표 추가 불가',
        '기본교육 날짜 선택·소양교육 필수 참석·그룹코칭 개별 배정. 전체 실제 출석 일정 미확인: 시간표 추가 불가.',
        '실제 운영일·시각 미확인: 시간표 추가 불가.')


def meetings(text):
    slots = {}
    for part in re.split(r',(?=[월화수목금토일]\[)', text):
        match = re.fullmatch(r'([월화수목금토일])\[([0-9,]+)\]/(.+)', part.strip())
        if not match:
            raise ValueError(text)
        weekday = DAYS.index(match[1]) + 1
        for slot in map(int, match[2].split(',')):
            if not 1 <= slot <= 15:
                raise ValueError(text)
            slots.setdefault((weekday, slot), []).append(match[3])
    rooms = {}
    for (weekday, slot), names in slots.items():
        rooms[(weekday, slot)] = ', '.join(dict.fromkeys(names))
    return common.merge({'weekday': w, 'startMinute': 540 + (s - 1) * 60,
                         'endMinute': 540 + s * 60, 'classroom': rooms[(w, s)]}
                        for (w, s) in rooms)


def main():
    dataset = common.load(PATH)
    held = 0
    for course in dataset['courses']:
        if course.get('scheduleStatus') != 'unrecognized':
            continue
        if course['courseCode'] in BOOTCAMP:
            room, dates = BOOTCAMP[course['courseCode']]
            schedules = [{'weekday': datetime.date.fromisoformat(d).isoweekday(), 'startMinute': 1140,
                          'endMinute': 1320, 'classroom': room, 'date': d} for d in dates]
            common.confirm(course, schedules, BOOTCAMP_NOTE + ' ' + NOTICE, DROP)
            course['sourceClassroom'] = room
            dataset['schemaVersion'] = 2
            continue
        if course.get('sourceAdministrativePeriod'):
            held += 1
            continue
        found = meetings(course['sourceSchedule'])
        common.confirm(course, found, NOTE, DROP)
        course['sourceClassroom'] = ' / '.join(dict.fromkeys(m['classroom'] for m in found))
    common.save(PATH, dataset, '서울시립대 11~15교시·운영 방식 보류 강좌를 공식 60분 슬롯으로 확정(2026-11-23 사용자 결정)')
    print('held', held)


if __name__ == '__main__':
    main()
