#!/usr/bin/env python3
"""백석대 2026-2 학부 강좌의 교시 원문을 교시 시각으로 확정하고 시간 미정 강좌를 정리한다.

근거: 간호학과 공지 「2026-1 자율실습 시간표」 첨부 교시표(1교시(9-10)~8교시(16-17))와 교무처 「2026학년도 제2학기 수업시간표」 주요사항 책자
(https://www.bu.ac.kr/sites/web/files/sugang/2026_2/2026_2_juyo.pdf, PDF 43쪽, 인쇄 38쪽,
C-4 원격교육 운영안내 ⑦ 출석정보 확인방법) 의 대면수업 예시
"월요일 7교시" 강의시간 15:00-15:50, 다음 교시 16:00-16:50.
같은 60분 슬롯(50분 수업 + 10분)으로 1교시 09:00부터 이어 계산한다.
「원격교육 운영규정」 제5조 ③(1시간 = 50분)과 같은 길이다.

계약학과 자체 시각(scopedClockProof)·기존 직접 시각(sourceClockProof) 강좌는 건드리지 않는다.
원문 필드(sourceSchedule, sourceClassroom 등)는 바꾸지 않는다. 다시 실행해도 결과가 같다.
"""
import datetime as dt
import json
import re
import sys
from pathlib import Path

ASSET = Path(__file__).resolve().parents[2] / 'assets/timetable/baekseok-unknown-2026-2.json'
HOLD = '학교 전체 교시 시각과 개별 운영·변경 사항을 검증하기 전으로 시간표 자동 추가를 보류합니다.'
SOURCE = 'https://www.bu.ac.kr/sites/web/files/sugang/2026_2/2026_2_juyo.pdf'
TABLE_URL = 'https://community.bu.ac.kr/bbs/nurse/915/54397/artclView.do'
TABLE_FILE = 'https://community.bu.ac.kr/bbs/nurse/915/52175/download.do'
CLOCK_NOTE = (
    '교시 시각: 간호학과 공지 「2026-1 자율실습 시간표」 첨부 교시표(Sheet1 A4~A11: 1교시(9-10)~8교시(16-17), '
    + TABLE_URL + ')와 교무처 2026-2학기 수업시간표 주요사항 책자 38쪽(PDF 43쪽) 대면수업 예시 '
    '"월요일 7교시" 15:00-15:50·다음 교시 16:00-16:50(' + SOURCE + ')에 따라 1교시 09:00부터 교시마다 '
    '60분 슬롯(50분 수업+10분)으로 계산했습니다. 9·10교시는 같은 슬롯 길이로 이어 계산했습니다(조회 2026-11-23). '
    '공식 교시표는 반대 근거가 없으면 학부 강좌 전체에 적용합니다(근거 없음은 반증이 아님, 호서대 사례).'
)
CYBER_NOTE = '"사"는 책자의 사이버(원격) 교시로 정해진 수업 시각이 없습니다.'
UNTIMED_NOTE = '원문 시간표에 요일·교시가 없습니다(별도 운영).'
DAYS = '월화수목금토일'
SEARCHED = [
    'https://www.bu.ac.kr/sites/web/files/sugang/2026_2/ 학부별 수업시간표 PDF 21개와 주요사항 책자',
    'https://www.bu.ac.kr/sites/web/intro/2026_1.html, 2025_2.html, 2025_1.html 학기별 수업시간표 PDF',
    'https://www.bu.ac.kr/sites/web/files/sugang/2026_1_new/ 신입생 학부별 안내책자 16개·수강신청 안내',
    'https://www.bu.ac.kr/pdfView/web/getDownload.do?pdfSeq=141 (규정집 전체·별표: 학칙·교무규정·원격교육 운영규정 등)',
    'https://www.bu.ac.kr/web/3446/subview.do 2026 요람(학사안내·주요학사제도·대학생활)',
    'https://www.bu.ac.kr/bbs/web/788/58632/artclView.do (2026-2 수업 운영 주요사항)',
    '2019~2025학기 주요사항 책자(sugang/<학기>/<학기>_juyo.pdf): 404',
    '공개 강의계획서: 포털 로그인 필요',
    'https://community.bu.ac.kr/<학부>/ 학부·학과·교양대학 게시판 24개 사이트의 제목 검색(시간표·교시)',
    'https://community.bu.ac.kr/bbs/{sports_sci/877,sports_sci/880,sports_sci/1849,emt/1187,health/928,health/929}/ '
    '게시판 목록·제목/본문 검색(집중·스킨·현장실습·응급), 스포츠과학부 학사안내·교과과정, 응급구조학과 실습안내·교과목 해설',
    'https://www.bu.ac.kr/sites/web/files/sugang/2025_1_hea.pdf, 2025_2_hea.pdf, 2026_1/2026_1_hea.pdf (이전 학기 응급구조학과 안내: 집중이수제 1-8주 더블수업)',
]
FIRST_START = 9 * 60
SLOT = 60


