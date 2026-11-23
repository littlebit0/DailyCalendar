#!/usr/bin/env python3
"""백석대 2026-2 학부 강좌의 교시 원문을 교시 시각으로 확정하고 시간 미정 강좌를 정리한다.

근거: 교무처 「2026학년도 제2학기 수업시간표」 주요사항 책자
(https://www.bu.ac.kr/sites/web/files/sugang/2026_2/2026_2_juyo.pdf, PDF 43쪽, 인쇄 38쪽,
C-4 원격교육 운영안내 ⑦ 출석정보 확인방법) 의 대면수업 예시
"월요일 7교시" 강의시간 15:00-15:50, 다음 교시 16:00-16:50.
같은 60분 슬롯(50분 수업 + 10분)으로 1교시 09:00부터 이어 계산한다.
「원격교육 운영규정」 제5조 ③(1시간 = 50분)과 같은 길이다.

계약학과 자체 시각(scopedClockProof)·기존 직접 시각(sourceClockProof) 강좌는 건드리지 않는다.
원문 필드(sourceSchedule, sourceClassroom 등)는 바꾸지 않는다. 다시 실행해도 결과가 같다.
"""
import json
import re
import sys
from pathlib import Path

ASSET = Path(__file__).resolve().parents[2] / 'assets/timetable/baekseok-unknown-2026-2.json'
HOLD = '학교 전체 교시 시각과 개별 운영·변경 사항을 검증하기 전으로 시간표 자동 추가를 보류합니다.'
SOURCE = 'https://www.bu.ac.kr/sites/web/files/sugang/2026_2/2026_2_juyo.pdf'
CLOCK_NOTE = (
    '교시 시각: 교무처 2026-2학기 수업시간표 주요사항 책자 38쪽(PDF 43쪽) 대면수업 예시 '
    '"월요일 7교시" 15:00-15:50·다음 교시 16:00-16:50과 같은 60분 슬롯(50분 수업+10분)으로 '
    '1교시 09:00부터 이어 계산했습니다(' + SOURCE + ', 조회 2026-11-23). '
    '학부 교시표가 따로 공개되지 않아, 공식 근거가 없다는 것은 반증이 아니라는 원칙(호서대 교시표 적용 사례와 같음)에 따라 '
    '학부 강좌 전체에 적용했습니다.'
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
        if parsed is None:
            c['scheduleStatus'] = 'unrecognized'
            c['schedules'] = []
            c['remarks'] = '원문 시간표에 요일만 있고 교시가 없어 시각을 정할 수 없습니다.'
        elif not parsed:
            c['scheduleStatus'] = 'unscheduled'
            c['schedules'] = []
            c['remarks'] = CYBER_NOTE if has_cyber else UNTIMED_NOTE
        else:
            c['scheduleStatus'] = 'scheduled'
            c['schedules'] = meetings(parsed)
            c['remarks'] = CLOCK_NOTE + (' ' + CYBER_NOTE if has_cyber else '')
    data['periodEvidence'] = {
        'sourceUrl': SOURCE, 'pdfPage': 43, 'printedPage': 38, 'checkedAt': '2026-11-23',
        'literal': '대면수업 월요일 7교시 / 강의시간 15:00-15:50, 16:00-16:50',
        'rule': '1교시 09:00 시작, 교시마다 60분 슬롯(50분 수업+10분)',
        'scope': '계약학과 자체 시각(scopedClockProof)·직접 시각(sourceClockProof) 강좌 제외',
        'basis': '근거 없음은 반증이 아님(DailyCalendar-Timetable 스킬 5장, 호서대 교시표 전체 적용 사례)',
    }
    data['periodSearch'] = {
        'checkedAt': '2026-11-23',
        'result': '학부 교시별 시각표 문서는 찾지 못함',
        'searched': SEARCHED,
    }
    return data


def self_check():
    assert parse('목5,6', '음악208', '') == [(4, [5, 6], '음악208')]
    assert meetings(parse('목5,6', '음악208', ''))[0]['startMinute'] == 13 * 60
    assert meetings(parse('월7', 'x', ''))[0]['endMinute'] == 16 * 60
    assert parse('사', '', '') == [] and parse('-', '별도', '') == []
    assert parse('금', '별도', '') is None
    assert parse('화', '별도', '수영 화 5,6,7') == [(2, [5, 6, 7], '별도')]
    assert parse('-/ 목2,3', '별도, 진리301', '') == [(4, [2, 3], '진리301')]
    assert [r['classroom'] for r in meetings(parse('수1,2/ 수3,4', 'a, b', ''))] == ['a', 'b']
    assert len(meetings(parse('월8,9, 화5,6', '조형210', ''))) == 2
    assert parse('사/ 수2,3/ 수4', '조형401, 조형404', '') == [(3, [2, 3], '조형401'), (3, [4], '조형404')]


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
