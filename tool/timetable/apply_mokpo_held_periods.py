#!/usr/bin/env python3
"""국립목포대 2026-2: 운영 방식 검토로 보류한 강좌를 공식 교시로 정규 예약한다.

2026-11-23 사용자 결정: 공식 요일·교시가 있으면 운영 방식(실습·집중·원격 등)이
불명확해도 대면 수업으로 보고 그 교시로 확정한다. 표에 없는 교시는 같은 슬롯
길이로 이어 계산한다.

교시표: https://www.mokpo.ac.kr/www/242/subview.do (수업시간표, 1교시 09:00~09:30 …
18교시 17:30~18:00, 30분 단위). 19교시 이후는 같은 30분으로 이어 계산한다
(19교시 18:00). 기존 정규 예약도 같은 규칙이다(실행 때 대조).
날짜: 기존 정규 예약과 같은 9/1~12/7 매주, 공휴일·개교기념일 9/24·9/25·9/26·
10/3·10/5·10/9·10/31 제외.
원문 강의실은 그대로 쓴다.
3차(2026-11-23 사용자 결정): 공식 시간표(UNCO04)·강의계획서·편성표에 요일·교시가 모두 빈 강좌는
다른 공개 자료(학과·단과대 공지, 편람)에서도 시각을 찾지 못해 시간 미정(unscheduled)으로 둔다.
이미 scheduled인 강좌는 건드리지 않고, 재실행해도 바뀌지 않는다.

    python3 tool/timetable/apply_mokpo_held_periods.py
"""
import datetime
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATHS = [ROOT / f'assets/timetable/mokpo-{c}-2026-2.json' for c in ('damyang', 'dorim', 'unknown')]
DAYS = '월화수목금토일'
FIRST_START, SLOT = 540, 30  # 1교시 09:00, 30분 교시
START, END = '2026-09-01', '2026-12-07'
CLOSED = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09',
          '2026-10-31'}
REVIEW = '운영 검토:'
NOTE = '운영 검토: 공식 요일·교시로 정규 예약했습니다(운영 방식 세부는 판단하지 않음).'


def dates(weekday):
    d = datetime.date.fromisoformat(START)
    d += datetime.timedelta(days=(weekday - d.isoweekday()) % 7)
    out = []
    while d.isoformat() <= END:
        if d.isoformat() not in CLOSED:
            out.append(d.isoformat())
        d += datetime.timedelta(days=7)
    return out


def blocks(raw):
    """'월10,11,12 수13,14,15' -> [(요일, 시작, 끝)]. 다른 표기가 섞이면 None."""
    raw = (raw or '').strip()
    if not raw:
        return None
    periods = {}
    for part in raw.split(' '):
        m = re.fullmatch(r'([월화수목금토일])(\d+(?:,\d+)*)', part)
        if not m:
            return None
        periods.setdefault(DAYS.index(m[1]) + 1, set()).update(int(p) for p in m[2].split(','))
    out = []
    for w, ps in sorted(periods.items()):
        for p in sorted(ps):
            start = FIRST_START + SLOT * (p - 1)
            if out and out[-1][0] == w and start - out[-1][2] < 60:
                out[-1] = (w, out[-1][1], start + SLOT)
            else:
                out.append((w, start, start + SLOT))
    return out


def meetings(segs, room):
    rows = [{'weekday': w, 'startMinute': s, 'endMinute': e, 'date': d, 'classroom': room}
            for w, s, e in segs for d in dates(w)]
    return sorted(rows, key=lambda r: (r['date'], r['startMinute']))


def _note(text):
    lines = [line for line in text.split('\n') if not line.startswith(REVIEW)]
    return '\n'.join(lines + [NOTE]) if REVIEW in text else text


def apply(data):
    changed = []
    for c in data['courses']:
        if c['scheduleStatus'] != 'unrecognized':
            continue
        segs = blocks(c['sourceSchedule'])
        if not segs:
            continue
        c['schedules'] = meetings(segs, c['sourceClassroom'])
        c['scheduleStatus'] = 'scheduled'
        c['period'] = {'startDate': START, 'endDate': END}
        c['departmentRemarks'] = {k: _note(v) for k, v in c['departmentRemarks'].items()}
        changed.append(c['sourceId'])
    return changed