def period_start(n):
    return FIRST_START + SLOT * (n - 1)


def parse(schedule, classroom, remark):
    """원문을 (요일, [교시], 강의실) 목록으로. 해석할 수 없으면 None, 시각 없음이면 []."""
    s = schedule.strip()
    chunks = [c.strip() for c in s.split('/')] if s else []
    face = [c for c in chunks if c not in ('사', '-', '')]
    if not face:
        return []
    # 요일만 있고 비고에 같은 요일·교시가 적힌 경우(예: 수영 "화 5,6,7")
    if len(face) == 1 and face[0] in DAYS:
        m = re.search(face[0] + r'\s*(\d+(?:,\d+)*)', remark)
        if not m:
            return None
        face = [face[0] + m.group(1)]
    rooms = [r.strip() for r in classroom.split(',')] if classroom.strip() else ['']
    slots = [c for c in chunks if c not in ('사', '')]  # '-'는 '별도' 강의실 자리를 차지한다
    if len(rooms) == len(slots):
        room_of = dict(zip(range(len(slots)), rooms))
        face_rooms = [room_of[i] for i, c in enumerate(slots) if c != '-']
    elif len(rooms) == 1:
        face_rooms = rooms * len(face)
    else:
        face_rooms = [classroom.strip()] * len(face)
    out = []
    for chunk, room in zip(face, face_rooms):
        parts = re.findall(r'([월화수목금토일])\s*([\d,\s]*)', chunk)
        if not parts or re.sub(r'[월화수목금토일\d,\s]', '', chunk):
            return None
        for day, nums in parts:
            periods = [int(n) for n in re.findall(r'\d+', nums)]
            if not periods:
                return None
            out.append((DAYS.index(day) + 1, periods, room))
    return out


def meetings(parsed):
    rows = []
    for weekday, periods, room in parsed:
        for p in sorted(set(periods)):
            start = period_start(p)
            last = rows[-1] if rows else None
            # 같은 요일·강의실에서 간격 60분 미만이면 한 구간으로 합친다
            if last and last['weekday'] == weekday and last['classroom'] == room \
                    and start - last['endMinute'] < 60:
                last['endMinute'] = max(last['endMinute'], start + SLOT)
                last['sourcePeriodNumbers'].append(p)
                continue
            rows.append({'weekday': weekday, 'startMinute': start, 'endMinute': start + SLOT,
                         'classroom': room, 'sourcePeriodNumbers': [p]})
    return rows

# 교무처 「2026학년도 2학기 수업 주차 현황」(2026. 8. 25. 수정, 2026-2 수업 운영 주요사항 공지 첨부)
WEEK_SOURCE = 'https://www.bu.ac.kr/bbs/web/788/57347/download.do'
WEEK_NOTICE = 'https://www.bu.ac.kr/bbs/web/788/58632/artclView.do'
WEEK_GRID = {  # 요일 → 1~15주차 수업일(원문 그대로, 지정보강일은 실제 날짜)
    1: ['09-07', '09-14', '09-21', '09-28', '10-12', '10-19', '10-26', '11-02', '11-09',
        '11-16', '11-23', '11-30', '12-07', '12-14', '12-21'],
    2: ['09-01', '09-08', '09-15', '09-22', '09-29', '10-06', '10-13', '10-20', '10-27',
        '11-03', '11-10', '11-17', '11-24', '12-01', '12-15'],
    3: ['09-02', '09-09', '09-16', '09-23', '09-30', '10-07', '10-14', '10-21', '10-28',
        '11-04', '11-11', '11-18', '11-25', '12-02', '12-16'],
    4: ['09-03', '09-10', '09-17', '10-01', '10-08', '10-15', '10-22', '10-29', '11-05',
        '11-12', '11-19', '11-26', '12-03', '12-10', '12-17'],
    5: ['09-04', '09-11', '09-18', '10-02', '10-16', '10-23', '11-06', '11-13', '11-20',
        '11-27', '12-04', '12-08', '12-09', '12-11', '12-18'],
}
TERM = {'startDate': '2026-09-01', 'endDate': '2026-12-21'}  # 개강일 9.1.(화) ~ 종강일 12.21.(월)

