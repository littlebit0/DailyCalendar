"""Build the Dongguk University WISE campus 2026-2 undergraduate timetable asset.

Source: 동국대학교 학사정보시스템 종합강의시간표(국문) 비로그인 공개 화면
(SOURCE_URL), 조직분류 학부(WISE)·2026·2학기 조회. The saved response of
POST /ed/edc/lesn/EdcLesn010/doList.do ({request, capturedAt, body:{dsMain}},
collected 2026-11-23) is the only input; every row of dsMain becomes one
course, including rows the screen may mark as closed (user decision
2026-11-23: closures are not judged).

    python3 tool/timetable/import_dongguk_wise.py <doList.json> assets/timetable/dongguk-wise-2026-2.json

Clock evidence (TMTBL_KOR_DSC, e.g. '월 1.5교시(09:30) ~ 4교시(12:30)'):
the bracket after the first period is the start clock and the bracket after
'~' is the end clock. WISE periods are one hour from 09:00 with half periods
(N.5교시 = second half of period N); every bracketed start equals
09:00 + (N-1)h and every bracketed end equals 09:00 + (M-1)h + 30min in all
1683 rows. Read this way the weekly total equals 이론+실습 시수 or 학점 in
1477 of the 1493 week-unlimited timed rows, e.g. '월 1.5교시(09:30) ~
4교시(12:30)' is 180 min for 3.0 시수 and '화, 목 7교시(15:00) ~ 8교시(16:30)'
is 2 x 90 min for 3.0 시수. The clocks are used as printed; periods are only
checked against them, never used to recompute a time.

Status rules (DailyCalendar-Timetable skill 5):
- scheduled: every segment parses. Operating mode (사이버·HyFlex·실습) does
  not change this (user decision 2026-11-23). A weekly total that differs
  from 시수·학점 (16 rows) is kept as printed and noted in remarks: the
  official weekday and clock are used as published (skill 5, 건국 집중이수).
- 'N주차 - N주차' rows (간호학과, 52) are dated by WISE teaching weeks. The
  WISE calendar runs every term period Tuesday to Monday (개강 9/1 Tue,
  정정 9/1~9/7, 중간시험 10/13~10/26 = weeks 7-8, 기말시험 12/8~12/14 = week
  15, 종강 12/14 Mon), so week N is 9/1 + 7(N-1) .. +6. The nursing
  department confirms 16주차: its notice of 2026-11-09 (NURSING_EXAM_NOTICE)
  moved the 졸업 종합시험 from 12/18 (Fri) to 12/17 because it overlapped the
  SPBL class, which the timetable prints as NUR42422 '16주차 - 16주차 금'.
  Only public holidays are skipped; the printed weeks already decide exams.
- unrecognized: only a text that does not parse.
- unscheduled: TMTBL_KOR_DSC is empty (사이버강의, 의학과 block courses,
  임상실습, 집중수업 etc.): the school publishes no weekday or clock.

Dated meetings follow the existing Dongguk Seoul asset: weekly meetings are
expanded from 2026-09-01 to 2026-12-07, skipping the WISE midterm and final
exam periods and public holidays. WISE academic calendar
(https://wise.dongguk.ac.kr/schedule/detail?schedule_info_seq=22, saved as
test/fixtures/academic/dongguk-wise-2026.html): 개강/학기개시일 2026.09.01.,
2학기 중간시험 2026.10.13. ~ 2026.10.26., 2학기 기말시험 2026.12.08. ~
2026.12.14., 종강 2026.12.14.
"""
import collections
import datetime as dt
import hashlib
import json
import re
import sys
from pathlib import Path

SOURCE_URL = ('https://support.dongguk.ac.kr/unis/index.do?t='
              '654867724D6E564B57577777554374315558647861564273646A524251543039')
CALENDAR_URL = 'https://wise.dongguk.ac.kr/schedule/detail?schedule_info_seq=22'
NURSING_EXAM_NOTICE = ('https://nursing.dongguk.ac.kr/HOME/nursing/sub.htm?nav_code=nur1587087792 '
                       '학과공지 298 「졸업 종합시험 일정 변경 안내」(2026-11-09)')
