"""고려대 서울·세종 2026-2 미확정·숨은 보류 강좌를 공식 교시표로 확정한다(재실행 가능).

규칙(2026-11-23 사용자 결정, DailyCalendar-Timetable 스킬 4·5장):
- 원문 요일·교시가 있으면 운영 방식(원격·MOOC·혼합·유연학기·실습 장소·분반 통합 등)이
  불명확해도 대면 수업으로 보고 그 교시로 `scheduled` 확정한다.
- 교시 슬롯 = 그 교시 시작~다음 교시 시작 직전. 같은 요일·같은 강의실이고 간격 60분 미만이면
  합친다. 0교시(08:00~08:50)는 기존 자료처럼 늘리거나 합치지 않는다.
- 표에 없는 교시(서울 11교시 이후, 세종 14교시 이후)는 같은 표의 마지막 슬롯 길이(60분)로
  이어 계산한다. 이어 계산해도 24시를 넘으면 시각을 만들지 않고 `unrecognized`로 둔다.
- 강의실은 원문 줄의 강의실 그대로, 줄에 강의실이 없으면 원문 sourceClassroom을 쓴다.
  같은 시각에 강의실이 여러 개면 강의실마다 구간을 둔다(서울대 자료 선례).
- '미정(1-2)'처럼 요일이 없는 줄은 시각을 만들지 않는다. 원문에 요일·교시가 없으면
  (`미정`, 빈 값, `(6-8)`) unscheduled 그대로 둔다.
- 날짜: 원문 period 안의 같은 요일 날짜에서 공휴일(9/24~26, 10/3, 10/5 대체, 10/9)과
  중간(10/20~26)·기말(12/14~18) 주간을 뺀다. 기존 scheduled 강좌가 쓰는 날짜와 같다.
- 서울 교직 0교시: 같은 교시표 PDF의 '교직과목0교시 설정 수업시간:08:40~'와 과목 원문 비고
  '*수업시작시간 8:40'(APPLY_DEPT)이 있는 강좌는 0교시를 08:40~1교시 시작(09:00) 슬롯으로 보고
  이어지는 1교시와 합친다(예: 수(0-1) → 08:40~10:30). 일반 0교시 08:00보다 구체적인 규칙이다.

근거(2026-11-23 curl 재확인, sha256 8528da9c…dc1d9 일치):
- 서울·세종 정규학기 교시표: https://koreanstudies.korea.ac.kr/bbs/software/352/181231/download.do
  (공지 https://koreanstudies.korea.ac.kr/bbs/software/352/271273/artclView.do)
  서울 1~6교시 75분+15분(09:00 시작), 7~10교시 50분+10분, 세종 0~13교시 50분+10분(09:00 시작).
- 수강신청 사이트 교시표(https://sugang.korea.ac.kr/)도 같은 값(테스트 fixture
  source-current-ui-regular-campus-clock-education.json).
- 세종 정부행정학부 강의시간표(https://spa.korea.ac.kr/bbs/spa/149/271438/artclView.do 첨부)
  '1 교 시 9:00-9:50' ~ '7 교 시 3:00-3:50'.

일관성 검사: 기존 scheduled 강좌 중 원문이 이 변환기로 파싱되는 강좌 전부를 다시 계산해
기존 schedules와 같은지 확인한다(부분 예약·시계 시각 강좌 등 다른 규칙 강좌는 제외 목록으로 센다).
"""
import datetime
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEEKDAYS = '월화수목금토일'
EXCLUDED = {
    '2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09',
    *(f'2026-10-{d}' for d in range(20, 27)),
    *(f'2026-12-{d}' for d in range(14, 19)),
}
SLOT_STARTS = {
    'seoul': [540, 630, 720, 810, 900, 990, 1080, 1140, 1200, 1260],
    'sejong': [540 + 60 * i for i in range(13)],
}
EVIDENCE = {
    'sourceUrl': 'https://koreanstudies.korea.ac.kr/bbs/software/352/181231/download.do',
    'noticeUrl': 'https://koreanstudies.korea.ac.kr/bbs/software/352/271273/artclView.do',
    'sourceSHA256': '8528da9cc7fbabca035e844ad0f53138d765df932bf63fd9ec4f03f18f9dc1d9',
    'alsoUrls': [
        'https://sugang.korea.ac.kr/',
        'https://spa.korea.ac.kr/bbs/spa/149/271438/artclView.do',
    ],
    'checkedDate': '2026-11-23',
    'rule': '교시 시작~다음 교시 시작 직전 슬롯, 표 밖 교시는 60분 슬롯으로 이어 계산, 0교시 08:00~08:50',
    'seoulTeachingPeriod0': {
        'sourceText': '교직과목0교시 설정 수업시간:08:40~',
        'courseRemark': '*수업시작시간 8:40',
        'startMinute': 520,
        'slotEnd': '1교시 시작 09:00(다음 교시 시작 직전까지)',
    },
}
CONFIRMED = '공식 요일·교시 기준 확정(운영 방식 미표기는 대면으로 간주).'
UNDATED_LINE = " 요일이 '미정'인 원문 줄은 시각을 만들지 않았습니다."
TEACHING_ZERO_NOTE = (" 교직 0교시는 공식 교시표의 '교직과목0교시 설정 수업시간:08:40~'와 과목 비고 "
                      "'수업시작시간 8:40'에 따라 08:40부터 1교시 시작(09:00)까지를 0교시 슬롯으로 계산했습니다.")