# 교양 시간표 책자 「⑩ 집중이수제 적용 교과 안내」: AI와 대인관계 분반별 백석연수원 1박 2일(금10~13/토1,2교시)
AI_CAMP = {
    '01': '09-11', '02': '09-11', '03': '09-11', '04': '09-11', '08': '09-11',
    '05': '09-18', '11': '09-18', '20': '09-18', '17': '09-18',
    '19': '10-16', '18': '10-16', '12': '10-16', '13': '10-16',
    '22': '10-30', '23': '10-30', '09': '10-30', '10': '10-30',
}
AI_NOTE = (
    '수업 주차: 원문 비고 "13~15주차/백석연수원/집중이수"에 따라 교무처 「2026학년도 2학기 수업 주차 현황」'
    '(' + WEEK_SOURCE + ', 2026.8.25. 수정)의 해당 요일 13~15주차 날짜만 넣었습니다. 교양 책자의 수업기간 '
    '"26.12.03~12.17(3주)"은 목요일 분반에만 맞아 더 최근 공식 자료인 주차 현황을 따랐습니다. '
    '같은 책자 집중이수제 안내의 백석연수원 1박 2일(금10~13교시/토1,2교시)은 분반별 날짜로 넣었습니다'
    '(10.30.은 주차 현황상 휴업일이나 책자 일정 그대로, "일정은 사정에 의해 변경될 수 있음").'
)
OT3_CODES = {'09502', '32123', '31381', '31746'}
OT3_CHAPEL = {('03355', '24'), ('03355', '25')}
OT3_START, OT3_END = '2026-10-26', '2026-12-20'
OT3_NOTE = (
    '수업 주차: 보건학부 시간표 책자 작업치료학과 3학년 안내 "현장임상실습 이후 10월 26일부터 집중수업'
    '(8주간 15주차 수업)으로 운영됨"에 따라 2026.10.26.부터 8주간(~12.20.)의 수업 주차 현황 날짜만 넣었습니다'
    '(' + WEEK_SOURCE + ').'
)
EMT_CODES = {'09957', '08956'}
DAY_ONLY_NOTE = (
    '원문 시간표에 요일만 있고 교시가 비어 있습니다(강의실 "별도"). 학과 홈페이지 공지·게시판, 학사공지, '
    '수업 운영 주요사항·수업 주차 현황, 교양·학부 시간표 책자에도 수업 시각이 없어, 교시로 해석할 수 없는 '
    '표기는 시각을 만들지 않고 시간 미정으로 둔다는 규칙(광운대 사례)에 따라 시간 미정으로 둡니다(조회 2026-11-23).'
)
EMT_NOTE = (
    '보건학부 시간표 책자 응급구조학과 4학년 안내에 「종합응급처치실습2」와 「응급구조학각론」이 '
    '"집중이수제(1-5주, 1-8주 더블수업)"로 운영된다고 적혀 있으나 어느 과목이 어느 주차인지 정해져 있지 않아 '
    '수업 날짜를 정할 수 없어 원문 교시만 표시하고 시간표 추가를 보류합니다.'
)


def week_dates(weekday, weeks=None, start=None, end=None):
    out = []
    for i, md in enumerate(WEEK_GRID[weekday], 1):
        day = '2026-' + md
        if weeks and i not in weeks:
            continue
        if start and not (start <= day <= end):
            continue
        out.append(day)
    return out


