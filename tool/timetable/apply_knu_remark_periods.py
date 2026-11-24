#!/usr/bin/env python3
"""Confirm KNU time-less courses whose official remark names a weekday and 교시.

Rule (2026-11-23 user decision, DailyCalendar-Timetable skill 4·5장):
- 경북대 공식 수업시간표 및 강의계획서 조회
  (https://knuin.knu.ac.kr/public/stddm/lectPlnInqr.knu, 2026 2학기, 2026-11-23 조회)의
  비고에 '이론은 금 6교시 강의' 같은 요일+교시가 적힌 강좌만 그 교시로 확정한다.
  수업시간 칸이 빈 다른 강좌(임상·현장실습 등)는 시간 미정(unscheduled)으로 둔다.
- 교시표: 같은 화면의 '교과구분 및 교시별 수업시간' 표. n교시 = nA+nB(30분씩),
  1A 09:00 ... 9B 17:30~18:00, 즉 n교시 = (8+n):00 ~ (9+n):00. 슬롯 60분.
- 실습은 '별도계획에 의함'이라 시각을 만들지 않는다. 이론 강의 시각만 넣는다.
- 원문 필드는 바꾸지 않고, 비고의 '요일·시각 미게시' 문구만 사실에 맞게 고친다.
"""
import json
from pathlib import Path
import re

from import_knu import DAYS

ROOT = Path(__file__).parents[2]
PATH = ROOT/'assets/timetable/knu-unassigned-2026-2.json'
OLD_NOTE = '공식 시간표에 요일·시각 미게시: 시간 미정 강좌로 추가 가능'
NEW_NOTE = '공식 비고의 이론 강의 요일·교시 기준 확정(실습은 별도계획)'
EVIDENCE = {
    'source': 'https://knuin.knu.ac.kr/public/stddm/lectPlnInqr.knu',
    'checkedDate': '2026-11-23',
    'periodTable': '교과구분 및 교시별 수업시간: 1A교시 09:00-09:30 … 9B교시 17:30-18:00 (n교시 = nA+nB)',
    'rule': '비고의 "이론은 <요일> <n>교시 강의"만 확정, 실습 별도계획은 시각 없음',
}


def period_start(period):
    if not 1 <= period <= 14:
        raise ValueError('KNU period outside official table: %d' % period)
    return (8 + period) * 60


def remark_meeting(remarks):
    found = {m.groups() for text in remarks.values()
             for m in re.finditer(r'이론은\s*([월화수목금토일])\s*(\d{1,2})교시\s*강의', text)}
    if len(found) != 1:
        return None
    day, period = found.pop()
    start = period_start(int(period))
    return {'weekday': DAYS.index(day) + 1, 'startMinute': start, 'endMinute': start + 60}


def main():
    assert period_start(6) == 840 and period_start(7) == 900
    raw = PATH.read_text(encoding='utf-8')
    data = json.loads(raw)
    changed = []
    for course in data['courses']:
        if course['scheduleStatus'] != 'unscheduled' or course['sourceSchedule'].strip():
            continue
        meeting = remark_meeting(course['departmentRemarks'])
        if meeting is None:
            continue
        meeting['classroom'] = course['sourceClassroom']
        course['schedules'] = [meeting]
        course['scheduleStatus'] = 'scheduled'
        course['departmentRemarks'] = {k: v.replace(OLD_NOTE, NEW_NOTE)
                                       for k, v in course['departmentRemarks'].items()}
        changed.append(course['sourceId'])
    evidence = dict(EVIDENCE, courses=sorted(set(changed) | set(
        data.get('periodEvidence', {}).get('courses', []))))
    data['periodEvidence'] = evidence
    ending = raw[len(raw.rstrip('\n')):]
    PATH.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + ending, encoding='utf-8')
    print('confirmed', len(changed), changed)


if __name__ == '__main__':
    main()