TEACHING_REMARK = '수업시작시간 8:40'
PAST_MIDNIGHT = ('미확정(추가 불가): 원문 교시 번호를 공식 교시표 간격으로 이어 계산하면 24시를 넘어 '
                 '시각으로 바꿀 수 없습니다.')


class Unparsable(ValueError):
    pass


def slot(campus, period):
    starts = SLOT_STARTS[campus]
    if period == 0:
        return 480, 530
    if period <= len(starts):
        start = starts[period - 1]
    else:  # 표 밖 교시: 마지막 슬롯 길이(60분)로 이어 계산
        start = starts[-1] + 60 * (period - len(starts))
    end = starts[period] if period < len(starts) else start + 60
    if end > 1440:
        raise Unparsable('past-midnight')
    return start, end


def parse_lines(course):
    """원문을 (요일, 시작교시, 끝교시, 강의실) 목록으로. 요일 없는 '미정(…)' 줄은 건너뛴다."""
    raw = course['sourceSchedule'].strip()
    room_default = course['sourceClassroom'] if ' / ' not in course['sourceClassroom'] else ''
    out, skipped = [], 0
    if re.fullmatch(r'[월화수목금토일]\d+교시( / [월화수목금토일]\d+교시)*', raw):
        if ' / ' in course['sourceClassroom']:
            raise Unparsable('per-cell rooms')  # 칸마다 강의실이 달라 원문 표 칸 대응이 필요
        for wd, p in re.findall(r'([월화수목금토일])(\d+)교시', raw):
            out.append((WEEKDAYS.index(wd) + 1, int(p), int(p), course['sourceClassroom']))
        return out, skipped
    for line in raw.split('\n'):
        line = line.strip()
        if not line:
            continue
        if re.fullmatch(r'미정\(\d+(-\d+)?\)', line):
            skipped += 1
            continue
        m = re.fullmatch(r'([월화수목금토일])\((\d+)(?:-(\d+))?\)\s*(.*)', line)
        if not m:
            raise Unparsable(line)
        a, b = int(m[2]), int(m[3] or m[2])
        if b < a:
            raise Unparsable(line)
        out.append((WEEKDAYS.index(m[1]) + 1, a, b, m[4].strip() or room_default))
    if not out:
        raise Unparsable(raw)
    return out, skipped


def weekly_segments(campus, lines, teaching0=False):
    segs, fixed = [], []
    for wd, a, b, room in lines:
        if a == 0 and teaching0:  # 교직 0교시 08:40~09:00 슬롯, 1교시와 이어진다
            segs.append((wd, 520, slot(campus, b)[1] if b >= 1 else 540, room))
            continue
        if a == 0:
            fixed.append((wd, 480, 530, room))
            a = 1
        if b >= a:
            segs.append((wd, slot(campus, a)[0], slot(campus, b)[1], room))
            for p in range(a, b + 1):
                slot(campus, p)  # 중간 교시도 24시 검사
    merged = []
    for key in dict.fromkeys((s[0], s[3]) for s in segs):
        group = sorted((s for s in segs if (s[0], s[3]) == key), key=lambda s: s[1])
        cur = list(group[0])
        for s in group[1:]:
            if s[1] - cur[2] < 60:
                cur[2] = max(cur[2], s[2])
            else:
                merged.append(tuple(cur))
                cur = list(s)
        merged.append(tuple(cur))
    return fixed + merged


def dated(course, weekly):
    period = course['period']
    day = datetime.date.fromisoformat(period['startDate'])
    end = datetime.date.fromisoformat(period['endDate'])
    out = []
    while day <= end:
        iso = day.isoformat()
        if iso not in EXCLUDED:
            for i, (wd, s, e, room) in enumerate(weekly):
                if wd == day.isoweekday():
                    out.append((iso, s, i, {'weekday': wd, 'startMinute': s, 'endMinute': e,
                                            'classroom': room, 'date': iso}))
        day += datetime.timedelta(days=1)
    return [x[3] for x in sorted(out, key=lambda x: x[:3])]


def teaching_zero(course):
    apply_dept = (course.get('sourceEducationalMetadata') or {}).get('APPLY_DEPT') or ''
    return course['campus'] == 'seoul' and TEACHING_REMARK in apply_dept


def build(course):
    lines, skipped = parse_lines(course)
    weekly = weekly_segments(course['campus'], lines, teaching_zero(course))
    return dated(course, weekly), skipped


def key(schedules):
    return sorted(json.dumps(s, sort_keys=True, ensure_ascii=False) for s in schedules)


STANDARD_CLOCK = {
    'seoul': {0: (480, 530), **{p + 1: (s, s + (75 if p < 6 else 50))
                                for p, s in enumerate(SLOT_STARTS['seoul'])}},
    'sejong': {0: (480, 530), **{p + 1: (s, s + 50) for p, s in enumerate(SLOT_STARTS['sejong'])}},
}