def dated(rows, dates_for):
    out = []
    for r in rows:
        for day in dates_for(r['weekday']):
            out.append({'date': day, 'weekday': dt.date.fromisoformat(day).isoweekday(),
                        'startMinute': r['startMinute'], 'endMinute': r['endMinute'],
                        'classroom': r['classroom'], 'deliveryMode': 'inPerson',
                        'sourceWeekday': r['weekday'], 'sourcePeriodNumbers': r['sourcePeriodNumbers']})
    return sorted(out, key=lambda s: (s['date'], s['startMinute']))


def camp(md):
    fri = dt.date.fromisoformat('2026-' + md)
    sat = fri + dt.timedelta(days=1)
    return [
        {'date': fri.isoformat(), 'weekday': 5, 'startMinute': period_start(10),
         'endMinute': period_start(13) + SLOT, 'classroom': '백석연수원', 'deliveryMode': 'inPerson',
         'sourceWeekday': 5, 'sourcePeriodNumbers': [10, 11, 12, 13]},
        {'date': sat.isoformat(), 'weekday': 6, 'startMinute': period_start(1),
         'endMinute': period_start(2) + SLOT, 'classroom': '백석연수원', 'deliveryMode': 'inPerson',
         'sourceWeekday': 6, 'sourcePeriodNumbers': [1, 2]},
    ]


def week_limited(c, rows):
    """주차 제한이 있는 강좌: (일정, 비고) 또는 보류(None, 사유). 해당 없으면 False."""
    code, sec = c['courseCode'], c['section']
    remark = '\n'.join(c.get('departmentRemarks', {}).values())
    if code == '32065' and '13~15주차' in remark:
        meet = dated(rows, lambda w: week_dates(w, weeks={13, 14, 15}))
        if sec in AI_CAMP:
            meet = sorted(meet + camp(AI_CAMP[sec]), key=lambda s: (s['date'], s['startMinute']))
        return meet, AI_NOTE
    if code in OT3_CODES and re.search(r'작업치료학\s*3[ABC]|작업치료학과\s*3학년', remark) \
            or (code, sec) in OT3_CHAPEL:
        return dated(rows, lambda w: week_dates(w, start=OT3_START, end=OT3_END)), OT3_NOTE
    if code in EMT_CODES and '응급구조학과' in remark:
        return None, EMT_NOTE
    return False


def day_only(schedule):
    face = [x.strip() for x in schedule.split('/') if x.strip() not in ('사', '-', '')]
    return bool(face) and all(x in DAYS for x in face)


def strip_hold(remarks):
    out = {}
    for k, v in remarks.items():
        v = v.replace('\n' + HOLD, '').replace(HOLD, '').strip()
        if v:
            out[k] = v
    return out


