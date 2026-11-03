from pathlib import Path
import copy
import datetime
import hashlib
import json
import re

P = Path(__file__).parent
source = P.parents[2] / 'root-ku-normal-ui-20261009' / 'seoul-semiconductor-current15-education.json'
raw = json.loads(source.read_text())
assert raw['selectedYear'] == 2026 and raw['selectedSemester'] == '2R'
assert raw['selectedCampus'] == '서울' and raw['displayedTotal'] == raw['capturedRows'] == len(raw['rows']) == 15
assert hashlib.sha256(source.read_bytes()).hexdigest() == 'd0be3aaa2ba1df5888ae3840ac306750fa0949886e1b7371bfd6f62193cf763b'
(P / 'source-semiconductor15-education.json').write_bytes(source.read_bytes())
calendar = json.loads((P / 'current-2026-2-calendar-education.json').read_text())
clock = {r['period']: r for r in json.loads((P / 'current-2026-2-campus-clock-education.json').read_text())['seoul']}
closed = set(json.loads((P / 'closure-cumulative-scope-audit.json').read_text())['knownSeoulClosedUnion'])
courses = []
proofs = []
for row in raw['rows']:
    assert row['YEAR'] == '2026' and row['TERM'] == '2R' and row['CAMPUS'] == '서울'
    identity = row['COUR_CD'] + '-' + row['COUR_CLS']
    first_line = row['COUR_NM'].split('\n')[0].strip()
    badge = 'FC' if first_line.endswith('FC') else 'DL' if first_line.endswith('DL') else ''
    title = first_line[:-len(badge)] if badge else first_line
    holds = []
    segments = []
    allocations = {}
    if badge == 'FC':
        holds.append('FC badge individual operating allocation not yet verified')
    if '유연학기' in row['APPLY_DEPT'] and not (row['FLEXIBLE_FR_DT'] and row['FLEXIBLE_TO_DT']):
        holds.append('Explicit flexible-term operation without published individual dates')
    if identity in closed:
        holds.append('Current official native closure')
    direct_remark_room = row['APPLY_DEPT'].strip() if re.fullmatch(r'[^\n<>*]+\s+[A-Z]?\d+[A-Z]?호(?:\([^)]*\))?', row['APPLY_DEPT'].strip()) else ''
    single_room = re.fullmatch(r'강의실\s*:\s*([^<>\n]+)', row['APPLY_DEPT'].strip())
    if single_room:
        direct_remark_room = single_room[1].strip()
    for line in row['TIME_ROOM'].splitlines():
        if re.fullmatch(r'[월화수목금토일]\([^)]+\)\s*', line.strip()) and direct_remark_room:
            line = line.strip() + ' ' + direct_remark_room
        match = re.fullmatch(r'([월화수목금토일])\(([^)]+)\)\s+(.+)', line.strip())
        if not match:
            holds.append('Unresolved native time-room line')
            continue
        weekday = '월화수목금토일'.index(match[1]) + 1
        for part in match[2].split(','):
            bounds = [int(v) for v in re.split(r'[-~]', part)]
            for period in range(bounds[0], bounds[-1] + 1):
                key = (weekday, period)
                if key in allocations and allocations[key] != match[3]:
                    holds.append('Conflicting current room allocation')
                allocations[key] = match[3]
                if period not in clock:
                    holds.append('Native period outside published current Seoul clock table')
                    continue
                segments.append({'weekday': weekday, 'startMinute': clock[period]['startMinute'], 'endMinute': clock[period]['endMinute'], 'classroom': match[3], 'sourcePeriod': period})
    if not allocations:
        holds.append('No current clock-room allocation')
    # Every public operating remark was manually read: topic, registration
    # restrictions, microdegree and explicitly dated flexible-term notes do not
    # imply that the current day-room allocation must be blanked.
    start = row['FLEXIBLE_FR_DT'] or calendar['semesterStart']
    end = row['FLEXIBLE_TO_DT'] or calendar['semesterEnd']
    assert start <= end
    schedules = []
    partial_monday = identity == 'SEMI110-00' and all(reason == 'Unresolved native time-room line' for reason in holds)
    if not holds or partial_monday:
        date = datetime.date.fromisoformat(start)
        while str(date) <= min(end, calendar['ordinaryReservationEndDerived']):
            day = str(date)
            if day not in calendar['holidays'] and not calendar['midtermStart'] <= day <= calendar['midtermEnd']:
                for segment in segments:
                    if date.isoweekday() == segment['weekday']:
                        schedules.append({k: v for k, v in segment.items() if k != 'sourcePeriod'} | {'date': day})
            date += datetime.timedelta(days=1)
    note = '현재2026-2 공개 수강조회 원문과 학교 서울캠퍼스 정규 교시표로 만든 주간 예약 계획입니다. 과목별 비고·개별 운영기간·요일·강의실을 보존하며 교시 사이의 공표 휴식은 합치지 않았습니다. 실제 모든 출석일·시험·보강을 확정한 자료는 아닙니다. 중간10/20–26·기말12/14–18·공휴일은 예약 제외하고 시험 시각을 만들지 않습니다. 사용자 수업방식 선택을 보존합니다. 전체폐강 완전성은 미확인입니다.'
    if badge == 'DL':
        note += ' DL은 학교 공식FAQ상 수강포기 제한 표시이며 원격수업 표시가 아닙니다.'
    if row['APPLY_DEPT']:
        note += ' 원문 비고: ' + row['APPLY_DEPT']
    if partial_monday:
        note += ' 월요일 직접 공표된 강의실·시각만 부분 예약했으며 화요일 이론/실습실 배정은 미확인입니다. 비고의 두 강의실을 요일별로 추측 배정하지 않았습니다.'
    if holds:
        note += ' 일정 보류: ' + ' / '.join(dict.fromkeys(holds))
    c = {'sourceId': 'korea/seoul/2026-2/' + identity, 'campus': 'seoul', 'academicYear': 2026, 'semester': '2', 'courseCode': row['COUR_CD'], 'section': row['COUR_CLS'], 'courseName': title, 'professor': row['PROF_NM'], 'classification': row['ISU_NM'], 'credits': float(row['CREDIT']), 'departments': [row['DEPARTMENT']], 'departmentCredits': {row['DEPARTMENT']: float(row['CREDIT'])}, 'departmentClassifications': {row['DEPARTMENT']: row['ISU_NM']}, 'sourceSchedule': row['TIME_ROOM'], 'sourceClassroom': ' / '.join(dict.fromkeys(segment['classroom'] for segment in segments)), 'remarks': note, 'scheduleStatus': 'scheduled' if schedules else 'unscheduled', 'schedules': schedules, 'period': {'startDate': start, 'endDate': end}, 'sourceEducationalMetadata': copy.deepcopy(row), 'sourcePublishedBadge': badge, 'sourceExplicitRemarkRoom': direct_remark_room, 'sourceCurrentClockSegments': segments, 'sourceOperatingHolds': list(dict.fromkeys(holds)), 'reservationOnly': True, 'actualAttendanceConfirmed': False, 'sourcePartialCoverage': partial_monday, 'sourcePerDayHolds': [{'weekday': 2, 'sourcePeriods': [2, 3], 'sourceLine': row['TIME_ROOM'].splitlines()[1], 'reason': 'Tuesday unspecified lecture/practice mapping; Monday actualroom not borrowed'}] if partial_monday else []}
    courses.append(c)
    proofs.append({'identity': identity, 'sourceBadge': badge, 'holds': c['sourceOperatingHolds'], 'period': c['period'], 'meetings': len(schedules), 'sourceOperatingRemarkReviewed': row['APPLY_DEPT'], 'nativeClosed': identity in closed})
assert len({c['sourceId'] for c in courses}) == 15
dataset = {'schemaVersion': 2, 'universityId': 'korea', 'campus': 'seoul', 'campusName': '서울캠퍼스', 'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-10-09', 'sourceUrl': 'https://sugang.korea.ac.kr/', 'researchOnly': True, 'completionClaim': False, 'courses': courses}
target = P / 'korea-seoul-2026-2.semiconductor-native15-reviewed-v2-20261009.json'
target.write_text(json.dumps(dataset, ensure_ascii=False, indent=2) + '\n')
audit = {'researchOnly': True, 'completionClaim': False, 'wholeUniversityCatalogComplete': False, 'currentNativeRows': 15, 'scheduled': sum(bool(c['schedules']) for c in courses), 'meetings': sum(len(c['schedules']) for c in courses), 'candidateSHA256': hashlib.sha256(target.read_bytes()).hexdigest(), 'sourceSHA256': hashlib.sha256(source.read_bytes()).hexdigest(), 'proofs': proofs, 'actualFixture': 'pending', 'SDKUsed': False}
(P / 'semiconductor15-candidate-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print({k: v for k, v in audit.items() if k != 'proofs'})
