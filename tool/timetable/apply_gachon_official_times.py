"""가천대 2026-2 보류 강좌를 공식 요일·교시로 확정한다(재실행 가능).

근거
- 교시표: 학사공지 「2026-2학기 예비수강신청 안내」
  https://www.gachon.ac.kr/bbs/kor/475/122331/artclView.do 의 첨부
  「강의시간표(2026-2).pdf」 https://www.gachon.ac.kr/bbs/kor/475/151337/download.do
  (50분수업, 1교시 09:00~09:50 … 14교시 22:00~22:50, 2026-11-23 curl 조회).
- 휴일: 기존 scheduled 강좌가 이미 빼는 날(추석 9/24~9/26, 개천절 대체 10/3·10/5, 한글날 10/9).

규칙(2026-11-23 사용자 결정)
- 원문 요일·교시가 있으면 운영 방식(원격·MOOC·실습·휴보강 등)이 불명확해도 대면으로 보고 확정한다.
- 교시 슬롯 = 시작~다음 교시 시작 직전(60분). 같은 요일·강의실에서 간격 60분 미만이면 합친다.
- 날짜는 강좌 period 안의 매주 해당 요일에서 휴일을 뺀다. period가 없는 12주·4주 강좌는
  같은 파일의 같은 종류 scheduled 강좌가 모두 쓰는 기간(12주 9/1~11/23, 4주 11/24~12/21)을 쓴다.
- 공식 강의시간표의 요일·교시를 그대로 쓴다. 강의계획서 일정과 달라도 보류하지 않는다(AI-NTree, 스킬 5장).
- 기간을 정할 수 없으면 보류를 유지한다.
- 일관성 검사: 기존 scheduled 강좌 전부의 구간 모양(요일·시각·강의실)을 이 변환기로 다시 계산해 같아야 한다.
"""

import datetime as dt
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FILES = [ROOT / f'assets/timetable/gachon-{c}-2026-2.json' for c in ('global', 'medical')]
CLOCK_URL = 'https://www.gachon.ac.kr/bbs/kor/475/151337/download.do'
NOTICE_URL = 'https://www.gachon.ac.kr/bbs/kor/475/122331/artclView.do'
DAYS = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7}
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}
INTENSIVE_PERIODS = {
    '12': {'startDate': '2026-09-01', 'endDate': '2026-11-23'},
    '4': {'startDate': '2026-11-24', 'endDate': '2026-12-21'},
}
# AI-NTree 2강좌: 공개 강의계획서(showTimetable.do → 수업계획서 SSU0906R, 2026-11-23 조회)는 강화캠퍼스
# 1박 2일 합숙(019: 8.27~8.28, 001: 학과별 날짜)이지만 시각이 없다. 스킬 5장(건국 집중이수 사례)에 따라
# 공식 강의시간표의 요일·교시(금13·14)를 그대로 쓰고, 기간은 같은 파일 일반 15주 강좌 기간을 쓴다.
# 강의계획서 일정은 비고에 참고로 남긴다.
SYLLABUS_INTENSIVE = {
    'gachon/20/2026/2/16013/001': '학과별 1박 2일(9.3~9.4 … 11.19~11.20)',
    'gachon/20/2026/2/16013/019': '8.27~8.28 1박 2일',
}
SEMESTER_PERIOD = {'startDate': '2026-09-01', 'endDate': '2026-12-14'}
CLOCK_TEXT = {'gachon/20/2026/2/12718/001'}  # 원문이 시각을 직접 적은 강좌
# 기존 scheduled 중 가상 강의실을 빈 강의실로 저장한 3강좌(나머지 71강좌는 원문 그대로). 시각은 같다.
EMPTY_ROOM_EXCEPTIONS = {
    'gachon/20/2026/2/13978/006', 'gachon/20/2026/2/14801/004', 'gachon/20/2026/2/14801/005',
}
HELD_PREFIX = '수업 운영 미확인:'
CONFIRMED_NOTE = ('공식 요일·교시 기준 확정(운영 방식 미표기는 대면으로 간주). '
                  '시험·보강·변경 사항은 학교 공지를 확인하세요.')
TOKEN = re.compile(r'([월화수목금토일])([0-9]+)')


