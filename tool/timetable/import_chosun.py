#!/usr/bin/env python3
"""조선대 공개 개설교과목 조회(a.chosun.ac.kr, 비로그인) 응답을 시간표 자산으로 바꾼다.

입력: 개설강좌 행 JSON(연락처 열 제거본)과 같은 화면의 코드표 응답(selectInitData).
원문이 적은 요일·시각·강의실·소속만 쓰고, 검색 활성화는 하지 않는다.
"""
import argparse
import json
import re
from pathlib import Path

DAYS = {d: i + 1 for i, d in enumerate('월화수목금토일')}
SLOT = re.compile(r'^([월화수목금토일]) (\d+[AB])~(\d+[AB])\((\d\d):(\d\d)~(\d\d):(\d\d)\)$')
HELD_MODES = {'비대면', '블렌디드'}
HELD_KINDS = {'02', '03', '04', '35'}  # 현장실습·산업체현장실습·사회봉사·임상실습
SOURCE_URL = 'https://a.chosun.ac.kr/S/sugang/gaeseol'


def code_tables(path):
    tables, name, header = {}, None, None
    for line in Path(path).read_text(encoding='utf-8').split('\n'):
        if line.startswith('@d#'):
            name, header = line[3:], None
            continue
        if name is None or not line.strip():
            continue
        if header is None:
            header = line.split('\t')
            continue
        row = dict(zip(header, line.split('\t')))
        tables.setdefault(name, {})[row['CODE']] = row['CD_NM']
    return tables


def meetings_for(row):
    slots = [s.strip() for s in row['GANGUI_TIME_NM'].split(',')]
    rooms = [r.strip() for r in row['GANGUISIL_NM'].strip().split(', ')]  # 강의실 이름 안에 쉼표가 있어 ', '로 나눈다
    if len(rooms) != len(slots):
        raise ValueError(f"강의실 수와 시간 수가 다름: {row['GWAMOK_CD']}-{row['BUNBAN']}")
    meetings = []
    for slot, room in zip(slots, rooms):
        m = SLOT.match(slot)
        if not m:
            raise ValueError(f'알 수 없는 시간 표기: {slot}')
        start = int(m[4]) * 60 + int(m[5])
        end = int(m[6]) * 60 + int(m[7])
        if not 0 <= start < end <= 1440:
            raise ValueError(f'잘못된 시각: {slot}')
        meetings.append({'weekday': DAYS[m[1]], 'startMinute': start,
                         'endMinute': end, 'classroom': room})
    return meetings


def hold_reasons(row, kinds):
    reasons = []
    mode = row['SUEOP_BANGSIK_NM']
    if mode in HELD_MODES:
        reasons.append(f'원문 수업방식 {mode}: 공식 요일·교시를 확정 시각으로 볼지 판단 대기')
    elif row['CYBER_GANGUI_GB'] == '1' or '사이버강좌' in row['GANGUISIL_NM']:
        reasons.append('원문 사이버강좌 구분: 공식 요일·교시를 확정 시각으로 볼지 판단 대기')
    if row['GANGUI_GB'] in HELD_KINDS:
        reasons.append(f"원문 강의구분 {kinds[row['GANGUI_GB']]}: 실제 운영 기간·시각 미확인")
    return reasons


def course_for(row, isu, kinds):
    label = row['HAKGWA_NM'].strip()
    classification = isu[row['ISU_GB']]
    credits = float(row['HAKJEOM'])
    meetings = meetings_for(row)
    reasons = hold_reasons(row, kinds)
    notes = []
    if row['GANGUI_GB']:
        notes.append(f"강의구분 {kinds[row['GANGUI_GB']]}")
    if row['SUEOP_BANGSIK_NM']:
        notes.append(f"수업방식 {row['SUEOP_BANGSIK_NM']}")
    if row['WONEO_GANGJWA_NM']:
        notes.append(f"원어강좌 {row['WONEO_GANGJWA_NM']}")
    if row['TEAM_GYOSU_NM_HAKSAENGYONG']:
        notes.append(f"팀티칭 {row['TEAM_GYOSU_NM_HAKSAENGYONG']}")
    if row['SUGANG_HAKGWA_ISU_GB']:
        notes.append(f"수강가능학과 {row['SUGANG_HAKGWA_ISU_GB']}")
    if row['BIGO'].strip():
        notes.append(f"비고 {row['BIGO'].strip()}")
    if reasons:
        notes.append('시각 보류: ' + ' / '.join(reasons))
    course = {
        'sourceId': f"chosun/unknown/2026/2/{row['GWAMOK_CD']}/{row['BUNBAN']}",
        'campus': 'unknown',
        'academicYear': 2026,
        'semester': '2',
        'courseCode': row['GWAMOK_CD'],
        'section': row['BUNBAN'],
        'courseName': row['GWAMOK_NM'],
        'professor': row['GYOSU_NM'],
        'credits': credits,
        'classification': classification,
        'departments': [label],
        'departmentCredits': {label: credits},
        'departmentClassifications': {label: classification},
        'departmentRemarks': {label: ' | '.join(notes)},
        'sourceSchedule': row['GANGUI_TIME_NM'],
        'sourceClassroom': row['GANGUISIL_NM'].strip(),
        'scheduleStatus': 'unrecognized' if reasons else 'scheduled',
        'schedules': [] if reasons else meetings,
    }
    if reasons:
        course['holdReasons'] = reasons
    return course


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('rows')
    parser.add_argument('codes')
    parser.add_argument('output')
    args = parser.parse_args()
    data = json.loads(Path(args.rows).read_text(encoding='utf-8'))
    tables = code_tables(args.codes)
    isu, kinds = tables['ds_out01'], tables['ds_out']
    rows = data['rows']
    if any((r['YEAR'], r['HAKGI_GB'], r['CORS_GB']) != ('2026', '21', '1') for r in rows):
        raise ValueError('2026학년도 2학기 학부 행이 아님')
    open_rows = [r for r in rows if r['PYEGANG_YN'] != '폐강']
    courses = [course_for(r, isu, kinds) for r in open_rows]
    if len({c['sourceId'] for c in courses}) != len(courses):
        raise ValueError('과목코드·분반 중복')
    status = {}
    for c in courses:
        status[c['scheduleStatus']] = status.get(c['scheduleStatus'], 0) + 1
    dataset = {
        'schemaVersion': 1,
        'universityId': 'chosun',
        'institutionId': 'institution:academyinfo:0000172',
        'campus': 'unknown',
        'campusName': '캠퍼스 미확인',
        'academicYear': 2026,
        'semester': '2',
        'publishedDate': data['fetched'],
        'retrievedDate': data['fetched'],
        'sourceUrl': SOURCE_URL,
        'sourceNotice': ('조선대학교 개설교과목조회 공개 화면(로그인 없음, 2026학년도 2학기 학부, 개설·폐강 전체) '
                         f"조회 결과 {len(rows)}행 중 폐강 {len(rows) - len(open_rows)}행을 뺀 개설 {len(open_rows)}강좌. "
                         'robots.txt가 막은 경로를 사용자 결정에 따라 직접 조회. 캠퍼스 구분은 원문에 없음.'),
        'sourceRowCount': len(rows),
        'closedRowCount': len(rows) - len(open_rows),
        'courseScheduleStatusCounts': status,
        'completionClaim': False,
        'courses': courses,
    }
    Path(args.output).write_text(json.dumps(dataset, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(len(rows), len(open_rows), status)


if __name__ == '__main__':
    main()
