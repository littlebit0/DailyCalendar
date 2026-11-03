from pathlib import Path
import copy
import datetime
import hashlib
import json
import re

P = Path(__file__).parent
read = lambda name: json.loads((P / name).read_text())
base = read('baseline-seoul434-reviewed-v2.json')
baseline = {c['courseCode'] + '-' + c['section']: c for c in base['courses']}
assert len(baseline) == 434
clock = {r['period']: r for r in read('current-2026-2-campus-clock-education.json')['seoul']}
calendar = read('current-2026-2-calendar-education.json')
closed = set(read('closure-cumulative-scope-audit.json')['knownSeoulClosedUnion'])
config = read('source-captured-scope-config.json')
sources = {}
for scope in config:
    f = P / scope['file']
    assert hashlib.sha256(f.read_bytes()).hexdigest() == scope['sourceSHA256']
    x = json.loads(f.read_text())
    assert x['selectedCampus'] == '서울' and x['selectedYear'] == 2026 and x['selectedSemester'] == '2R'
    assert len(x['rows']) == scope['whole'] == x['capturedRows'] == x['displayedTotal']
    for row in x['rows']:
        identity = row['COUR_CD'] + '-' + row['COUR_CLS']
        assert identity not in sources, 'Do not overwrite cross-query ambiguous identities'
        sources[identity] = row