def check_existing(datasets):
    """기존 정규 예약이 같은 교시·날짜 규칙인지 대조한다.

    별도 날짜 강좌(기간이 다른 1건)와 개별 휴강일을 뺀 강좌(규칙의 부분집합)는 제외한다.
    """
    checked = 0
    for data in datasets:
        for c in data['courses']:
            if c['scheduleStatus'] == 'scheduled' and c['period'] == {'startDate': START, 'endDate': END}:
                schedule, room, _ = SUPPLEMENT.get((c['courseCode'], c['section']),
                                                   (c['sourceSchedule'], c['sourceClassroom'], ''))
                rule = meetings(blocks(schedule), room)
                assert rule == c['schedules'] or all(s in rule for s in c['schedules']), c['sourceId']
                checked += rule == c['schedules']
    return checked


# 공개 UNCO04 학부 시간표(https://mnuhs.mokpo.ac.kr:7775/mnuq/?P=UNCO&ID=UNCO04, 2026-11-23 조회)
# 원문 그대로. 교양학부(893) 교양필수 2학점 학부 강좌인데 기록된 사유 없이 빠져 있었다.
ZAA006 = [  # (분반, 교수, 시간, 강의실)
    ('01', '강형구(교양)', '화5,6,7,8', '인문대학 141'),
    ('02', '강지영(교양)', '화5,6,7,8', '인문대학 142'),
    ('03', '박성현(도서)', '화5,6,7,8', '사회과학대학/경영대학 1101'),
    ('04', '이고은(교양)', '화5,6,7,8', '인문대학 341'),
    ('05', '홍은영(교양)', '화5,6,7,8', '자연과학대학1호관 1101'),
    ('06', '송기태(도서)', '화5,6,7,8', '사회과학대학/경영대학 1109'),
    ('07', '김경옥(도서)', '화5,6,7,8', '사회과학대학/경영대학 2101'),
    ('08', '홍선기(도서)', '화5,6,7,8', '사회과학대학/경영대학 3106'),
    ('09', '이용우(교양)', '수13,14,15,16', '(담양)제5학관 강당 5110'),
]
# 기존 데이터의 강의실 건물별 캠퍼스 배정과 같다(각 건물이 한 파일에만 있음).
CAMPUS_BY_ROOM = (('(담양)', 'damyang'), ('인문대학', 'dorim'),
                  ('사회과학대학/경영대학', 'unknown'), ('자연과학대학1호관', 'unknown'))
# 같은 강좌(이름·교수·시각·강의실 동일)의 학수번호가 최신 공개 조회에서 바뀌었다.
RENAMED = {'KG631': 'KG721'}
# 최신 공개 조회(2026-11-23)에서 담당교수 표기만 바뀐 강좌. 일정·강의실은 그대로다.
PROFESSORS = {('FNN030', '00'): '강혜연(식품)', ('ZBC013', '00'): '유상미(행정)',
              ('ALM048', '00'): '조정현(), 이효빈()'}


def restore_source_rows(datasets):
    by_campus = {d['campus']: d for d in datasets}
    have = {(c['courseCode'], c['section']) for d in datasets for c in d['courses']}
    added = []
    for section, professor, schedule, room in ZAA006:
        if ('ZAA006', section) in have:
            continue
        campus = next(v for k, v in CAMPUS_BY_ROOM if room.startswith(k))
        courses = by_campus[campus]['courses']
        course = {'sourceId': f'mokpo/{campus}/2026/2/ZAA006/{section}', 'sourceDepartmentCode': '893',
                  'sourceClassificationCode': '0010', 'campus': campus, 'academicYear': 2026,
                  'semester': '2', 'courseCode': 'ZAA006', 'courseName': '프론티어정신',
                  'section': section, 'professor': professor, 'credits': 2.0,
                  'departmentCredits': {'교양학부': 2.0}, 'departments': ['교양학부'],
                  'departmentClassifications': {'교양학부': '교양필수'},
                  'departmentRemarks': {'교양학부': '원 이수구분: 0010 교양필수. '},
                  'sourceSchedule': schedule, 'sourceClassroom': room,
                  'scheduleStatus': 'unrecognized', 'schedules': []}
        last = max(i for i, c in enumerate(courses) if c['sourceDepartmentCode'] == '893')
        courses.insert(last + 1, course)
        added.append(course['sourceId'])
    for d in datasets:
        for c in d['courses']:
            new = RENAMED.get(c['courseCode'])
            if new:
                c['courseCode'] = new
                c['sourceId'] = f"mokpo/{c['campus']}/2026/2/{new}/{c['section']}"
                added.append(c['sourceId'])
            professor = PROFESSORS.get((c['courseCode'], c['section']))
            if professor and c['professor'] != professor:
                c['professor'] = professor
                added.append(c['sourceId'])
    return added