def apply(data):
    for c in data['courses']:
        if 'scopedClockProof' in c or 'sourceClockProof' in c:
            continue
        remark_text = '\n'.join(c.get('departmentRemarks', {}).values())
        parsed = parse(c.get('sourceSchedule') or '', c.get('sourceClassroom') or '', remark_text)
        c['departmentRemarks'] = strip_hold(c.get('departmentRemarks', {}))
        has_cyber = '사' in [x.strip() for x in (c.get('sourceSchedule') or '').split('/')]
        if parsed is None and day_only(c.get('sourceSchedule') or ''):
            c['scheduleStatus'] = 'unscheduled'
            c['schedules'] = []
            c['remarks'] = DAY_ONLY_NOTE
        elif parsed is None:
            c['scheduleStatus'] = 'unrecognized'
            c['schedules'] = []
            c['remarks'] = '원문 시간표 표기를 교시로 해석할 수 없어 시각을 정할 수 없습니다.'
        elif not parsed:
            c['scheduleStatus'] = 'unscheduled'
            c['schedules'] = []
            c['remarks'] = CYBER_NOTE if has_cyber else UNTIMED_NOTE
        else:
            rows = meetings(parsed)
            limited = week_limited(c, rows)
            note = CLOCK_NOTE + (' ' + CYBER_NOTE if has_cyber else '')
            if limited is False:
                c['scheduleStatus'] = 'scheduled'
                c['schedules'] = rows
                c['remarks'] = note
            elif limited[0] is None:
                c['scheduleStatus'] = 'unrecognized'
                c['schedules'] = []
                c['remarks'] = limited[1]
            else:
                c['scheduleStatus'] = 'scheduled'
                c['schedules'] = limited[0]
                c['period'] = dict(TERM)
                c['remarks'] = note + ' ' + limited[1]
                continue
        c['period'] = None
    data['periodEvidence'] = {
        'periodTable': {
            'articleUrl': TABLE_URL, 'attachmentUrl': TABLE_FILE,
            'attachment': '26-1 자율실습 시간표.xlsx', 'sheet': 'Sheet1', 'cells': 'A4:A11',
            'sha256': 'edda0f19ba7ef34e83b0541fa7a0dc49be6f81519f3a6dd7a4eb056ebb75cd76',
            'literal': '1교시(9-10) 2교시(10-11) 3교시(11-12) 4교시(12-13) 5교시(13-14) 6교시(14-15) 7교시(15-16) 8교시(16-17)',
            'note': '본문: 각 자율실습 시간은 정각-50분까지',
        },
        'sourceUrl': SOURCE, 'pdfPage': 43, 'printedPage': 38, 'checkedAt': '2026-11-23',
        'literal': '대면수업 월요일 7교시 / 강의시간 15:00-15:50, 16:00-16:50',
        'rule': '1교시 09:00 시작, 교시마다 60분 슬롯(50분 수업+10분)',
        'scope': '계약학과 자체 시각(scopedClockProof)·직접 시각(sourceClockProof) 강좌 제외',
        'basis': '공식 교시표는 반대 근거가 없으면 전체 적용, 근거 없음은 반증이 아님(DailyCalendar-Timetable 스킬 5장, 호서대 사례); 9·10교시는 같은 60분 슬롯',
    }
    data['periodSearch'] = {
        'checkedAt': '2026-11-23',
        'result': '학칙·규정·책자에는 교시 시각표 없음; 간호학과 공지 첨부 교시표(1~8교시)에서 찾음',
        'searched': SEARCHED,
    }
    return data


def self_check():
    assert parse('목5,6', '음악208', '') == [(4, [5, 6], '음악208')]
    assert meetings(parse('목5,6', '음악208', ''))[0]['startMinute'] == 13 * 60
    assert meetings(parse('월7', 'x', ''))[0]['endMinute'] == 16 * 60
    assert parse('사', '', '') == [] and parse('-', '별도', '') == []
    assert parse('금', '별도', '') is None and day_only('금') and not day_only('금1')
    assert parse('화', '별도', '수영 화 5,6,7') == [(2, [5, 6, 7], '별도')]
    assert parse('-/ 목2,3', '별도, 진리301', '') == [(4, [2, 3], '진리301')]
    assert [r['classroom'] for r in meetings(parse('수1,2/ 수3,4', 'a, b', ''))] == ['a', 'b']
    assert len(meetings(parse('월8,9, 화5,6', '조형210', ''))) == 2
    assert parse('사/ 수2,3/ 수4', '조형401, 조형404', '') == [(3, [2, 3], '조형401'), (3, [4], '조형404')]
    assert week_dates(1, weeks={13, 14, 15}) == ['2026-12-07', '2026-12-14', '2026-12-21']
    assert week_dates(4, weeks={13, 14, 15}) == ['2026-12-03', '2026-12-10', '2026-12-17']
    assert week_dates(2, start=OT3_START, end=OT3_END)[0] == '2026-10-27'
    assert len(week_dates(1, start=OT3_START, end=OT3_END)) == 8
    assert all(len(v) == 15 for v in WEEK_GRID.values())
    assert [s['startMinute'] for s in camp('09-11')] == [18 * 60, 9 * 60]
    ai = {'courseCode': '32065', 'section': '01', 'departmentRemarks': {'교양': '13~15주차'}}
    got, _ = week_limited(ai, meetings(parse('화2,3', '진리511', '')))
    assert [s['date'] for s in got] == ['2026-09-11', '2026-09-12', '2026-11-24', '2026-12-01', '2026-12-15']


if __name__ == '__main__':
    self_check()
    data = json.loads(ASSET.read_text(encoding='utf-8'))
    apply(data)
    ASSET.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    counts = {}
    for c in data['courses']:
        counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
    print(json.dumps(counts, ensure_ascii=False))
    sys.exit(0)
