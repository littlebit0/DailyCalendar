from pathlib import Path
import copy
import datetime
import hashlib
import json
import re

P = Path(__file__).parent
read = lambda name: json.loads((P / name).read_text())
base = read('baseline-sejong22-18-701.json')
calendar = read('current-own-sejong-calendar-education.json')
clock = {r['period']: r for r in read('current-own-sejong-regular-clock-education.json')['periods']}
closed = {r['identity'] for r in read('source-sejong-current-53-closure-education.json')['rows']}
rows = copy.deepcopy(base['courses'])
assert len(rows) == 22
observed = set()
proofs = []
scopes = read('source-captured-scope-config-open.json')
source_entries = {}
source_occurrences = 0
for scope in scopes:
    file = P / scope['file']
    assert hashlib.sha256(file.read_bytes()).hexdigest() == scope['sourceSHA256']
    source = json.loads(file.read_text())
    assert source.get('campus', source.get('selectedCampus')) == '세종' and source.get('year', source.get('selectedYear')) in (2026, '2026') and source.get('term', source.get('selectedSemester')) in ('2학기', '2R')
    assert len(source['rows']) == source['capturedRows'] == source['displayedTotal'] == scope['whole']
    within_query = set()
    for raw in source['rows']:
        identity = raw['COUR_CD'] + '-' + raw['COUR_CLS']
        assert identity not in within_query, 'Duplicate within one query is an unresolved source capture ambiguity'
        within_query.add(identity)
        source_entries.setdefault(identity, []).append({'file': scope['file'], 'sourceSHA256': scope['sourceSHA256'], 'selectedDepartment': scope['selectedDepartment'], 'nativeEducation': copy.deepcopy(raw)})
        source_occurrences += 1