TERM_START = dt.date(2026, 9, 1)
TERM_END = dt.date(2026, 12, 14)
LAST_CLASS = dt.date(2026, 12, 7)  # the day before the final exam period
EXAM_PERIODS = ((dt.date(2026, 10, 13), dt.date(2026, 10, 26)),
                (dt.date(2026, 12, 8), dt.date(2026, 12, 14)))
# 관공서의 공휴일에 관한 규정: 추석 9/24~26, 개천절 10/3과 대체공휴일 10/5, 한글날 10/9
# (lib/core/calendar/korean_holiday_service.dart, same dates as dongguk-seoul-2026-2).
HOLIDAYS = {dt.date(2026, 9, 24), dt.date(2026, 9, 25), dt.date(2026, 9, 26),
            dt.date(2026, 10, 3), dt.date(2026, 10, 5), dt.date(2026, 10, 9)}
WEEKDAYS = {d: i + 1 for i, d in enumerate('월화수목금토일')}
SEGMENT = re.compile(
    r'(?:(\d+)주차 - (\d+)주차 )?((?:[월화수목금토일], )*[월화수목금토일]) '
    r'(\d+(?:\.5)?)교시\((\d\d):(\d\d)\) ~ (\d+(?:\.5)?)교시\((\d\d):(\d\d)\)')


class Held(Exception):
    pass


def segments(text):
    """[(weeks, weekday, start, end)] from TMTBL_KOR_DSC (weeks None = every week), or ValueError."""
    found = list(SEGMENT.finditer(text))
    if not found or ', '.join(m.group(0) for m in found) != text:
        raise ValueError(f'unknown schedule text: {text!r}')
    out = []
    for m in found:
        first, last = float(m[4]), float(m[7])
        start, end = int(m[5]) * 60 + int(m[6]), int(m[8]) * 60 + int(m[9])
        # Bracket clocks must agree with the WISE hour grid; they are used as printed.
        if start != 540 + round((first - 1) * 60) or end != 540 + round((last - 1) * 60) + 30 or start >= end:
            raise ValueError(f'clock does not match period: {m.group(0)!r}')
        for day in m[3].split(', '):
            weeks = range(int(m[1]), int(m[2]) + 1) if m[1] else None
            if weeks is not None and not weeks:
                raise ValueError(f'empty week range: {m.group(0)!r}')
            out.append((weeks, WEEKDAYS[day], start, end))
    return out


def merge(spans):
    """Join same-weekday spans that overlap or are less than 60 minutes apart."""
    out = []
    for day, start, end in sorted(spans):
        if out and out[-1][0] == day and start - out[-1][2] < 60:
            out[-1][2] = max(out[-1][2], end)
        else:
            out.append([day, start, end])
    return [tuple(s) for s in out]


def week_date(week, weekday):
    """Date of `weekday` in WISE teaching week `week` (Tuesday 9/1 starts week 1)."""
    return TERM_START + dt.timedelta(days=7 * (week - 1) + (weekday - TERM_START.isoweekday()) % 7)


def class_dates(weekday):
    day = TERM_START
    while day <= LAST_CLASS:
        if (day.isoweekday() == weekday and day not in HOLIDAYS
                and not any(a <= day <= b for a, b in EXAM_PERIODS)):
            yield day
        day += dt.timedelta(days=1)


def hours(value):
    return float(value or 0)


