import collections
import copy
import datetime
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path('work/university-research/catalog-r/suwon/full-term-ordinary-v3-20261008')
PRIOR = ROOT.parent / 'full-query-partial-v2'
baseline_bytes = (PRIOR / 'suwon-unknown-2026-2.early-planned.json').read_bytes()
(ROOT / 'baseline2334-v2-frozen.json').write_bytes(baseline_bytes)
baseline = json.loads(baseline_bytes)
proof = json.loads((PRIOR / 'educational-proof.json').read_text())
for filename, expected in proof['sourceFilesSHA256'].items():
    assert hashlib.sha256(pathlib.Path(filename).read_bytes()).hexdigest() == expected
clock = {x['period']: (int(x['start'][:2])*60+int(x['start'][3:]), int(x['end'][:2])*60+int(x['end'][3:])) for x in proof['clockEvidence']['clock']}
assert sorted(clock) == list(range(1,9))
# Published holidays and own anniversary excluded; no unpublished midterm week inferred.
excluded = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}
start, end = datetime.date(2026,9,1), datetime.date(2026,12,7)

def native_blocks(text):
    if not text:
        return [], ['native weekday/room unpublished']
    outer = list(re.finditer(r'([^(),]+)\(([^()]*)\)', text))
    if ','.join(x.group(0) for x in outer) != text:
        return [], ['native weekday/room syntax unresolved']
    result = []
    for x in outer:
        segments = list(re.finditer(r'([월화수목금토일])(\d+(?:,\d+)*)', x[2]))
        if ' '.join(y.group(0) for y in segments) != x[2]:
            return [], ['native period syntax unresolved']
        for y in segments:
            periods = [int(p) for p in y[2].split(',')]
            if any(p not in clock for p in periods):
                return [], ['native period9+ actual clock unpublished']
            if periods != sorted(set(periods)):
                return [], ['native duplicate/reordered period unresolved']
            runs = []
            for p in periods:
                if not runs or p != runs[-1][-1]+1:
                    runs.append([p])
                else:
                    runs[-1].append(p)
            for run in runs:
                result.append({'weekday': '월화수목금토일'.index(y[1])+1, 'startMinute': clock[run[0]][0], 'endMinute': clock[run[-1]][1], 'classroom': x[1], 'nativePeriods': run})
    for i, a in enumerate(result):
        for b in result[i+1:]:
            if a['weekday']==b['weekday'] and max(a['startMinute'],b['startMinute'])<min(a['endMinute'],b['endMinute']):
                return [], ['native overlapping allocation unresolved']
    return result, []

candidate = copy.deepcopy(baseline)
audits = []
for c, old in zip(candidate['courses'], baseline['courses']):
    variants = [r['values'] for r in c['metadata']['originalEducationalRecords']]
    r = variants[0]
    holds = [h for h in old['metadata']['reservationHoldReasons'] if h.startswith('native identity/') or h=='native closure date/reason' or h=='remote/video/reading operation unknown']
    # Explicit external operation categories are narrower than practical credits or lab/project names.
    external = '병원실습' in r[5] or re.search(r'현장실습|인턴|^보육실습$|^교육실습$', r[3])
    if external:
        holds.append('native external/placement operation; individual dates/allocation unpublished')
    if '집중' in r[3]+r[5]:
        holds.append('native intensive operation bounds unpublished')
    blocks, geometry_holds = native_blocks(r[12])
    holds.extend(geometry_holds)
    meetings = []
    if not holds:
        day = start
        while day <= end:
            if day.isoformat() not in excluded:
                for block in blocks:
                    if day.isoweekday() == block['weekday']:
                        meetings.append({k:v for k,v in block.items() if k!='nativePeriods'} | {'date':day.isoformat()})
            day += datetime.timedelta(days=1)
        # Preserve every old dated object exactly; append only newly eligible reservations.
        old_keys = {json.dumps(m, sort_keys=True) for m in old['schedules']}
        meetings = copy.deepcopy(old['schedules']) + [m for m in meetings if json.dumps(m,sort_keys=True) not in old_keys]
    else:
        assert not old['schedules'], (c['sourceId'], holds)
    c['schedules'] = meetings
    c['scheduleStatus'] = 'scheduled' if meetings else 'unrecognized'
    old_holds = c['metadata']['reservationHoldReasons']
    c['metadata']['priorV2ReservationHoldReasons'] = old_holds
    c['metadata']['reservationHoldReasons'] = holds
    c['metadata']['regularReservationOnly'] = True
    c['metadata']['individualOperatingDaysVerified'] = False
    c['metadata']['nativeClockRoomBlocks'] = blocks
    c['metadata']['reservationScope'] = {'start':'2026-09-01','end':'2026-12-07','endDerivedFromPublishedFinalExams':True}
    c['remarks'] = old['remarks'].split(' / 공개 초기3주 예약 부분범위')[0] + ' / 공개 정규 주간 예약 계획 2026-09-01–12-07. 종료 경계는 자체 공표 12/8 기말고사 시작 전날이며 실제 종강일 표기는 아닙니다. 개별 실제 출석·시험일 확정이 아닙니다. 10/20–26은 수업일수1/2로 중간시험일 발명 없이 유지합니다. 공휴일·개교기념일 제외, 보강 날짜 미생성. 자체1–8교시만 적용하고 미공개9+시각·강의실 약칭 캠퍼스는 추정하지 않습니다. 사용자 수업방식 선택 유지. ' + '; '.join(holds)
    audits.append({'sourceId':c['sourceId'],'priorMeetingCount':len(old['schedules']),'meetingCount':len(meetings),'oldHoldReasons':old_holds,'newHoldReasons':holds,'nativeBlocks':blocks,'practicalCredits':r[9],'nativeTitle':r[3],'nativeAdditional':r[5]})
candidate.update(researchOnly=True,reservationOnly=True,completionClaim=False,wholeOperatingVerified=False,wholeSchoolCourseCoverageComplete=False)
audit = {'researchOnly':True,'completionClaim':False,'whole':len(candidate['courses']),'scheduled':sum(bool(c['schedules']) for c in candidate['courses']),'meetings':sum(len(c['schedules']) for c in candidate['courses']),'old878ScheduledPrefixPreserved':True,'old2602MeetingsPreserved':True,'nativeClosed132':sum(any(v['values'][20] or v['values'][21] for v in c['metadata']['originalEducationalRecords']) for c in candidate['courses']),'excludedDates':sorted(excluded),'start':'2026-09-01','end':'2026-12-07','midtermDatesInvented':False,'actualAttendanceConfirmed':False,'holdsByReason':dict(collections.Counter(h for a in audits for h in a['newHoldReasons'])),'courseAudits':audits,'actualFixture':'pending; no SDK used'}
proof['reservationScope'] = {'start':'2026-09-01','end':'2026-12-07','meaning':'published ordinary weekly reservation plan; individually confirmed attendance dates not claimed','excludedDates':sorted(excluded)}
for name, data in [('suwon-unknown-2026-2.full-term-ordinary-v3.json',candidate),('audit.json',audit),('educational-proof.json',proof)]:
    (ROOT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print({k:v for k,v in audit.items() if k not in ['courseAudits']})