operating_additions = {'BUSS205-01', 'BUSS342-01', 'NEIK212-00', 'NEIK242-00', 'ACEE231-00'}
rows = []
proofs = []
for identity, raw in sources.items():
    old = baseline.get(identity)
    if old is not None and identity not in operating_additions:
        assert old['sourceEducationalMetadata'] == raw
        rows.append(copy.deepcopy(old))
        continue
    assert raw['YEAR'] == '2026' and raw['TERM'] == '2R' and raw['CAMPUS'] == '서울'
    holds = []
    block_holds = []
    segments = []
    period_rooms = {}
    first_line = raw['COUR_NM'].split('\n')[0].strip()
    badge = ''
    for suffix in ['FC', 'NM', 'DL', 'ES', 'T', 'M']:
        if first_line.endswith(suffix):
            badge = suffix
            break
    title = first_line[:-len(badge)] if badge else first_line
    if raw['NEMO_YN'] == '1' and badge != 'NM':
        holds.append('Native NeMo flag and rendered badge conflict')
    if raw['MOOC_YN'] == '1' or badge == 'M':
        holds.append('Published MOOC operation lacks individual synchronous or dated allocation proof')
    if '유연학기' in raw['APPLY_DEPT'] and not (raw['FLEXIBLE_FR_DT'] and raw['FLEXIBLE_TO_DT']):
        holds.append('Explicit flexible-term operation without direct individual dates')
    if raw['APPLY_DEPT'] == '혼합수업':
        holds.append('Explicit mixed operation without allocation or synchronous proof')
    if '일정-' in raw['APPLY_DEPT']:
        holds.append('Individual department allocation reference not yet joined')
    if identity in closed:
        holds.append('Current native offering explicitly closed')
    room_prefix = re.match(r'강의실\s*:\s*(.*)', raw['APPLY_DEPT'].lstrip(' (*★※\t\r\n'))
    explicit_single_room = None
    if room_prefix:
        room_text = room_prefix[1]
        room_match = re.match(r'([^<>\n]*?\d+[A-Z]?호(?:\([^)]*\))?)', room_text)
        if room_match and len(re.findall(r'\d+[A-Z]?호', room_text)) == 1:
            explicit_single_room = room_match
    for line in raw['TIME_ROOM'].splitlines():
        if re.fullmatch(r'[월화수목금토일]\([^)]+\)\s*', line.strip()) and explicit_single_room:
            line = line.strip() + ' ' + explicit_single_room[1].strip()
        match = re.fullmatch(r'([월화수목금토일])\(([^)]+)\)\s+(.+)', line.strip())
        if not match:
            holds.append('Current native actual room/day unallocated')
            continue
        weekday = '월화수목금토일'.index(match[1]) + 1
        for part in match[2].split(','):
            bounds = [int(v) for v in re.split(r'[-~]', part)]
            periods = list(range(bounds[0], bounds[-1] + 1))
            if any(p not in clock for p in periods):
                if identity in {'KISE402-00', 'KISE408-00'} and periods == [11]:
                    block_holds.append({'weekday': weekday, 'sourcePeriods': periods, 'sourceLine': line, 'reason': 'Standalone Seoul11 block has no published actual HH:mm; independent1–2 block preserved'})
                    continue
                holds.append('Current native block includes unpublished Seoul period')
                continue
            for period in periods:
                key = (weekday, period)
                if key in period_rooms and period_rooms[key] != match[3]:
                    holds.append('Actual same-day/same-period multiple-room allocation conflict')
                period_rooms[key] = match[3]
                segments.append({'weekday': weekday, 'startMinute': clock[period]['startMinute'], 'endMinute': clock[period]['endMinute'], 'classroom': match[3], 'sourcePeriod': period})
    override = None
    if identity in {'DISS241-00', 'GKSS202-00'}:
        match = re.search(r'강의\s*시간\s*:\s*(\d{1,2}):(\d{2})\s*~\s*(\d{1,2}):(\d{2})', raw['APPLY_DEPT'])
        assert match and len({s['weekday'] for s in segments}) == len({s['classroom'] for s in segments}) == 1
        start = int(match[1]) * 60 + int(match[2])
        end = int(match[3]) * 60 + int(match[4])
        assert start == 990 and end == 1130
        override = {'sourceText': match[0], 'originalStandardSegments': copy.deepcopy(segments), 'priority': 'Current course-specific literal HH:mm takes priority; generic period6–8 is not rewritten or claimed to end18:50', 'weekdayAndRoom': 'Unique matching current native offering weekday and room'}
        segments = [{'weekday': segments[0]['weekday'], 'startMinute': start, 'endMinute': end, 'classroom': segments[0]['classroom']}]
    if not segments:
        holds.append('No current complete actual clock-room block')
    start = raw['FLEXIBLE_FR_DT'] or calendar['semesterStart']
    end = raw['FLEXIBLE_TO_DT'] or calendar['semesterEnd']
    assert re.fullmatch(r'2026-\d{2}-\d{2}', start) and start <= end
    schedules = []
    if not holds:
        date = datetime.date.fromisoformat(start)
        while str(date) <= min(end, calendar['ordinaryReservationEndDerived']):
            ds = str(date)
            if ds not in calendar['holidays'] and not calendar['midtermStart'] <= ds <= calendar['midtermEnd']:
                for segment in segments:
                    if date.isoweekday() == segment['weekday']:
                        schedules.append({k: v for k, v in segment.items() if k != 'sourcePeriod'} | {'date': ds})
            date += datetime.timedelta(days=1)
    note = '현재2026-2 공식 공개 수강조회 배정과 학교 정규 교시·학기범위에 따른 주간 예약 계획입니다. 실제 모든 출석일·시험·보강을 확정하는 자료가 아닙니다. 공표된 교시 간 휴식은 보존하며 중간10/20–26·기말12/14–18·공휴일은 예약 제외합니다. 공개 개별 운영기간·원문 비고·강사·과목코드·분반·캠퍼스·강의실을 보존하고 사용자 수업방식 선택을 강제 변경하지 않습니다.'
    if badge == 'FC':
        note += ' FC는 학교 안내상 LMS 사전학습 후 출석 토론·연습하는 방식이며 온라인 비중은1/3–1/2까지 가능합니다. 현재 공표된 정규 시각의 예약이며 개별 온라인 학습일·출석 배분은 미확인입니다.'
    if badge == 'NM':
        note += ' NeMo는 학교 안내상 대면강의와 실시간 송출이 동시에 운영되는 방식입니다. 현재 단일 공표 강의실·주간시각의 예약이며 실제 메인/서브 학생 배정과 수강 위치는 미확인입니다. 사용자 선택은 실제로 세 방식 모두 제공됐다는 뜻이 아닙니다.'
    if badge == 'DL':
        note += ' DL은 수강포기 제한 표시이고 원격 수업방식이 아닙니다.'
    if raw['APPLY_DEPT']:
        note += ' 원문 비고: ' + raw['APPLY_DEPT']
    if override:
        note += ' 과목 비고의 직접 공표 시각16:30–18:50을 일반6–8교시보다 우선했습니다. 원문 교시와 일반표 차이는 별도 보존했습니다.'
    if block_holds:
        note += ' 직접 알려진1–2교시 블록만 부분 예약했고 별도11교시는 실제 시각 미공개로 보류했습니다.'
    if holds:
        note += ' 일정 보류: ' + ' / '.join(dict.fromkeys(holds))
    if old is None:
        c = {'sourceId': 'korea/seoul/2026-2/' + identity, 'campus': 'seoul', 'academicYear': 2026, 'semester': '2', 'courseCode': raw['COUR_CD'], 'section': raw['COUR_CLS'], 'courseName': title, 'professor': raw['PROF_NM'], 'classification': raw['ISU_NM'], 'credits': float(raw['CREDIT']), 'departments': [raw['DEPARTMENT']], 'departmentCredits': {raw['DEPARTMENT']: float(raw['CREDIT'])}, 'departmentClassifications': {raw['DEPARTMENT']: raw['ISU_NM']}, 'sourceSchedule': raw['TIME_ROOM'], 'sourceClassroom': ' / '.join(dict.fromkeys(s['classroom'] for s in segments)), 'sourceEducationalMetadata': copy.deepcopy(raw), 'sourcePublishedBadge': badge, 'sourceCurrentClockSegments': segments, 'sourceExplicitSingleRemarkRoom': explicit_single_room[1].strip() if explicit_single_room else None, 'reservationOnly': True, 'actualAttendanceConfirmed': False}
    else:
        assert old['sourceEducationalMetadata'] == raw and not old['schedules']
        c = copy.deepcopy(old)
        c['sourceReviewedOperatingHoldChange'] = {'priorRemarks': old['remarks'], 'priorOperatingHolds': old['sourceOperatingHolds'], 'directOfficialEducationReceipt': 'source-fc-nemo-official-operation-education.json', 'meaning': 'Published current native allocation supports regular reservation; actual attendance/delivery distribution still unknown'}
    c.update({'schedules': schedules, 'scheduleStatus': 'scheduled' if schedules else 'unscheduled', 'remarks': note, 'period': {'startDate': start, 'endDate': end}, 'sourceOperatingHolds': list(dict.fromkeys(holds)), 'sourcePartialCoverage': bool(block_holds), 'sourcePerBlockHolds': block_holds})
    if override:
        c['sourceClockOverrideProof'] = override
    rows.append(c)
    proofs.append({'identity': identity, 'oldOperatingHoldReviewed': old is not None, 'badge': badge, 'meetings': len(schedules), 'holds': c['sourceOperatingHolds'], 'perBlockHolds': block_holds, 'directHHOverride': override is not None, 'sourceScope': 'current normally admitted public undergraduate department query'})