# 2차 재검토(2026-11-23): UNCO04 시간 칸이 빈 강좌를 교무과 학사공지 "2026학년도 2학기
# 수강신청 안내"(https://www.mokpo.ac.kr/bbs/www/149/173061/artclView.do) 첨부
# "2026학년도 제2학기 수업시간표 편성표(수정).xlsx"에서 찾았다. 시각이 적힌 것만 쓴다.
# 같은 편성표의 OCU·글로벌한국학 시트는 강의시간이 비었고, ZBD008·ZBE132는 "원격수업 예정",
# ZZA006은 "실제 수업 이루어지지 않음", CA926은 "-"라 그대로 둔다.
SUPPLEMENT = {  # (학수번호, 분반): (편성표 강의시간을 UNCO 표기로, 편성표 강의실, 근거)
    ('ZZA002', '00'): ('금13,14,15,16,17,18', '미정',
                       '학생지원과 시트 "금 13~18교시", 강의실 "미정"'),
}
SUPPLEMENT_NOTE = ('시각 근거: 교무과 2026학년도 제2학기 수업시간표 편성표(수정) {}. '
                   'UNCO04 시간 칸은 비어 있습니다.')


def apply_supplement(data):
    changed = []
    for c in data['courses']:
        found = SUPPLEMENT.get((c['courseCode'], c['section']))
        if c['scheduleStatus'] != 'unrecognized' or not found:
            continue
        schedule, room, why = found
        c['schedules'] = meetings(blocks(schedule), room)
        c['scheduleStatus'] = 'scheduled'
        c['period'] = {'startDate': START, 'endDate': END}
        note = SUPPLEMENT_NOTE.format(why)
        c['departmentRemarks'] = {
            k: '\n'.join([line for line in v.split('\n') if not line.startswith(REVIEW)] + [note])
            for k, v in c['departmentRemarks'].items()}
        changed.append(c['sourceId'])
    return changed


UNTIMED_NOTE = '운영 검토: 공식 시간표·강의계획서·편성표에 요일·교시가 없어 시간 미정으로 둡니다(2026-11-23 사용자 결정).'


def apply_untimed(data):
    changed = []
    for c in data['courses']:
        if c['scheduleStatus'] != 'unrecognized' or (c['sourceSchedule'] or '').strip():
            continue
        c['scheduleStatus'] = 'unscheduled'
        c['departmentRemarks'] = {
            k: '\n'.join([line for line in v.split('\n') if not line.startswith(REVIEW)] + [UNTIMED_NOTE])
            for k, v in c['departmentRemarks'].items()}
        changed.append(c['sourceId'])
    return changed


def main():
    raws = [p.read_text(encoding='utf-8') for p in PATHS]
    datasets = [json.loads(r) for r in raws]
    checked = check_existing(datasets)
    restored = restore_source_rows(datasets)
    changed = [sid for d in datasets for sid in apply_supplement(d) + apply(d) + apply_untimed(d)]
    for path, raw, data in zip(PATHS, raws, datasets):
        out = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
        if out != raw:
            path.write_text(out, encoding='utf-8')
    print('existing rule checked', checked, 'restored', len(restored), 'confirmed', len(changed))


if __name__ == '__main__':
    main()
