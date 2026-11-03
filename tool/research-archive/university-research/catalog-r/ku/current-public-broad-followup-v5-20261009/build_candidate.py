from pathlib import Path
import copy
import datetime
import hashlib
import json
import re

P = Path(__file__).parent
read = lambda name: json.loads((P / name).read_text())
base = read('baseline-seoul1188-reviewed-v4.json')
baseline = {c['courseCode'] + '-' + c['section']: c for c in base['courses']}
assert len(baseline) == 1188
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

operating_additions = set()
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
    badges = [badge] if badge else []
    multiple_badges = {
        'CSAI202-02': ('기초딥러닝', ['FC', 'ES']),
        'COSE212-01': ('프로그래밍언어', ['DL', 'ES']),
        'COSE352-01': ('소프트웨어공학', ['FC', 'T']),
        'COSE361-01': ('인공지능(영강)', ['T', 'DL']),
        'COSE474-01': ('딥러닝', ['DL', 'ES']),
        'JURA242-01': ('민법', ['M', 'ES']),
        'JURA249-00': ('국제법', ['M', 'ES']),
    }
    if identity in multiple_badges:
        title, badges = multiple_badges[identity]
        assert first_line == title + ''.join(badges)
        badge = 'FC' if 'FC' in badges else badges[0]
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
    if identity in {'GEOG172-00', 'GEOG272-00', 'GEOG372-00'}:
        assert float(raw['CREDIT']) == 0 and raw['TIME_ROOM'].startswith('토(0)')
        holds.append('Published zero-credit field-survey placeholder has no actual individual field dates/venue allocation')
    if '이론강의실' in raw['APPLY_DEPT']:
        holds.append('Source distinguishes numbered-week theory room from physical practice venue; exact dated allocation is unpublished, no week-to-date invention')
    elif re.search(r'^(체육생활관|화정체육관) ', raw['APPLY_DEPT']):
        holds.append('Explicit physical practice venue conflicts with current native educational classroom; no direct precedence or allocation dates')
    if identity in closed:
        holds.append('Current native offering explicitly closed')
    room_prefix = re.match(r'강의실\s*:\s*(.*)', raw['APPLY_DEPT'].lstrip(' (*★※\t\r\n'))
    explicit_single_room = None
    if room_prefix:
        room_text = room_prefix[1]
        room_match = re.match(r'([^<>\n]*?\d+[A-Z]?호(?:\([^)]*\))?)', room_text)
        if room_match and len(re.findall(r'\d+[A-Z]?호', room_text)) == 1:
            explicit_single_room = room_match
    # A bare, complete source room is a literal allocation, not a building guess.
    bare_room = re.fullmatch(r'[^<>\n:]*?\d+[A-Z]?호', raw['APPLY_DEPT'].strip())
    if bare_room:
        explicit_single_room = [None, bare_room[0]]
    hall = re.search(r'강의실\s*:\s*(대강당 한국일보홀)(?:<br>|$)', raw['APPLY_DEPT'])
    if hall:
        explicit_single_room = [None, hall[1]]
    if identity == 'LIET365-00':
        assert raw['APPLY_DEPT'] == '*강의실 생명과학관 동관 416호 오정강당으로 변경(2026.08.28.자)'
        explicit_single_room = [None, '생명과학관 동관 416호 오정강당']
    if identity in {'LESE322-00', 'LESE326-00'}:
        assert raw['APPLY_DEPT'].startswith('●강의실: 생명과학관(동관) 416호 오정강당')
        explicit_single_room = [None, '생명과학관(동관) 416호 오정강당']
    if identity in {'ECON172-09', 'ECON172-10'}:
        assert raw['APPLY_DEPT'] == '(경영대 전용반)(강의실: 대강당 한국일보홀)'
        explicit_single_room = [None, '대강당 한국일보홀']
    if identity == 'JURA204-00':
        assert raw['APPLY_DEPT'] == '강의실: 대강당 김양현홀'
        explicit_single_room = [None, '대강당 김양현홀']
    conflicting_periods = set()
    for line in raw['TIME_ROOM'].splitlines():
        day = line.strip()[:1]
        if identity in {'EDUC230-00', 'EDUC274-00', 'EDUC318-00'}:
            online = re.search(rf'{day}\s*:\s*비대면', raw['APPLY_DEPT'])
            if online:
                block_holds.append({'sourceLine': line, 'reason': 'Direct course remark assigns this weekday to remote operation; no direct dated remote allocation'})
                continue
            if identity == 'EDUC274-00' and day == '화':
                assert '화: 대면,(교육관 507호)' in raw['APPLY_DEPT']
                line = line.strip() + ' 교육관 507호'
        if re.fullmatch(r'[월화수목금토일]\([^)]+\)\s*', line.strip()) and explicit_single_room:
            line = line.strip() + ' ' + explicit_single_room[1].strip()
        match = re.fullmatch(r'([월화수목금토일])\(([^)]+)\)\s+(.+)', line.strip())
        if not match:
            block_holds.append({'sourceLine': line, 'reason': 'Current native actual room/day unallocated; no other weekday room borrowed'})
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
                    conflicting_periods.add(key)
                period_rooms[key] = match[3]
                segments.append({'weekday': weekday, 'startMinute': clock[period]['startMinute'], 'endMinute': clock[period]['endMinute'], 'classroom': match[3], 'sourcePeriod': period})
    if conflicting_periods:
        for day, period in sorted(conflicting_periods):
            block_holds.append({'weekday': day, 'sourcePeriod': period, 'reason': 'Actual same-day/same-period multiple-room allocation conflict; neither room selected'})
        segments = [s for s in segments if (s['weekday'], s['sourcePeriod']) not in conflicting_periods]
    override = None
    if identity in {'HEED234-01', 'HEED234-02', 'HEED333-00', 'HEED334-00', 'FADM402-00', 'HISE204-00', 'HISE411-00', 'HISE462-00'}:
        direct = re.match(r'(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})', raw['APPLY_DEPT'])
        assert direct and len({s['weekday'] for s in segments}) == len({s['classroom'] for s in segments}) == 1
        start = int(direct[1]) * 60 + int(direct[2])
        end = int(direct[3]) * 60 + int(direct[4])
        standard_start = min(s['startMinute'] for s in segments)
        if start < 720 and standard_start >= 720:
            start += 720
            end += 720
        assert start == standard_start and end > start
        override = {'sourceText': direct[0], 'originalStandardSegments': copy.deepcopy(segments), 'priority': 'Course-specific literal clock priority; incomplete 12-hour source is disambiguated only by matching current native afternoon period start', 'sourceExplicitPM': False, 'native24HourContext': standard_start}
        segments = [{'weekday': segments[0]['weekday'], 'startMinute': start, 'endMinute': end, 'classroom': segments[0]['classroom']}]
    if identity == 'MATE404-00':
        assert '화요일은 6시 20분까지 수업' in raw['APPLY_DEPT']
        tue = [s for s in segments if s['weekday'] == 2]
        assert min(s['startMinute'] for s in tue) == 990 and max(s['endMinute'] for s in tue) == 1130
        override = {'sourceText': '화요일은 6시 20분까지 수업', 'originalStandardSegments': copy.deepcopy(segments), 'priority': 'Direct Tuesday end18:20 is disambiguated by matching native afternoon6–7; Wednesday unchanged', 'sourceExplicitPM': False}
        segments = [s for s in segments if s['weekday'] != 2] + [{'weekday': 2, 'startMinute': 990, 'endMinute': 1100, 'classroom': tue[0]['classroom']}]
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
    if identity == 'ELED164-01':
        assert raw['PROF_NM'] == '이영주' and raw['APPLY_DEPT'] == '이지선 교수님'
        note += ' 담당교수 열은 이영주, 비고는 이지선 교수님으로 원문 내 차이가 있습니다. 어느 쪽도 임의 교정하지 않았습니다.'
    if override:
        note += ' 과목별 직접 공표 시각을 일반 교시표보다 우선했고 원문과 일반표 차이를 별도 보존했습니다. 12시간제의 오전·오후 생략은 현재 원문 교시의 시작 시각이 일치할 때만 구별했습니다.'
    if block_holds:
        note += ' 원문 시각과 강의실이 확인된 회차만 부분 예약했고 미배정·원격 배정 미확정·실 중복 회차는 별도로 보류했습니다.'
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
    if len(badges) > 1:
        c['sourcePublishedBadges'] = badges
    if identity == 'ELED164-01':
        c['sourceInstructorConflict'] = {'nativeInstructor': raw['PROF_NM'], 'remarkInstructor': raw['APPLY_DEPT'], 'resolved': False}
    rows.append(c)
    proofs.append({'identity': identity, 'oldOperatingHoldReviewed': old is not None, 'badge': badge, 'meetings': len(schedules), 'holds': c['sourceOperatingHolds'], 'perBlockHolds': block_holds, 'directHHOverride': override is not None, 'sourceScope': 'current normally admitted public undergraduate department query'})