def override(course):
    """일반 교시표가 아닌 강좌별 규칙으로 만든 기존 강좌인지(다르게 나와도 되는 사유)."""
    if course.get('sourcePartialCoverage') or course.get('sourcePerDayHolds') \
            or course.get('sourcePerBlockHolds'):
        return 'partial-or-held-block'
    table = STANDARD_CLOCK[course['campus']]
    for s in course.get('sourceCurrentClockSegments') or []:
        if table.get(s.get('sourcePeriod')) != (s['startMinute'], s['endMinute']):
            return 'course-clock'
    remarks = course['remarks']
    if '실제HH:mm' in remarks or '직접 공표된 장소' in remarks:
        return 'remark-clock-or-room'
    return None


def consistency(courses):
    """기존 scheduled 강좌 전부를 다시 계산한다. 다르면 강좌별 규칙(override) 강좌여야 한다."""
    same, overridden, unparsed, unexplained = 0, {}, 0, []
    for c in courses:
        if c['scheduleStatus'] != 'scheduled':
            continue
        try:
            built, _ = build(c)
        except Unparsable:
            unparsed += 1
            continue
        if key(built) == key(c['schedules']):
            same += 1
        elif reason := override(c):
            overridden[reason] = overridden.get(reason, 0) + 1
        else:
            unexplained.append(c['sourceId'])
    assert not unexplained, unexplained[:10]
    return same, overridden, unparsed


PARTIAL_SENTENCE = ' 원문 시각과 강의실이 확인된 회차만 부분 예약했고 미배정·원격 배정 미확정·실 중복 회차는 별도로 보류했습니다.'


def replace_hold(remarks, text):
    if text in remarks:
        return remarks
    for marker in (' 일정 보류: ', ' 예약 보류: '):
        if marker in remarks:
            return remarks[:remarks.index(marker)] + ' ' + text
    return remarks + ' ' + text


def apply(path):
    raw_text = path.read_text(encoding='utf-8')
    data = json.loads(raw_text)
    courses = data['courses']
    before = consistency(courses)
    counts = {}
    for c in courses:
        status = c['scheduleStatus']
        src = c['sourceSchedule'].strip()
        if status == 'scheduled' or src in ('', '미정'):
            continue
        hold = c['remarks']
        try:
            schedules, skipped = build(c)
        except Unparsable as e:
            if str(e) == 'past-midnight':
                c['scheduleStatus'], c['schedules'] = 'unrecognized', []
                c['remarks'] = replace_hold(hold, PAST_MIDNIGHT)
                counts['unrecognized:past-midnight'] = counts.get('unrecognized:past-midnight', 0) + 1
            else:
                counts[f'kept:{status}:{src}'] = counts.get(f'kept:{status}:{src}', 0) + 1
            continue
        c['scheduleStatus'], c['schedules'] = 'scheduled', schedules
        c['remarks'] = replace_hold(hold.replace(PARTIAL_SENTENCE, ''),
                                    CONFIRMED + (UNDATED_LINE if skipped else '')
                                    + (TEACHING_ZERO_NOTE if teaching_zero(c) else ''))
        if 'sourcePartialCoverage' in c:
            c['sourcePartialCoverage'] = bool(skipped)
        label = f'scheduled:from-{status}'
        counts[label] = counts.get(label, 0) + 1
    consistency(courses)  # 확정한 강좌도 같은 변환기 결과와 같아야 한다
    data['periodEvidence'] = EVIDENCE
    out = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    if raw_text.endswith('\n'):
        out += '\n'
    path.write_text(out, encoding='utf-8')
    return before, counts


def _self_check():
    assert slot('seoul', 4) == (810, 900) and slot('seoul', 10) == (1260, 1320)
    assert slot('seoul', 12) == (1380, 1440) and slot('sejong', 9) == (1020, 1080)
    assert slot('sejong', 14) == (1320, 1380)
    try:
        slot('sejong', 16)
        raise AssertionError('past midnight not rejected')
    except Unparsable:
        pass
    c = {'campus': 'seoul', 'sourceClassroom': '', 'sourceSchedule': '토(0-1)'}
    assert weekly_segments('seoul', parse_lines(c)[0]) == [(6, 480, 530, ''), (6, 540, 630, '')]
    c = {'campus': 'seoul', 'sourceClassroom': 'A / B', 'sourceSchedule': '금(4-6) A\n금(4-6) B'}
    assert weekly_segments('seoul', parse_lines(c)[0]) == [(5, 810, 1080, 'A'), (5, 810, 1080, 'B')]


if __name__ == '__main__':
    _self_check()
    for campus in ('seoul', 'sejong'):
        before, counts = apply(ROOT / f'assets/timetable/korea-{campus}-2026-2.json')
        same, overridden, unparsed = before
        print(campus, f'기존 scheduled 재계산: 일치 {same}, 강좌별 규칙 {overridden}, '
              f'다른 원문 형식 {unparsed}', file=sys.stderr)
        for k, v in sorted(counts.items()):
            print(campus, v, k)
