#!/usr/bin/env python3
"""백석대 2026-2 강좌의 시간표 상태를 원문 표기대로 정리한다.

- 원문에 요일·교시가 있으면 unrecognized(원문 교시만 표시). 학부 공식 교시 시각표
  (학칙·학사안내·학과 공지 교시표)를 찾지 못해 시각을 만들지 않는다.
- 요일·교시가 없는 사이버("사")·별도("-")·빈 칸 강좌는 unscheduled(시간 미정).
- 요일만 있고 교시가 없는 강좌는 unrecognized.

계약학과 자체 시각(scopedClockProof)·기존 직접 시각(sourceClockProof) 강좌는 건드리지 않는다.
원문 필드(sourceSchedule, sourceClassroom 등)는 바꾸지 않는다. 다시 실행해도 결과가 같다.
"""
import json
from pathlib import Path

ASSET = Path(__file__).resolve().parents[2] / 'assets/timetable/baekseok-unknown-2026-2.json'
HOLD = '학교 전체 교시 시각과 개별 운영·변경 사항을 검증하기 전으로 시간표 자동 추가를 보류합니다.'
DAYS = '월화수목금토일'
PERIOD_HOLD = ('학부 교시별 시작·종료 시각을 공개한 공식 교시표를 찾지 못해 원문 교시만 표시하고 '
               '시간표 추가를 보류합니다.')
DAY_ONLY = '원문 시간표에 요일만 있고 교시가 없어 시각을 정할 수 없습니다.'
CYBER_NOTE = '"사"는 수업시간표 책자의 사이버(원격) 교시로 정해진 수업 시각이 없습니다.'
UNTIMED_NOTE = '원문 시간표에 요일·교시가 없습니다(별도 운영).'
SEARCHED = [
    'https://www.bu.ac.kr/sites/web/files/sugang/2026_2/ 학부별 수업시간표 PDF 21개와 주요사항 책자',
    'https://www.bu.ac.kr/sites/web/files/sugang/2026_1/2026_1_juyo.pdf',
    'https://www.bu.ac.kr/sites/web/files/sugang/2026_1_new/ 신입생 학부별 안내책자 16개·수강신청 안내',
    'https://www.bu.ac.kr/pdfView/web/getDownload.do?pdfSeq=141 (규정집: 학칙·교무규정·원격교육 운영규정)',
    'https://www.bu.ac.kr/web/3446/subview.do 2026 요람(학사안내·주요학사제도·대학생활)',
    'https://www.bu.ac.kr/bbs/web/788/58632/artclView.do (2026-2 수업 운영 주요사항)',
    '2019~2025학기 수업시간표 책자(sugang/<학기>/<학기>_juyo.pdf): 404',
    '공개 강의계획서: 포털 로그인 필요',
]


def classify(schedule):
    chunks = [c.strip() for c in schedule.strip().split('/')] if schedule.strip() else []
    face = [c for c in chunks if c not in ('사', '-', '')]
    if not face:
        return 'unscheduled'
    if all(c in DAYS for c in face):
        return 'dayOnly'
    return 'periods'


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
        schedule = c.get('sourceSchedule') or ''
        kind = classify(schedule)
        has_cyber = '사' in [x.strip() for x in schedule.split('/')]
        c['departmentRemarks'] = strip_hold(c.get('departmentRemarks', {}))
        c['schedules'] = []
        if kind == 'unscheduled':
            c['scheduleStatus'] = 'unscheduled'
            c['remarks'] = CYBER_NOTE if has_cyber else UNTIMED_NOTE
        else:
            c['scheduleStatus'] = 'unrecognized'
            c['remarks'] = DAY_ONLY if kind == 'dayOnly' else PERIOD_HOLD
    data.pop('periodEvidence', None)
    data['periodSearch'] = {
        'checkedAt': '2026-11-23',
        'result': '학부 공식 교시 시각표 없음',
        'searched': SEARCHED,
    }
    return data


def self_check():
    assert classify('목5,6') == 'periods'
    assert classify('사/ 화4') == 'periods'
    assert classify('-/ 목2,3') == 'periods'
    assert classify('사') == classify('-') == classify('') == 'unscheduled'
    assert classify('화') == 'dayOnly'


if __name__ == '__main__':
    self_check()
    data = json.loads(ASSET.read_text(encoding='utf-8'))
    apply(data)
    ASSET.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    counts = {}
    for c in data['courses']:
        counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
    print(json.dumps(counts, ensure_ascii=False))
