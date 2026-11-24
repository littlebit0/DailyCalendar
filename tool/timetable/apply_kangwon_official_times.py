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
- 한 묶음에 같은 교시를 여러 번 적은 삼척 이러닝 표기('토1,1,1', 3학점)는 그 교시 한 칸이다
  (2차, 2026-11-23). 근거: 학사공지 pstSn=2540 첨부 LRS 시간표(자연어처리·유기화학 토1 등
  15강좌가 같은 요일·교시 한 칸, '강의시간은 시험시간'), 춘천 같은 과목 1분반 원문 '토1'·'토4'
  ·'토5'·'토6', 학사공지 pstSn=346(이러닝 강좌 수업시간(시험시간) 편성).
- 원문 '0'이어도 pstSn=2540 첨부 표에 강좌번호가 있는 LRS·원격 강좌는 그 요일·시각으로 확정한다
  (LRS_TIMES). 표에 없는 '0' 강좌(현장실습 등)만 unscheduled로 둔다.
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
BLANK_NOTE = '공식 시간표에 요일·시각 미게시: 시간 미정 강좌로 추가 가능'
REPEATED_OK_NOTE = '같은 교시 반복 표기는 그 교시 한 칸(이러닝 수업·시험시간)으로 확정: 공식 LRS 시간표·같은 과목 춘천 분반 원문 기준'
LRS_NOTE = '원문 수업시간 0: 공식 미래융합가상학과·강원LRS공유대학 시간표의 요일·시각(시험시간)으로 확정'

# 2차(2026-11-23): 강원대 학사공지 '2026학년도 2학기 미래융합가상학과(융합전공) 개설 교과목
# 및 시간표 안내'(강릉교육지원과, 2026-07-24) 첨부 엑셀. 본문: '강원LRS공유대학에서 정규학기에
# 운영되는 교과목은 중간·기말 시험을 위하여 편성되었으며, 강의시간은 시험시간'.
LRS_URL = 'https://www.kangwon.ac.kr/ko/bbs/720/detail.do?pstSn=2540'
# 강좌번호 → 원문 강의시간 칸. 'n (HH:mm~HH:mm)' 교시는 숫자 교시 60분 슬롯과 같은 값이다.
LRS_TIMES = {
    '83090004': '일7 (15:00~16:00)', '83090010': '일8 (16:00~17:00)',
    '83090022': '일6 (14:00~15:00)', '83090024': '일2 (10:00~11:00)',
    '83090025': '일3 (11:00~12:00)', '83090026': '일1 (09:00~10:00)',
    '83090029': '일5 (13:00~14:00)', '83090031': '토1 (09:00~10:00)',
    '83170015': '일5 (13:00~14:00)', '83120002': '일7 (15:00~16:00)',
    '83170011': '일2 (10:00~11:00)', '83120018': '일3 (11:00~12:00)',
    '83120019': '일6 (14:00~15:00)', '83120022': '일8 (16:00~17:00)',
    '83170010': '일7 (15:00~16:00)', '83170031': '일3 (11:00~12:00)',
    '83170033': '일6 (14:00~15:00)', '83170034': '일8 (16:00~17:00)',
    '83080005': '일09:00~10:00', '83080026': '일09:00~10:00',
    '83020005': '일6 (14:00~15:00)', '83020007': '일3 (11:00~12:00)',
    '83020017': '일7 (15:00~16:00)', '83020018': '일2 (10:00~11:00)',
    '83020020': '토2 (10:00~11:00)', '83020021': '일5 (13:00~14:00)',
    '83020031': '토7 (15:00~16:00)',
}