assert len(rows) == len(sources) == len({c['sourceId'] for c in rows})
dataset = copy.deepcopy(base)
dataset.update({'courses': rows, 'sourceQueryScope': f'{len(config)} current public Seoul department queries, including empty scopes; whole university coverage incomplete', 'researchOnly': True, 'completionClaim': False})
target = P / 'korea-seoul-2026-2.current-native-reviewed-v3-20261009.json'
target.write_text(json.dumps(dataset, ensure_ascii=False, indent=2) + '\n')
audit = {'researchOnly': True, 'completionClaim': False, 'whole': len(rows), 'scheduled': sum(bool(c['schedules']) for c in rows), 'meetings': sum(len(c['schedules']) for c in rows), 'candidateSHA256': hashlib.sha256(target.read_bytes()).hexdigest(), 'sourceCaptures': len(config), 'sourceNativeDuplicates': [], 'knownSeoulClosedIntersection': list(set(sources) & closed), 'baselineNative': 434, 'baselineDeepPreservedExceptExplicitOperatingReviews': sorted(operating_additions), 'newNative': len(sources) - 434, 'newSourceProofs': proofs, 'actualFixture': 'pending', 'SDKUsed': False, 'productChanged': False}
(P / 'candidate-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print({k: v for k, v in audit.items() if k != 'newSourceProofs'})