def schedule(row):
    """(status, [(weekday, start, end, date)], note): weekly rows expand over class_dates,
    week-limited rows over their printed weeks."""
    text = row['TMTBL_KOR_DSC'] or ''
    if not text.strip():
        return 'unscheduled', [], None
    parts = segments(text)
    if any(weeks for weeks, *_ in parts):
        if not all(weeks for weeks, *_ in parts):
            raise ValueError(f'mixed weekly and week-limited text: {text!r}')
        by_date = collections.defaultdict(list)
        for weeks, day, start, end in parts:
            for week in weeks:
                date = week_date(week, day)
                if date not in HOLIDAYS:
                    by_date[date].append((day, start, end))
        meetings = [(d, s, e, date) for date in sorted(by_date) for d, s, e in merge(by_date[date])]
        return 'scheduled', meetings, '주차 한정'
    weekly = sum(end - start for _, _, start, end in parts) / 60
    note = None
    if weekly not in (hours(row['THRY_HCNT']) + hours(row['PRAC_HCNT']), hours(row['CDT'])):
        note = (f'원문 주간 시각 합계 {weekly:g}시간이 시수(이론 {hours(row["THRY_HCNT"]):g}·실습 {hours(row["PRAC_HCNT"]):g})·'
                f'학점 {hours(row["CDT"]):g}과 다르나 공식 요일·시각을 그대로 사용')
    meetings = [(d, s, e, date) for d, s, e in merge((d, s, e) for _, d, s, e in parts) for date in class_dates(d)]
    return 'scheduled', meetings, note


def clean(value):
    return ' '.join(str(value).split()) if value is not None else ''


def room_text(raw):
    return ', '.join(clean(p) for p in (raw or '').split(',') if clean(p))


def course(row):
    code, section = clean(row['SBJ_NO']), clean(row['DVCLS'])
    held = None
    try:
        status, meetings, note = schedule(row)
    except ValueError as error:
        status, meetings, note = 'unrecognized', [], None
        held = ('표기 해석 불가', str(error))
    room = room_text(row['ROOM_KOR_DSC'])
    departments = [clean(row[k]) for k in ('COLG_NM', 'DPT_NM', 'MJR_NM') if clean(row[k])]
    native = [f'학수번호-분반 {code}-{section}', f'교과목명 {clean(row["SBJ_NM"])}',
              f'교원 {clean(row["PROF_KOR_DSC"]) or "미표기"}',
              f'요일/교시 {clean(row["TMTBL_KOR_DSC"]) or "미표기"}', f'강의실 {room or "미표기"}',
              f'이수구분 {clean(row["CPDIV_CD_NM"])}', f'세부교과과정 {clean(row["DETL_CURI_CD_NM"]) or "미표기"}',
              f'강의형태 {clean(row["LESN_STY_CD"])}', f'강의유형 {clean(row["LESN_TYP_CD"]) or "미표기"}',
              f'대상학년 {clean(row["OBJ_SCHGRD"]) or "미표기"}',
              f'이론/실습/학점 {clean(row["THRY_HCNT"])}/{clean(row["PRAC_HCNT"])}/{clean(row["CDT"])}',
              f'강의지역 {clean(row["LESN_REGN_CD_NM"])}']
    if clean(row['REMK_DSC']):
        native.append(f'비고 {clean(row["REMK_DSC"])}')
    if clean(row['CLSLESN_DT']) or clean(row['CLSLESN_RESN_DSC']):
        native.append(f'폐강 원문 {clean(row["CLSLESN_DT"])} {clean(row["CLSLESN_RESN_DSC"])}'.strip())
    remarks = ['공식 종합강의시간표 원문: ' + ', '.join(native)]
    if note == '주차 한정':
        remarks.append('원문 괄호 시각을 그대로 사용. N주차는 학사일정의 화~월 주 단위(1주차 9/1~9/7, 8주차 10/20~26, '
                       '15주차 12/8~14, 16주차 12/15~21)로 날짜를 정하고 공휴일만 제외. 16주차 수업은 간호학과 '
                       f'공지({NURSING_EXAM_NOTICE}: 12/18(금) 졸업 종합시험이 SPBL 수업 일정과 겹쳐 12/17로 변경)로 확인')
    elif status == 'scheduled':
        remarks.append('원문 괄호 시각을 그대로 사용. 9/1 개강~12/7, 중간시험 10/13~26·기말시험 12/8~14·공휴일 제외')
        if note:
            remarks.append(note)
    elif held:
        remarks.append('일정 보류: ' + held[1])
    else:
        remarks.append('요일·교시 원문 없음(시간 미정)')
    return {
        'sourceId': f'dongguk/wise/2026-2/{code}-{section}',
        'campus': 'wise', 'academicYear': 2026, 'semester': '2',
        'courseCode': code, 'courseName': clean(row['SBJ_NM']), 'section': section,
        'professor': clean(row['PROF_KOR_DSC']), 'classification': clean(row['CPDIV_CD_NM']),
        'credits': hours(row['CDT']), 'departmentCredits': {}, 'departmentClassifications': {},
        'departments': departments, 'remarks': '. '.join(remarks),
        'sourceSchedule': clean(row['TMTBL_KOR_DSC']), 'sourceClassroom': room,
        'scheduleStatus': status,
        # 16주차 (12/15~21) runs past 종강 12/14, so the period ends at the last printed meeting.
        'period': {'startDate': TERM_START.isoformat(),
                   'endDate': max([TERM_END] + [day for *_, day in meetings]).isoformat()},
        'schedules': [{'weekday': d, 'startMinute': s, 'endMinute': e, 'classroom': room, 'date': day.isoformat()}
                      for d, s, e, day in meetings],
        '_held': held,
    }