def lrs_meeting(text):
    m = re.fullmatch(r'([토일])(?:(\d+) )?\(?(\d\d):(\d\d)~(\d\d):(\d\d)\)?', text)
    if not m:
        raise ValueError('unparsed_lrs_clock')
    start, end = int(m[3]) * 60 + int(m[4]), int(m[5]) * 60 + int(m[6])
    if m[2]:
        assert slot(m[2])[:2] == (start, end), text  # 표의 교시와 시각이 교시표와 같다.
    return [{'weekday': DAYS.index(m[1]) + 1, 'startMinute': start, 'endMinute': end, 'classroom': ''}]


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
assert lrs_meeting('토1 (09:00~10:00)') == [{'weekday': 6, 'startMinute': 540, 'endMinute': 600, 'classroom': ''}]
assert lrs_meeting('일09:00~10:00')[0]['weekday'] == 7


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
        if len(set(periods)) == 1:
            # '토1,1,1'(이러닝 3학점): 공식 LRS 시간표·춘천 같은 과목 1분반 원문('토1')이
            # 그 교시 한 칸(시험시간)이다(LRS_URL 참고).
            periods = periods[:1]
        elif len(set(periods)) != len(periods):
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
                if c['sourceSchedule'].strip() == '0':
                    assert lrs_meeting(LRS_TIMES[c['courseCode']]) == c['schedules'], c['sourceId']
                else:
                    assert convert(c) == c['schedules'], c['sourceId']
        counts = {'scheduled': 0, 'unscheduled': 0, 'unrecognized': {}, 'lrs': 0, 'repeated': 0}
        # 한 번 실행으로 끝나도록 바뀐 강좌가 없을 때까지 반복한다(예: unrecognized '0' → unscheduled → LRS 확정).
        while True:
            before = json.dumps(data['courses'], ensure_ascii=False)
            counts['unrecognized'] = {}
            for c in data['courses']:
                # 2차: 시간 미정으로 둔 '0'(LRS 강좌)과 '토1,1,1' 표기를 공식 LRS 시간표로 확정한다.
                if c['scheduleStatus'] == 'unscheduled':
                    remarks = ' '.join(c['departmentRemarks'].values())
                    if NONE_NOTE in remarks and c['courseCode'] in LRS_TIMES:
                        schedules, old, note, key = lrs_meeting(LRS_TIMES[c['courseCode']]), NONE_NOTE, LRS_NOTE, 'lrs'
                    elif REPEATED_NOTE in remarks:
                        schedules, old, note, key = convert(c), REPEATED_NOTE, REPEATED_OK_NOTE, 'repeated'
                    else:
                        continue
                    c['scheduleStatus'], c['schedules'] = 'scheduled', schedules
                    c['departmentRemarks'] = {k: v.replace(old, note) for k, v in c['departmentRemarks'].items()}
                    counts[key] += 1
                    continue
                if c['scheduleStatus'] != 'unrecognized':
                    continue
                if not c['sourceSchedule'].strip():
                    # 원문 시간표 칸이 비면 시각이 없다: convert()가 빈 구간을 돌려줘도 scheduled로 두지 않는다.
                    status, schedules, note = 'unscheduled', [], BLANK_NOTE
                elif c['sourceSchedule'].strip() == '0' and c['sourceClassroom'].strip() == '0':
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
            if json.dumps(data['courses'], ensure_ascii=False) == before:
                break
        data['periodEvidence'] = {
            'url': CLOCK_URL, 'checkedDate': '2026-11-23',
            'text': 'A1교시(75분) 09:00~10:15 … A6교시(75분) 16:30~17:45 / '
                    '1교시(50분) 09:00~09:50 … 14교시(50분) 22:00~22:50',
            'rule': '슬롯=교시 시작~다음 교시 시작(숫자 60분·A 90분), 15교시·A7~A9는 같은 슬롯 길이로 이어 계산'}
        if campus in ('gangneung', 'samcheok'):
            data['periodEvidence']['lrsTimetable'] = {
                'url': LRS_URL, 'checkedDate': '2026-11-23',
                'text': '강원LRS공유대학에서 정규학기에 운영되는 교과목은 중간·기말 시험을 위하여 '
                        '편성되었으며, 강의시간은 시험시간 (첨부: 개설 교과목 및 시간표 취합 안내.xlsx, '
                        '강원LRS공유대학 2026학년도 2학기 개설 교과목 시간표.xlsx)',
                'rule': "원문 '0' LRS 강좌는 첨부 표의 요일·시각, 삼척 '토n,n,n' 이러닝은 그 교시 한 칸"}
        text = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
        path.write_text(text + ('\n' if raw.endswith('\n') else ''), encoding='utf-8')
        report[campus] = counts
    print(json.dumps(report, ensure_ascii=False))


if __name__ == '__main__':
    main()
