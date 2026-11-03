# coding: utf-8
"""Five corroborated current accounting blocks; retain all search metadata."""
import hashlib
import json
import re
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).parent
APPROVED = {'10642', '10645', '10647', '10651', '12799'}
DAY = dict(zip('월화수목금토일', range(1, 8)))
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-09-27', '2026-10-03', '2026-10-05', '2026-10-09'}
EXAM = set((date(2026, 10, 19) + timedelta(days=i)).isoformat() for i in range(5))


def main():
    source_path = ROOT / 'sch-2026-2-educational-operating-review-20261008.json'
    source = json.loads(source_path.read_text())
    proof = json.loads((ROOT / 'sch-current-accounting-clock-operating-review-20261008.json').read_text())
    matches = {r['CORS_NO'] for r in proof['courses'] if r['departmentImageComparison'] == 'matching-current-AB-blocks'}
    assert matches == APPROVED
    courses = []
    for raw in source['publicCourseMetadata']:
        dept = raw['OPEN_ORGN_NM'] or ''
        classification = raw['CORS_ST_DIV_NM'] or ''
        credits = float(raw['CDT']) if raw['CDT'] is not None else None
        notes = [note['text'] for note in raw.get('educationalOperatingNotes', [])]
        eligible = raw['CORS_NO'] in APPROVED
        blocks = []
        if eligible:
            assert dept == '회계학과' and raw['TM_CNT'] == '3' and credits == 3
            for part in raw['DAY_TM_NM'].split('/'):
                m = re.fullmatch(r'([월화수목금])([1-9][AB])-([1-9][AB])', part)
                assert m
                day, first, last = m.groups()
                start = 540 + (int(first[0]) - 1) * 60 + (30 if first[1] == 'B' else 0)
                grid_end = 540 + (int(last[0]) - 1) * 60 + (60 if last[1] == 'B' else 30)
                assert grid_end - start == 90
                blocks.append({'weekday': DAY[day], 'startMinute': start, 'endMinute': start + 75, 'classroom': raw['LECT_ROOM_NM'] or ''})
            notes += ['회계학과 현재학기 전 과목 대면 원칙(2026-08-11 공지)', '3시간 전공 75분제: 현재 공개목록 최신 학부 요람(2023)의 명시 규칙과 2026-2 동일 A/B 시작 교시·강좌·강의실 대조. 접촉75분/예약표90분을 구분; 공통 표시30분 반올림 적용.', '원표 일반수업만 적용; 중간평가·기말평가·보강주간의 개별 확정 시각을 생성하지 않음. 개별 강의계획 추가 비고는 미확인.']
            if raw['CORS_NO'] == '10645':
                notes.append('재무관리1 → 재무관리2; 담당교수 상담으로 선이수 없이 수강 가능(현재 회계학과 공지)')
        meetings = []
        current = date(2026, 8, 31)
        while eligible and current <= date(2026, 12, 6):
            day = current.isoformat()
            if day not in HOLIDAYS and day not in EXAM:
                meetings += [dict(b, date=day) for b in blocks if b['weekday'] == current.isoweekday()]
            current += timedelta(days=1)
        course = {'sourceId': 'sch/unknown/2026/2/' + raw['CORS_NO'] + '-' + raw['CLS_NO'],
                  'campus': 'unknown', 'academicYear': 2026, 'semester': '2',
                  'courseCode': raw['CORS_NO'], 'section': raw['CLS_NO'],
                  'courseName': raw['SBJT_KOR_NM'], 'professor': raw['EMP_NM'] or '',
                  'credits': credits, 'departments': [dept] if dept else [],
                  'classification': classification,
                  'departmentCredits': {dept: credits} if dept and credits is not None else {},
                  'departmentClassifications': {dept: classification} if dept else {},
                  'departmentRemarks': {dept: '\n'.join(notes)} if dept else {},
                  'sourceSchedule': raw['DAY_TM_NM'] or '', 'sourceClassroom': raw['LECT_ROOM_NM'] or '',
                  'sourceSubjectId': raw['SBJT_ID'], 'sourceAcademicNumber': raw['CORS_NO'],
                  'sourceOpeningYear': raw['OPEN_SHYR'], 'sourceClassification': classification,
                  'sourceEducationalMetadata': raw,
                  'period': {'startDate': '2026-08-31', 'endDate': '2026-12-06'},
                  'scheduleStatus': 'scheduled' if meetings else 'unrecognized', 'schedules': meetings}
        courses.append(course)
    assert len(courses) == len({c['sourceId'] for c in courses}) == 2598
    assert sum(bool(c['schedules']) for c in courses) == 5
    target = ROOT / 'sch-unknown-2026-2.accounting-five-candidate.json'
    dataset = {'schemaVersion': 2, 'universityId': 'sch', 'campus': 'unknown', 'campusName': '위치 미확인',
               'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-10-07',
               'sourceUrl': 'https://st.sch.ac.kr/?sch001', 'courses': courses}
    target.write_text(json.dumps(dataset, ensure_ascii=False, indent=2) + '\n')
    audit = {'reviewDate': '2026-10-08', 'productionRegistered': False, 'completionClaim': False,
             'wholeMetadata': 2598, 'corroboratedScheduledCourses': 5,
             'datedMeetings': sum(len(c['schedules']) for c in courses),
             'remainingUnrecognized': 2593, 'sourceMetadataEqualityMismatches': 0,
             'sourceProjectionSHA256': hashlib.sha256(source_path.read_bytes()).hexdigest(),
             'candidateSHA256': hashlib.sha256(target.read_bytes()).hexdigest(),
             'clockBasis': ['sch-latest-public-yearbook-clock-review-20261008.json', 'sch-current-accounting-clock-operating-review-20261008.json'],
             'dateBasis': ['sch-current-academic-rule-20261008.json', 'sch-current-gyomu-regulation-20261008.json', 'sch-2026-calendar-dom.json'],
             'ordinaryDateRange': ['2026-08-31', '2026-12-06'],
             'excludedPublishedMidtermWeek': ['2026-10-19', '2026-10-23'],
             'notGeneratedFinals': ['2026-12-07', '2026-12-11'], 'notGeneratedMakeup': ['2026-12-14', '2026-12-18'],
             'holidayDates': sorted(HOLIDAYS), 'hangulDayDateSource': 'https://law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=900257794',
             'holidayRule': 'Latest school article10 explicitly closes legal holidays; actual course exception overrides if later confirmed.',
             'limits': ['Only five independently matching accounting courses; no extrapolation to 811 other A/B rows.', '7 accounting changes preserve current Oct7 data and remain individually pending.', 'Current full individual plans have not been read; no hidden plan extraction.', 'No inferred campus from department/room; unknown preserved.', 'CORS_NO is published visible 수강번호; SBJT_ID retained separately, no invented code decomposition.']}
    (ROOT / 'sch-accounting-five-candidate-audit-20261008.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k:audit[k] for k in ['wholeMetadata','corroboratedScheduledCourses','datedMeetings','remainingUnrecognized','candidateSHA256']}))


if __name__ == '__main__':
    main()