def period_start(number):
    # 표 1~14교시는 09:00부터 60분 간격. 표 밖 교시도 같은 슬롯 길이로 이어 계산한다.
    if number < 1:
        raise ValueError(f'교시 번호 {number}')
    return 480 + 60 * number


def blocks(source, classroom):
    tokens = [t.strip() for t in source.split(',')]
    if not source.strip() or any(not TOKEN.fullmatch(t) for t in tokens):
        raise ValueError(f'해석할 수 없는 교시 표기: {source!r}')
    slots = sorted({(DAYS[m[1]], period_start(int(m[2]))) for m in map(TOKEN.fullmatch, tokens)})
    result = []
    for weekday, start in slots:
        last = result[-1] if result else None
        if last and last['weekday'] == weekday and start - last['endMinute'] < 60:
            last['endMinute'] = start + 60
        else:
            result.append({'weekday': weekday, 'startMinute': start,
                           'endMinute': start + 60, 'classroom': classroom})
    return result


def dated(block_list, period):
    day = dt.date.fromisoformat(period['startDate'])
    end = dt.date.fromisoformat(period['endDate'])
    out = []
    while day <= end:
        key = day.isoformat()
        if key not in HOLIDAYS:
            out += [{**b, 'date': key} for b in block_list if b['weekday'] == day.isoweekday()]
        day += dt.timedelta(days=1)
    return out


def shape(schedules):
    return sorted({(s['weekday'], s['startMinute'], s['endMinute'], s['classroom']) for s in schedules})


def main():
    confirmed = {'unrecognized': 0, 'unscheduled': 0}
    held = []
    for path in FILES:
        text = path.read_text(encoding='utf-8')
        data = json.loads(text)
        for course in data['courses']:
            sid = course['sourceId']
            if course['scheduleStatus'] == 'scheduled':
                if sid not in CLOCK_TEXT:
                    room = '' if sid in EMPTY_ROOM_EXCEPTIONS else course['sourceClassroom']
                    expected = shape(blocks(course['sourceSchedule'], room))
                    assert shape(course['schedules']) == expected, sid
                continue
            try:
                block_list = blocks(course['sourceSchedule'], course['sourceClassroom'])
            except ValueError as error:
                if course['scheduleStatus'] == 'unrecognized':
                    held.append((sid, str(error)))
                continue  # 원문에 시각이 없는 unscheduled는 그대로 둔다
            period = course.get('period')
            if period is None:
                weeks = re.search(r'\((\d+)주', course['courseName'])
                period = (SEMESTER_PERIOD if sid in SYLLABUS_INTENSIVE
                          else INTENSIVE_PERIODS.get(weeks and weeks.group(1)))
                if period is None:
                    held.append((sid, '수업 기간 미확인'))
                    continue
                course['period'] = dict(period)
            confirmed[course['scheduleStatus']] += 1
            course['schedules'] = dated(block_list, period)
            assert course['schedules'], sid
            course['scheduleStatus'] = 'scheduled'
            course['unresolvedReasons'] = []
            course.setdefault('sourceDepartmentRemarks', dict(course['departmentRemarks']))
            remarks = {}
            for department, value in course['departmentRemarks'].items():
                lines = [line for line in value.split('\n')
                         if line.strip() and not line.startswith(HELD_PREFIX)]
                note = [f'참고: 공개 강의계획서 일정은 강화캠퍼스 {SYLLABUS_INTENSIVE[sid]} 합숙(시각 미표기).'] \
                    if sid in SYLLABUS_INTENSIVE else []
                remarks[department] = '\n'.join(lines + note + [CONFIRMED_NOTE])
            course['departmentRemarks'] = remarks
        data['periodEvidence'] = {
            'clockSource': CLOCK_URL,
            'clockNotice': NOTICE_URL,
            'clockNoticeTitle': '2026-2학기 예비수강신청 안내 · 첨부 강의시간표(2026-2).pdf',
            'clock': '50분수업 1교시 09:00~09:50 … 14교시 22:00~22:50, 슬롯 60분',
            'retrieved': '2026-11-23',
        }
        out = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
        path.write_text(out + ('\n' if text.endswith('\n') else ''), encoding='utf-8')
    print('confirmed', confirmed)
    for sid, reason in held:
        print('held', sid, reason)
    return 0


if __name__ == '__main__':
    sys.exit(main())
