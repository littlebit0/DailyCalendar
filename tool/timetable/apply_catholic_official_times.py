# coding: utf-8
"""가톨릭대 성심교정 2026-2: 보류(unrecognized) 강좌를 공식 교시표로 확정한다.

근거: [학사행정팀] 2026-2학기 타대학 소속 학점교류생 안내사항(2026-07-28)
https://www.catholic.ac.kr/ko/campuslife/notice.do?mode=view&articleNo=274170
(2026-11-23 조회) '4. 수업교시 구간 (50분 수업, 10분 쉬는시간)
1교시 09:00~09:50 … 9교시 17:00~17:50'.

규칙(2026-11-23 사용자 결정):
- 슬롯 = 교시 시작~다음 교시 시작 직전(60분). 10교시 이후·토요일은 표에 없으므로
  같은 60분 간격으로 이어 계산한다(10교시 18:00, 14교시 22:00).
- 같은 날·같은 강의실이고 간격 60분 미만이면 한 구간으로 합친다.
- 강의실 괄호가 비면 classroom은 빈 문자열(기존 정규 예약과 같음).
- 날짜: 운영기간(2026-08-31~12-18) 안의 해당 요일 전부, 법정휴일 제외.
  2026-09-09(수) 개강미사는 2~3교시 수업을 대체(학사행정팀 2026-2학기 개강미사 및
  수업운영 안내, https://www.catholic.ac.kr/ko/campuslife/notice.do?mode=view&articleNo=275275)
  하므로 그날 2~3교시 슬롯은 뺀다. 기존 정규 예약과 같다.
- 운영 방식(원격·봉사·수도원체험 등) 미표기·비고는 대면 수업으로 보고 요일·교시로 확정.
  비고의 날짜 지정 행사(수도원체험)는 비고로만 두고 주간 일정으로 바꾸지 않는다.
- 먼저 기존 scheduled 강좌 전부를 같은 규칙으로 다시 만들어 일치하는지 확인한다.
- 파싱 못 하는 표기는 그 강좌만 unrecognized로 남긴다.

사용: 저장소 루트에서 python3 tool/timetable/apply_catholic_official_times.py
"""
import datetime as dt
import json
import re
from pathlib import Path

PATH = Path('assets/timetable/catholic-songsim-2026-2.json')
CLOCK_URL = ('https://www.catholic.ac.kr/ko/campuslife/notice.do'
             '?mode=view&articleNo=274170')
START, END = dt.date(2026, 8, 31), dt.date(2026, 12, 18)
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03',
            '2026-10-05', '2026-10-09'}
MASS_DAY, MASS_BLOCK = '2026-09-09', (600, 720)  # 개강미사: 2~3교시 대체
TOKEN = re.compile(r'([월화수목금토일])(\d{1,2})(?:~(\d{1,2}))?\(([^()]*)\)')
STD = '학교 공시의 정규 수업 계획입니다. 시험·보강·변경 사항은 학교 공지를 확인하세요.'
ROOM_NOTE = '강의실은 학교 공시 자료에 미표기되어 확인이 필요합니다.'
CONFIRMED = '공식 요일·교시 기준 확정(운영 방식 미표기는 대면으로 간주).'


def slot(period):
    return 480 + period * 60, 540 + period * 60


assert slot(1) == (540, 600) and slot(9) == (1020, 1080)  # 표 원문 1·9교시


def blocks(text):
    """원문 시간표 → 하루 안 구간 목록. 형식이 다르면 ValueError."""
    tokens = list(TOKEN.finditer(text))
    if not tokens or ', '.join(m[0] for m in tokens) != text:
        raise ValueError(f'unparsed schedule: {text!r}')
    slots = []
    for m in tokens:
        first, last = int(m[2]), int(m[3] or m[2])
        if not 1 <= first <= last <= 14:
            raise ValueError(f'period out of range: {text!r}')
        weekday = '월화수목금토일'.index(m[1]) + 1
        for p in range(first, last + 1):
            slots.append((weekday, *slot(p), m[4]))
    return slots


def merge(slots):
    out = []
    for w, a, b, room in sorted(set(slots), key=lambda s: (s[0], s[3], s[1])):
        if out and out[-1][0] == w and out[-1][3] == room and a - out[-1][2] < 60:
            out[-1][2] = max(out[-1][2], b)
        else:
            out.append([w, a, b, room])
    return out


def schedules(text):
    by_day = {}
    for w, a, b, room in blocks(text):
        by_day.setdefault(w, []).append((w, a, b, room))
    result = []
    day = START
    while day <= END:
        iso = day.isoformat()
        w = day.isoweekday()
        if w in by_day and iso not in HOLIDAYS:
            slots = by_day[w]
            if iso == MASS_DAY:
                slots = [s for s in slots
                         if s[2] <= MASS_BLOCK[0] or s[1] >= MASS_BLOCK[1]]
            for _, a, b, room in merge(slots):
                result.append({'weekday': w, 'startMinute': a, 'endMinute': b,
                               'classroom': room, 'date': iso})
        day += dt.timedelta(days=1)
    result.sort(key=lambda s: (s['date'], s['startMinute']))
    return result


def remark(source, blank_room):
    lines = [source] if source else []
    lines += [STD, CONFIRMED]
    if blank_room:
        lines.append(ROOM_NOTE)
    return '\n'.join(lines)


def main():
    raw = PATH.read_text(encoding='utf-8')
    data = json.loads(raw)
    courses = data['courses']
    # 일관성 검사: 기존 정규 예약 전체가 같은 규칙으로 다시 만들어져야 한다.
    for c in courses:
        if c['scheduleStatus'] == 'scheduled':
            assert schedules(c['sourceSchedule']) == c['schedules'], c['sourceId']
    confirmed, held = 0, []
    for c in courses:
        if c['scheduleStatus'] != 'unrecognized':
            continue
        try:
            made = schedules(c['sourceSchedule'])
        except ValueError as error:
            held.append((c['sourceId'], str(error)))
            continue
        if not made:
            held.append((c['sourceId'], 'no meeting dates'))
            continue
        c['schedules'] = made
        c['scheduleStatus'] = 'scheduled'
        blank = any(not s['classroom'] for s in made)
        c['departmentRemarks'] = {
            k: remark(v, blank) for k, v in c['departmentRemarks'].items()}
        confirmed += 1
    data['periodEvidence'] = {
        'sourceUrl': CLOCK_URL,
        'retrievedDate': '2026-11-23',
        'quote': '4. 수업교시 구간 (50분 수업, 10분 쉬는시간) '
                 '1교시 09:00~09:50 … 9교시 17:00~17:50',
        'extension': '10~14교시·토요일은 같은 60분 간격으로 이어 계산',
        'massDayUrl': ('https://www.catholic.ac.kr/ko/campuslife/notice.do'
                       '?mode=view&articleNo=275275'),
    }
    PATH.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':'))
                    + ('\n' if raw.endswith('\n') else ''), encoding='utf-8')
    print(f'confirmed={confirmed} held={len(held)}')
    for item in held:
        print('held', *item)


if __name__ == '__main__':
    main()