def build(rows):
    courses = [course(r) for r in rows]
    ids = collections.Counter(c['sourceId'] for c in courses)
    if max(ids.values()) > 1:
        raise ValueError(f'duplicate sourceId: {[k for k, v in ids.items() if v > 1]}')
    held = collections.Counter(reason[0] for c in courses if (reason := c.pop('_held')))
    return sorted(courses, key=lambda c: c['sourceId']), held


def main(argv):
    src, out = argv
    raw = Path(src).read_bytes()
    rows = json.loads(raw)['body']['dsMain']
    courses, held = build(rows)
    statuses = collections.Counter(c['scheduleStatus'] for c in courses)
    data = {
        'schemaVersion': 2, 'universityId': 'dongguk', 'campus': 'wise', 'campusName': 'WISE캠퍼스',
        'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-11-23',
        'publishedDateMeaning': 'public query acquisition date, not an official posting date',
        'sourceUrl': SOURCE_URL,
        'sourceNotice': (f'동국대학교 학사정보시스템 종합강의시간표(국문) 비로그인 공개 화면, 조직분류 학부(WISE)·2026학년도 2학기 '
                         f'조회 결과 {len(rows)}행(2026-11-23 수집). 원문 괄호 시각을 그대로 쓰고, 학사일정({CALENDAR_URL}) '
                         f'개강 9/1·중간시험 10/13~26·기말시험 12/8~14와 공휴일을 뺀 날짜로 펼칩니다. 간호학과 N주차 표기는 '
                         f'학사일정의 화~월 주 단위(1주차 9/1~9/7)로 날짜를 정하고 공휴일만 뺍니다(16주차 수업은 간호학과 공지 확인: '
                         f'{NURSING_EXAM_NOTICE}).'),
        'periodEvidence': ('TMTBL_KOR_DSC 괄호: 앞=시작, ~ 뒤=끝. 1교시 09:00부터 1시간 교시·N.5교시 30분 격자와 전 행 일치, '
                           '주간 합계가 시수·학점과 일치하는 행 1477/1493.'),
        'sourceRowCount': len(rows),
        'sourceHashes': {'doList.do 응답 JSON (sha256)': hashlib.sha256(raw).hexdigest()},
        'courseScheduleStatusCounts': dict(sorted(statuses.items())),
        'heldReasonCounts': dict(sorted(held.items())),
        'researchOnly': False, 'productionIntegrationEnabled': True,
        'completionClaim': False, 'wholeOperatingVerified': False,
        'courses': courses,
    }
    Path(out).write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(json.dumps({'rows': len(rows), 'courses': len(courses), 'status': statuses, 'held': held,
                      'meetings': sum(len(c['schedules']) for c in courses)}, ensure_ascii=False))


if __name__ == '__main__':
    main(sys.argv[1:])