cross_query_audit = []
for identity, occurrences in source_entries.items():
    observed.add(identity)
    raw = occurrences[0]['nativeEducation']
    differences = []
    for occurrence in occurrences[1:]:
        other = occurrence['nativeEducation']
        changed = sorted(key for key in set(raw) | set(other) if raw.get(key) != other.get(key))
        differences.append({'sourceFile': occurrence['file'], 'changedFields': changed, 'operatingConflictingFields': [key for key in changed if key != 'DEPARTMENT']})
    conflicting = sorted({key for change in differences for key in change['operatingConflictingFields']})
    if len(occurrences) > 1:
        cross_query_audit.append({'identity': identity, 'sourceOccurrences': copy.deepcopy(occurrences), 'fieldDifferences': differences, 'operatingConflicts': conflicting, 'mergedIntoOneNativeModel': True, 'arbitraryNewSourceIdCreated': False})
    assert raw['YEAR'] == '2026' and raw['TERM'] == '2R' and raw['CAMPUS'] == '세종'
    title = raw['COUR_NM'].split('\n')[0].strip()
    badges = []
    for suffix in ['FCDL', 'MDL', 'MES', 'FCES', 'FCT', 'FC', 'NM', 'DL', 'ES', 'T', 'M']:
        if title.endswith(suffix):
            badges = {'FCDL': ['FC', 'DL'], 'MDL': ['M', 'DL'], 'MES': ['M', 'ES'], 'FCES': ['FC', 'ES'], 'FCT': ['FC', 'T']}.get(suffix, [suffix])
            title = title[:-len(suffix)]
            break
    holds = []
    if raw['COUR_CD'] in {'PHAR528', 'PHAR530', 'PHAR532', 'PHAR534', 'PHAR536', 'PHAR538', 'PHAR540'}:
        holds.append('Current clinical/community-pharmacy/manufacturing placement has cross-room or beyond-published-period operation; individual actual allocation is unknown, no isolated ordinary fragment generalized')
    if conflicting:
        holds.append('Current same-native cross-query educational fields conflict: ' + ', '.join(conflicting))
    partial = []
    slots = []
    allocations = {}
    note = raw['APPLY_DEPT']
    if raw['MOOC_YN'] == '1' or 'M' in badges:
        holds.append('Published MOOC lacks individual dated synchronous allocation proof')
    if identity in closed:
        holds.append('Current native identity explicitly present in own current Sejong closure list53')
    if '유연학기' in note and not (raw['FLEXIBLE_FR_DT'] and raw['FLEXIBLE_TO_DT']):
        holds.append('Explicit flexible operation without individual current dates')
    if note == '혼합수업':
        holds.append('Explicit mixed operation without individual allocation proof')
    for line in raw['TIME_ROOM'].splitlines():
        match = re.fullmatch(r'([월화수목금토일])\(([^)]+)\)\s+(.+)', line.strip())
        if not match:
            partial.append({'sourceLine': line, 'reason': 'Current actual day/time/room unallocated'})
            continue
        day = '월화수목금토일'.index(match[1]) + 1
        for part in match[2].split(','):
            bounds = [int(s) for s in re.split(r'[-~]', part)]
            periods = list(range(bounds[0], bounds[-1] + 1))
            if any(period not in clock for period in periods):
                partial.append({'sourceLine': line, 'weekday': day, 'sourcePeriods': periods, 'reason': 'This current block includes unpublished Sejong period; no end inferred, separate directly known blocks retained'})
                continue
            for period in periods:
                key = (day, period)
                allocations.setdefault(key, set()).add(match[3])
                slots.append({'weekday': day, 'sourcePeriod': period, 'startMinute': clock[period]['startMinute'], 'endMinute': clock[period]['endMinute'], 'classroom': match[3]})
    conflicts = {key for key, rooms in allocations.items() if len(rooms) != 1}
    for day, period in sorted(conflicts):
        partial.append({'weekday': day, 'sourcePeriod': period, 'reason': 'Simultaneous literal rooms ambiguous; no arbitrary room selected'})
    slots = list({(s['weekday'], s['sourcePeriod'], s['classroom']): s for s in slots if (s['weekday'], s['sourcePeriod']) not in conflicts}.values())
    if not slots:
        holds.append('No complete current native actual clock/room block')
    start = raw['FLEXIBLE_FR_DT'] or calendar['semesterStart']
    end = raw['FLEXIBLE_TO_DT'] or calendar['semesterEnd']
    assert re.fullmatch(r'2026-\d{2}-\d{2}', start) and start <= end
    schedules = []
    if not holds:
        date = datetime.date.fromisoformat(start)
        while str(date) <= min(end, calendar['ordinaryReservationEndDerived']):
            ds = str(date)
            if ds not in calendar['holidays'] and not calendar['midtermStart'] <= ds <= calendar['midtermEnd']:
                for slot in slots:
                    if date.isoweekday() == slot['weekday']:
                        schedules.append({k: v for k, v in slot.items() if k != 'sourcePeriod'} | {'date': ds})
            date += datetime.timedelta(days=1)
    remark = '현재2026-2 세종캠퍼스 공식 공개 수강조회 배정과 자체 정규 교시표·학사일정에 따른 주간 예약 계획입니다. 실제 모든 출석일·실습·시험·보강일을 확정한 자료가 아닙니다. 학교 공휴일과 중간10/20–26·기말12/14–18은 보수적 예약 제외이며 전교 휴강 주장과 다릅니다. 과목별 운영기간·비고·원문 실·요일·학수번호·분반·강사·학점·구분을 보존하고 사용자 수업방식 선택을 강제 변경하지 않습니다.'
    if 'FC' in badges:
        remark += ' FC는 LMS 사전학습 후 출석 토론·연습 방식이며 온라인 비중1/3–1/2까지 가능하므로 개별 온라인 날짜·분배는 미확인입니다.'
    if 'NM' in badges:
        remark += ' NeMo는 대면·실시간 송출 병행 방식이며 원문 배정실의 예약만 표시합니다. 실제 학생별 메인/서브 위치는 미확인입니다.'
    if 'DL' in badges:
        remark += ' DL은 수강포기 제한이며 원격 방식 표시가 아닙니다.'
    if note:
        remark += ' 원문 비고: ' + note
    if holds:
        remark += ' 일정 보류: ' + ' / '.join(dict.fromkeys(holds))
    c = {'sourceId': 'korea/sejong/2026-2/' + identity, 'campus': 'sejong', 'academicYear': 2026, 'semester': '2', 'courseCode': raw['COUR_CD'], 'section': raw['COUR_CLS'], 'courseName': title, 'professor': raw['PROF_NM'], 'classification': raw['ISU_NM'], 'credits': float(raw['CREDIT']), 'departments': [raw['DEPARTMENT']], 'departmentCredits': {raw['DEPARTMENT']: float(raw['CREDIT'])}, 'departmentClassifications': {raw['DEPARTMENT']: raw['ISU_NM']}, 'sourceSchedule': raw['TIME_ROOM'], 'sourceClassroom': ' / '.join(dict.fromkeys(s['classroom'] for s in slots)), 'sourceEducationalMetadata': copy.deepcopy(raw), 'sourcePublishedBadges': badges, 'sourceCurrentClockSegments': slots, 'reservationOnly': True, 'actualAttendanceConfirmed': False, 'schedules': schedules, 'scheduleStatus': 'scheduled' if schedules else 'unscheduled', 'remarks': remark, 'period': {'startDate': start, 'endDate': end}, 'sourceOperatingHolds': list(dict.fromkeys(holds)), 'sourcePartialCoverage': bool(partial), 'sourcePerBlockHolds': partial}
    if len(occurrences) > 1:
        c['sourceEducationalVariants'] = [copy.deepcopy(o['nativeEducation']) for o in occurrences]
        c['sourceQueryProvenance'] = [{key: value for key, value in o.items() if key != 'nativeEducation'} for o in occurrences]
        c['sourceCrossQueryConflicts'] = conflicting
        c['departments'] = list(dict.fromkeys(o['nativeEducation']['DEPARTMENT'] for o in occurrences))
        c['departmentCredits'] = {o['nativeEducation']['DEPARTMENT']: float(o['nativeEducation']['CREDIT']) for o in occurrences}
        c['departmentClassifications'] = {o['nativeEducation']['DEPARTMENT']: o['nativeEducation']['ISU_NM'] for o in occurrences}
    rows.append(c)
    proofs.append({'identity': identity, 'meetings': len(schedules), 'holds': c['sourceOperatingHolds'], 'perBlockHolds': partial})
