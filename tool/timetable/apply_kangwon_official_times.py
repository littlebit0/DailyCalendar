# coding: utf-8
"""강원대 2026-2: 원문 요일·교시가 있는데 보류(unrecognized)한 강좌를 공식 교시표로 확정한다.

근거: 강원대 학사안내 > 수업 > 수업안내 '수업시간표'(춘천/삼척, 강릉/원주 두 표가 같은 값)
https://www.kangwon.ac.kr/ko/conts/465/web.do (2026-11-23 조회)
'A1교시(75분) 09:00~10:15 … A6교시(75분) 16:30~17:45', '1교시(50분) 09:00~09:50 …
14교시(50분) 22:00~22:50'. 도계는 삼척 캠퍼스 원문 파일에 함께 실린 캠퍼스라 춘천/삼척 표를 쓴다.

규칙(2026-11-23 사용자 결정):
- 슬롯 = 그 교시 시작~다음 교시 시작 직전. 숫자 교시 60분(n교시 = 08:00 + n시간,
  0교시 08:00), A교시 90분(A1 = 09:00). 기존 scheduled 강좌와 같은 변환이다(아래에서
  기존 scheduled 강좌 전부를 다시 계산해 같은지 assert).
- 표에 없는 15교시·A7~A9는 같은 표의 슬롯 길이로 이어 계산한다(15교시 23:00, A7 18:00).
- 한 묶음 안의 연속 교시는 한 구간으로 합친다. 강의실이 한 번만 뒤에 적힌 경우 그
  강의실을 앞 묶음에도 적용한다(기존 자료와 같은 모양).
- 운영 방식(이러닝·집중·현장실습·임상실습·봉사 등)이 불명확해도 원문 요일·교시로 확정한다.
- 원문이 '0'뿐(요일 없음, 강의실도 '0')인 강좌는 시간표 칸이 빈 것과 같아 시각이 없다
  → unscheduled. 시각을 만들지 않는다.
- 한 묶음에 같은 교시를 여러 번 적은 표기('토1,1,1', 3학점)는 교시로 해석할 수 없다
  → 시각을 만들지 않고 unscheduled(시간 미정, 2026-11-23 사용자 결정). 원문은 그대로.
- 파싱 못 하는 표기는 그 강좌만 unrecognized로 남긴다.
- 원문 필드는 바꾸지 않고, 비고의 옛 '시간표 추가 불가' 줄만 고친다.

사용: 저장소 루트에서 python3 tool/timetable/apply_kangwon_official_times.py
"""
import json
import re
from pathlib import Path

CAMPUSES = ['chuncheon', 'dogye', 'gangneung', 'samcheok', 'wonju']
CLOCK_URL = 'https://www.kangwon.ac.kr/ko/conts/465/web.do'
DAYS = '월화수목금토일'
OLD_NOTE = '실제 수업시간·운영기간 미확인: 시간표 추가 불가'
NEW_NOTE = '공식 요일·교시 기준 확정(이러닝·집중·실습 등 운영 방식과 관계없이 원문 시각 적용)'
HELD_NOTE = '같은 교시가 여러 번 적혀 학점과 교시가 맞지 않음: 시간표 추가 불가'
REPEATED_NOTE = '같은 교시가 여러 번 적혀 교시로 해석할 수 없음: 요일·시각 미정'
NONE_NOTE = '원문 수업시간이 0으로만 표기됨: 요일·시각 미정'


def slot(period):
    if period.startswith('A'):
        n = int(period[1:])
        if not 1 <= n <= 9:
            raise ValueError('unverified_source_period')
        return 540 + (n - 1) * 90, 630 + (n - 1) * 90, 'A', n
    n = int(period)
    if not 0 <= n <= 15:
        raise ValueError('unverified_source_period')
    return 480 + n * 60, 540 + n * 60, 'N', n


# 공식 표 원문 값 고정 확인(수업 시작 시각).
assert slot('A1')[0] == 540 and slot('A6')[0] == 990 and slot('1')[0] == 540
assert slot('14')[0] == 1320 and slot('15') == (1380, 1440, 'N', 15)