assert len(rows) == len(sources) == len({c['sourceId'] for c in rows})
dataset = copy.deepcopy(base)
dataset.update({'courses': rows, 'sourceQueryScope': f'{len(config)} current public Seoul department queries, including empty scopes; whole university coverage incomplete', 'researchOnly': True, 'completionClaim': False})
target = P / 'korea-seoul-2026-2.current-native-reviewed-v5-20261009.json'
target.write_text(json.dumps(dataset, ensure_ascii=False, indent=2) + '\n')
audit = {'researchOnly': True, 'completionClaim': False, 'whole': len(rows), 'scheduled': sum(bool(c['schedules']) for c in rows), 'meetings': sum(len(c['schedules']) for c in rows), 'candidateSHA256': hashlib.sha256(target.read_bytes()).hexdigest(), 'sourceCaptures': len(config), 'sourceNativeDuplicates': [], 'knownSeoulClosedIntersection': list(set(sources) & closed), 'baselineNative': 1188, 'baselineDeepPreservedExceptExplicitOperatingReviews': sorted(operating_additions), 'newNative': len(sources) - 1188, 'newSourceProofs': proofs, 'actualFixture': 'pending', 'SDKUsed': False, 'productChanged': False}
(P / 'candidate-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print({k: v for k, v in audit.items() if k != 'newSourceProofs'})