assert len(rows) == len(observed) + 22 == len({c['sourceId'] for c in rows})
assert rows[:22] == base['courses']
dataset = copy.deepcopy(base)
dataset.update({'courses': rows, 'researchOnly': True, 'completionClaim': False, 'sourceQueryScope': 'Closed61 current normally admitted public Sejong undergraduate queries: major35, foundation10, general14, teacher1, lifelong1. Root observed every visible selection; military41 explicitly excluded/unqueried. Whole latest operating/closure confirmation remains unverified.'})
f = P / 'korea-sejong-2026-2.current-native-reviewed-v8-20261009.json'
f.write_text(json.dumps(dataset, ensure_ascii=False, indent=2) + '\n')
audit = {'researchOnly': True, 'completionClaim': False, 'scopeClosed': True, 'sourceCaptures': len(scopes), 'newNative': len(observed), 'wholeIncludingFrozen22': len(rows), 'scheduled': sum(bool(c['schedules']) for c in rows), 'meetings': sum(len(c['schedules']) for c in rows), 'sourceOccurrenceRows': source_occurrences, 'sourceNativeDuplicateJoins': cross_query_audit, 'currentClosedIntersection': sorted(observed & closed), 'old22DeepPreserved': True, 'oldOpaqueNativeAliasVerified': False, 'candidateSHA256': hashlib.sha256(f.read_bytes()).hexdigest(), 'newSourceProofs': proofs, 'actualFixture': 'Five tests prepared as .dart.txt; closed61 source scope; SDK validation pending', 'SDKUsed': False, 'productChanged': False}
(P / 'candidate-audit-open.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print({k: v for k, v in audit.items() if k != 'newSourceProofs'})
