#!/usr/bin/env python3
"""동아대 2026-11-23 사용자 결정으로 확정한 강좌의 날짜를 기존 동아대 예약 규칙대로 다시 만든다(PR 1168 리뷰).

- 정규 수업: 9/1~12/7 원문 요일, 공휴일(9/24~26, 10/3, 10/5, 10/9)과 중간시험(10/20~26) 제외.
- 보강: 기존 동아대 자산·donga_mju_expansion_test와 같은 공식 보강표 매핑
  9/24→12/10, 9/25→12/11, 10/5→12/8, 10/9→12/9 (원 수업 시각·강의실, 보강일 요일로).
- 원문 비고가 주차를 정한 강좌는 그 주차만 쓴다(1주차=8/31~9/6 주, 원문 8·15주=중간·기말 주와 일치):
  01329465 "집중이수제: 1~10주간 수업(09.04.~11.06.까지)", 01HMC302 "2,3,5,9,10,11,13주차 2시간, 15주차 1시간",
  01HEM407·01322814·01HCC307은 원문 주차별 날짜(이미 날짜로 만든 일정 유지).
- 원문이 날짜·시각을 적은 필드 수업은 더한다: 01HCC305 "11.13.(금) 09~18시", "11.27.(금) 10~18시".
- departmentRemarks에도 같은 설명을 넣고 '일정 미생성' 문구를 바꾼다(화면은 departmentRemarks를 우선 보여 준다).

    python3 tool/timetable/patch_donga_official_clock_20261123.py   # 다시 실행해도 결과 동일
"""
import datetime as dt
import json
import re
from pathlib import Path

FILES = [Path(f'assets/timetable/donga-{c}-2026-2.json') for c in ('seunghak', 'unknown')]
MARK = '공식 시각 확정(2026-11-23 사용자 결정)'
EXCLUDED = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09',
            *[f'2026-10-{d}' for d in range(20, 27)]}
MAKEUPS = {'2026-09-24': '2026-12-10', '2026-09-25': '2026-12-11', '2026-10-05': '2026-12-08', '2026-10-09': '2026-12-09'}
DATED = {'01HEM407', '01322814', '01HCC307'}
DISPLAY = (' 공식 시각 확정(2026-11-23 사용자 결정): 운영 방식이 불명확해도 원문 요일·시각을 대면 수업으로 둡니다. '
           '정규 9/1~12/7(공휴일·중간시험 제외)과 공식 보강표의 보강일로 만든 예약이며 실제 출석일 확정이 아닙니다.')


def week_day(week, weekday):
    return (dt.date(2026, 8, 31) + dt.timedelta(7 * (week - 1) + weekday - 1)).isoformat()


def regular(blocks, until='2026-12-07', makeups=True):
    out, day = [], dt.date(2026, 9, 1)
    while day.isoformat() <= until:
        k = day.isoformat()
        if k not in EXCLUDED:
            out += [(k, b) for b in blocks if b[0] == day.isoweekday()]
        day += dt.timedelta(1)
    if makeups:
        for orig, mk in MAKEUPS.items():
                w = dt.date.fromisoformat(orig).isoweekday()
                out += [(mk, b) for b in blocks if b[0] == w]
    return out


W = '월화수목금토일'
C1 = re.compile(r'\(\s*([월화수목금토일])\s*(\d{1,2}):(\d{2})\s*[-~]\s*(\d{1,2}):(\d{2})')
C2 = re.compile(r'\(\s*([월화수목금토일])\s*(\d{1,2})-(\d{1,2})시\)')


def source_blocks(c):
    """원문 '수업요일/시간'의 괄호 시각과 '수업장소' 줄(온라인 LMS 줄 제외)을 순서대로 짝짓는다."""
    src = c['sourceSchedule']
    clocks = ([(W.index(m[0]) + 1, int(m[1]) * 60 + int(m[2]), int(m[3]) * 60 + int(m[4])) for m in C1.findall(src)]
              + [(W.index(m[0]) + 1, int(m[1]) * 60, int(m[2]) * 60) for m in C2.findall(src)])
    rooms = [r.strip().lstrip('＊').strip() for r in c['sourceClassroom'].split('\n') if r.strip()]
    rooms = [r for r in rooms if 'LMS' not in r]
    if len(rooms) == 1:
        rooms = rooms * len(clocks)
    assert clocks and len(rooms) == len(clocks), (c['courseCode'], src, rooms)
    out = []
    for (w, a, b), r in sorted(zip(clocks, rooms)):
        if out and out[-1][0] == w and out[-1][3] == r and a - out[-1][2] < 60:
            out[-1] = (w, out[-1][1], max(out[-1][2], b), r)
        else:
            out.append((w, a, b, r))
    return out


def meeting(date, b, start=None, end=None):
    return {'weekday': dt.date.fromisoformat(date).isoweekday(), 'startMinute': start if start is not None else b[1],
            'endMinute': end if end is not None else b[2], 'classroom': b[3], 'date': date}


def rebuild(c):
    code = c['courseCode']
    if code in DATED:
        return None
    blocks = source_blocks(c)
    if code == '01329465':
        pairs = [(d, b) for d, b in regular(blocks, until='2026-11-06', makeups=False)]
    elif code == '01HMC302':
        (b,) = blocks
        pairs = [(week_day(w, 5), b) for w in (2, 3, 5, 9, 10, 11, 13)]
        ms = [meeting(d, x) for d, x in pairs] + [meeting(week_day(15, 5), b, b[1], b[1] + 60)]
        return sorted(ms, key=lambda m: (m['date'], m['startMinute']))
    else:
        pairs = regular(blocks)
    ms = [meeting(d, b) for d, b in pairs]
    if code == '01HCC305':
        room = '범어사 성보박물관'  # 원문 "범어사 성보박물관 수업예정(필드)"
        ms += [meeting('2026-11-13', (5, 540, 1080, room)), meeting('2026-11-27', (5, 600, 1080, room))]
    uniq = {(m['date'], m['startMinute'], m['endMinute'], m['classroom']): m for m in ms}
    return sorted(uniq.values(), key=lambda m: (m['date'], m['startMinute']))


def fix_remarks(text):
    text = re.sub(r'; 일정 미생성: [^|\n]*', '', text)
    return text if DISPLAY.strip() in text else text.rstrip() + DISPLAY


def main():
    changed = []
    for path in FILES:
        d = json.loads(path.read_text(encoding='utf-8'))
        for c in d['courses']:
            if MARK not in c['remarks'] or c['scheduleStatus'] != 'scheduled':
                continue
            new = rebuild(c)
            if new is not None and new != c['schedules']:
                c['schedules'] = new
                changed.append(c['courseCode'])
            c['departmentRemarks'] = {k: fix_remarks(v) for k, v in c['departmentRemarks'].items()}
        path.write_text(json.dumps(d, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(json.dumps({'rescheduled': changed}, ensure_ascii=False))


if __name__ == '__main__':
    main()
