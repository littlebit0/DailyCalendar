#!/usr/bin/env python3
"""Confirm KNU held courses from their official HH:mm clock text.

Rule (2026-11-23 user decision, DailyCalendar-Timetable skill 4·5장):
- 경북대 공식 강의계획서 조회(https://knuin.knu.ac.kr/public/stddm/lectPlnInqr.knu)의
  수업시간(lssnsRealTimeInfo → sourceSchedule)은 '목 10:30 ~ 12:00' 같은 요일+HH:mm
  직접 표기다. 교시 변환 없이 그 시각을 그대로 쓴다.
- 원격강좌·학점교류(거점국립대·대구라이즈공유대학) 등 운영 방식 비고가 있어도 공식
  요일·시각이 있으면 그 시각으로 scheduled 확정한다(운영 방식 미표기는 대면으로 간주).
- 구간 모양은 같은 데이터셋의 기존 주간 scheduled 강좌와 같다: 쉼표 구간 하나당 schedule
  하나, 원문 순서 유지, 합치지 않음, classroom = sourceClassroom. 실행 전에 기존 주간
  scheduled 강좌 전부를 이 변환기로 다시 계산해 기존 schedules와 같은지 확인한다.
- 날짜 지정 강좌(schedules에 date가 있는 강좌)는 건드리지 않는다.
- 파싱 못 하는 표기는 그 강좌만 unrecognized로 남기고 사유를 출력한다.
- 원문 필드는 바꾸지 않고, 비고의 옛 "추가 불가" 문구만 사실에 맞게 고친다.
"""
import glob
import json
from pathlib import Path
import re

from import_knu import DAYS, clock

ROOT = Path(__file__).parents[2]
OLD_NOTE = '실제 수업시간·적용일자 또는 진행 방식 미확인: 시간표 추가 불가'
NEW_NOTE = '공식 요일·시각 기준 확정(운영 방식 미표기는 대면으로 간주)'


def convert(course):
    schedules = []
    for segment in course['sourceSchedule'].split(','):
        match = re.fullmatch(r'\s*([월화수목금토일])\s*(\d{2}:\d{2})\s*~\s*(\d{2}:\d{2})\s*', segment)
        if not match:
            raise ValueError('Unparsed KNU clock segment: ' + repr(segment))
        start, end = clock(match[2]), clock(match[3])
        if start >= end:
            raise ValueError('Reversed KNU clock: ' + repr(segment))
        schedules.append({'weekday': DAYS.index(match[1]) + 1, 'startMinute': start,
                          'endMinute': end, 'classroom': course['sourceClassroom']})
    return schedules


def main():
    total = 0
    for path in sorted(glob.glob(str(ROOT/'assets/timetable/knu-*-2026-2.json'))):
        raw = Path(path).read_text(encoding='utf-8')
        data = json.loads(raw)
        changed = 0
        for course in data['courses']:
            status = course['scheduleStatus']
            if status == 'scheduled' and not any('date' in s for s in course['schedules']):
                if convert(course) != course['schedules']:
                    raise ValueError('Converter disagrees with existing course: ' + course['sourceId'])
            elif status == 'unscheduled' and course['sourceSchedule'].strip():
                print('hidden hold:', course['sourceId'], course['sourceSchedule'])
            elif status == 'unrecognized':
                try:
                    course['schedules'] = convert(course)
                except ValueError as error:
                    print('kept unrecognized:', course['sourceId'], error)
                    continue
                course['scheduleStatus'] = 'scheduled'
                course['departmentRemarks'] = {k: v.replace(OLD_NOTE, NEW_NOTE)
                                               for k, v in course['departmentRemarks'].items()}
                changed += 1
        if changed:
            ending = raw[len(raw.rstrip('\n')):]
            Path(path).write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + ending,
                                  encoding='utf-8')
        print(Path(path).name, 'confirmed', changed)
        total += changed
    print('total confirmed', total)


if __name__ == '__main__':
    main()
