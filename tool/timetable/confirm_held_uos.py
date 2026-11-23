#!/usr/bin/env python3
"""Confirm UOS rows held for periods 13-15 or operating mode (2026-11-23 decision).

Official day table: period 1 at 09:00, 50-minute class + 10-minute break
(60-minute slot) up to period 10 at 18:00
(https://www.uos.ac.kr/kor/html/uaInfo/result/order/order.do). Periods 11-15
continue the same 60-minute slot (15 = 23:00-24:00). Rooms listed for the same
slot are kept together in one meeting. Concentrated courses stay held: their
registration period and the operating notice give different attendance dates.

    python3 tool/timetable/confirm_held_uos.py
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import held_confirm_common as common  # noqa: E402

PATH = 'assets/timetable/uos-main-2026-2.json'
DAYS = '월화수목금토일'
NOTE = common.DECISION + '. 11교시 이후는 공식 교시표와 같은 60분 슬롯으로 이어 계산.'
DROP = ('학교 원본 수업시간의 시각 미확인: 시간표 추가 불가',
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
