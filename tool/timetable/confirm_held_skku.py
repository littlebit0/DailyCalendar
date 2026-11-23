#!/usr/bin/env python3
"""Confirm SKKU rows held for delivery mode, modules or operating review (2026-11-23 decision).

The public course list prints '요일HH:mm-HH:mm【room】' blocks; clocks are kept
as written (no slot merging), '【미지정】' leaves the room blank, and tags such as
'【모듈A】' or '【1.5h(ON)+1.5h(OFF)】' do not change the clock. Dates follow each
campus file's regular weekly pattern. Module date ranges are not published,
so module rows use the whole regular term like other rows. Rows the school
declares pre-produced online (teaching type 32, 온라인[사전제작]) stay held,
as their 82 regular peers carry no live attendance clock.

    python3 tool/timetable/confirm_held_skku.py
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import held_confirm_common as common  # noqa: E402

PATHS = ['assets/timetable/skku-humanities-2026-2.json', 'assets/timetable/skku-naturalScience-2026-2.json']
DAYS = '월화수목금토일'
NOTE = common.DECISION + '. 학교 공시 정규 수업시간에 학기·휴업일을 적용했습니다. 실제 휴·보강 및 시험 시간은 학교 공지를 확인하세요.'
DROP = ('수업 운영 미확인: 실제 날짜·수업 방식·휴강·보강을 확인 중입니다.',)
BLOCK = re.compile(r'([월화수목금토일])(\d{2}):(\d{2})-(\d{2}):(\d{2})【([^】]*)】')


def meetings(text):
    found = []
    for part in re.sub(r'【모듈[A-Z]】', '', text).split(','):
        match = BLOCK.match(part.strip())
        if not match or re.sub(r'【[^】]*】', '', part.strip()[match.end():]).strip():
            raise ValueError(text)
        room = '' if match[6] == '미지정' else match[6]
        found.append({'weekday': DAYS.index(match[1]) + 1,
                      'startMinute': int(match[2]) * 60 + int(match[3]),
                      'endMinute': int(match[4]) * 60 + int(match[5]), 'classroom': room})
    return common.merge(found, join=False)


def main():
    for path in PATHS:
        dataset = common.load(path)
        dates = common.weekday_dates(dataset)
        held = []
        for course in dataset['courses']:
            if course.get('scheduleStatus') != 'unrecognized':
                continue
            if course.get('sourceTeachingTypeCode') == '32':
                held.append(course['sourceSchedule'])
                continue
            try:
                found = meetings(course['sourceSchedule'])
            except ValueError:
                held.append(course['sourceSchedule'])
                continue
            frame = course.get('ordinaryTermFrameForReviewOnly') or {}
            schedules = [s for s in common.expand(found, dates)
                         if frame.get('startDate', '') <= s['date'] <= frame.get('endDate', '9999')]
            common.confirm(course, schedules, NOTE, DROP)
            course['unresolvedReasons'] = []
            if frame:
                course.setdefault('period', {'startDate': frame['startDate'], 'endDate': frame['endDate']})
        common.save(path, dataset, '성균관대 수업 방식·모듈·운영 검토 보류 강좌를 공시 요일·시각으로 확정(2026-11-23 사용자 결정)')
        print(path, 'held', held)


if __name__ == '__main__':
    main()