def parse(source, embedded, room):
    groups, cursor = [], 0
    while cursor < len(source):
        cursor += re.match(r'[\s,]*', source[cursor:]).end()
        if cursor == len(source):
            break
        m = re.match(r'([월화수목금토일])\s*,?\s*((?:A?\d{1,2})(?:\s*,\s*A?\d{1,2})*)', source[cursor:])
        if not m:
            raise ValueError('unparsed_source_clock')
        cursor += m.end()
        classroom = None if embedded else room
        if embedded and cursor < len(source) and source[cursor] == '(':
            start, depth = cursor + 1, 1
            cursor += 1
            while cursor < len(source) and depth:
                depth += {'(': 1, ')': -1}.get(source[cursor], 0)
                cursor += 1
            if depth:
                raise ValueError('unbalanced_source_classroom')
            classroom = source[start:cursor - 1]
        periods = re.sub(r'\s+', '', m[2]).split(',')
        if len(set(periods)) != len(periods):
            # '토1,1,1'(3학점): 한 교시를 여러 번 적어 수업 시간과 교시가 모순된다.
            raise ValueError('repeated_source_period')
        slots = sorted(slot(p) for p in periods)
        chunks = []
        for s, e, kind, n in slots:
            if chunks and chunks[-1][2] == kind and n == chunks[-1][3] + 1:
                chunks[-1] = (chunks[-1][0], e, kind, n)
            else:
                chunks.append((s, e, kind, n))
        groups.append((DAYS.index(m[1]) + 1, chunks, classroom))
    # 뒤에 한 번만 적힌 강의실은 강의실 없는 앞 묶음에도 적용한다.
    nxt = ''
    for i in range(len(groups) - 1, -1, -1):
        day, chunks, classroom = groups[i]
        if classroom is None:
            classroom = nxt
        nxt = classroom
        groups[i] = (day, chunks, classroom)
    return [{'weekday': d, 'startMinute': s, 'endMinute': e, 'classroom': r or ''}
            for d, chunks, r in groups for s, e, _, _ in chunks]


def convert(course):
    embedded = course['sourceSchedule'] == course['sourceClassroom']
    return parse(course['sourceSchedule'], embedded, '' if embedded else course['sourceClassroom'])


def main():
    report = {}
    for campus in CAMPUSES:
        path = Path(f'assets/timetable/kangwon-{campus}-2026-2.json')
        raw = path.read_text(encoding='utf-8')
        data = json.loads(raw)
        # 일관성 검사: 기존 scheduled 강좌(봉사 기관 시각 강좌 제외) 전부를 다시 계산.
        for c in data['courses']:
            if c['scheduleStatus'] == 'scheduled' and c['courseCode'] != '14207025':
                assert convert(c) == c['schedules'], c['sourceId']
        counts = {'scheduled': 0, 'unscheduled': 0, 'unrecognized': {}}
        for c in data['courses']:
            if c['scheduleStatus'] != 'unrecognized':
                continue
            if c['sourceSchedule'].strip() == '0' and c['sourceClassroom'].strip() == '0':
                status, schedules, note = 'unscheduled', [], NONE_NOTE
            else:
                try:
                    status, schedules, note = 'scheduled', convert(c), NEW_NOTE
                except ValueError as error:
                    if str(error) != 'repeated_source_period':
                        counts['unrecognized'][str(error)] = counts['unrecognized'].get(str(error), 0) + 1
                        continue
                    status, schedules, note = 'unscheduled', [], REPEATED_NOTE
                    c['departmentRemarks'] = {k: v.replace(HELD_NOTE, OLD_NOTE)
                                              for k, v in c['departmentRemarks'].items()}
            c['scheduleStatus'], c['schedules'] = status, schedules
            c['departmentRemarks'] = {k: v.replace(OLD_NOTE, note)
                                      for k, v in c['departmentRemarks'].items()}
            counts[status] += 1
        data['periodEvidence'] = {
            'url': CLOCK_URL, 'checkedDate': '2026-11-23',
            'text': 'A1교시(75분) 09:00~10:15 … A6교시(75분) 16:30~17:45 / '
                    '1교시(50분) 09:00~09:50 … 14교시(50분) 22:00~22:50',
            'rule': '슬롯=교시 시작~다음 교시 시작(숫자 60분·A 90분), 15교시·A7~A9는 같은 슬롯 길이로 이어 계산'}
        text = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
        path.write_text(text + ('\n' if raw.endswith('\n') else ''), encoding='utf-8')
        report[campus] = counts
    print(json.dumps(report, ensure_ascii=False))


if __name__ == '__main__':
    main()
