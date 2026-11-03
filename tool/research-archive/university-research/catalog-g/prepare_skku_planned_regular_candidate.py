"""Current published timetable baseline; never confirms individual attendance.
Preserve r21 individual evidence exactly. No network or production writes.
"""
import ast
import collections
import copy
import datetime
import hashlib
import json
import re
from pathlib import Path

P = Path(__file__).resolve().parent
CHECKPOINT = '20261008-r23'
CAMPUSES = ['humanities', 'naturalScience', 'icampus']
CLOCK = re.compile(r'([월화수목금토일])(?:\[[^\]]*\])?(\d{2}):(\d{2})[-~](\d{2}):(\d{2})')
# Screening flags are unresolved evidence, not automatically proved cancellations.
SIGNAL = re.compile(r'휴강|휴업|보강|수업\s*(?:없|안)|강의\s*없|no\s+(?:class|lecture)|cancel.{0,15}(?:class|lecture)|make[- ]?up|reschedul|집중|모듈|module\s*[ABCD1-4]|field\s*(?:trip|visit|work|placement)|답사|견학|현장실습|임상실습|인턴|교외|개별연구|비대면|화상|zoom|remote|온라인|online|계절|summer|winter|spring|202[0-57-9].{0,15}(?:학기|semester|fall|spring)|(?:수업|강의|요일|시각|시간|장소).{0,15}변경', re.I)
TERM_CONFLICT = re.compile(r'(?:학년도\s*[/·]?\s*학기.{0,25}|2026\s*(?:학년도|년도|년)?\s*[/.-]?\s*)1\s*학기|(?:academic\s*(?:year|term)|semester).{0,40}2026.{0,20}(?:spring|first)|2026\s*(?:[./-]|년)\s*0?[1-7]\s*(?:[./-]|월)\s*\d{1,2}|(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?)\.?\s*\d{1,2}\b', re.I)
PLACEMENT = re.compile(r'clinical\s+practice|individual\s+research|hospital.{0,40}practice|약국.{0,30}실습|병원.{0,30}실습|preceptor|실험실.{0,30}배정|laboratory.{0,30}(?:placement|assignment)|현장|실습', re.I)


def read(name):
    return json.loads((P / name).read_text())


def frames(value):
    return sorted((m[1], int(m[2])*60+int(m[3]), int(m[4])*60+int(m[5])) for m in CLOCK.finditer(value))


def immutable(path, value):
    body = (json.dumps(value, ensure_ascii=False, indent=2)+'\n').encode()
    if path.exists() and path.read_bytes() != body:
        raise ValueError('Immutable filename differs; choose a new checkpoint: '+str(path))
    if not path.exists():
        path.write_bytes(body)
    return hashlib.sha256(body).hexdigest()


def main():
    scope = read('skku-final-current-scope-check.json')
    assert scope['currentCensusCompleted'] and scope['scopeStable'] and not scope.get('knownCancelledStillPresent')
    current = {r['HAKSU_NO_BUNBAN']: r for r in read('skku-final-current-educational-source.json')['records'] if r['JUKYONGHAKWI_GB'] != '05'}
    evidence = {r['offeringCode']: r for r in read('skku-public-operating-plan-audit.json')['records']}
    tree = ast.parse((P/'prepare_skku_reviewed_ordinary_draft.py').read_text())
    blocked = next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign) and any(isinstance(x, ast.Name) and x.id == 'BLOCKED' for x in n.targets))
    rules = read('skku-current-term-closure-rule-evidence.json')
    start = datetime.date.fromisoformat(rules['term']['startDate'])
    end = datetime.date.fromisoformat(rules['term']['endDate'])
    closed = set(rules['nationalHolidayDates']['dates']) | set(rules['closureRule']['schoolSpecificClosures'])
    manifest = {'universityId':'skku','semester':'2026-2','completionClaim':False,'wholeOperatingAuditFinished':False,'wholeCurrentDetailsFetched':True,'currentCensusCompleted':True,'currentCensusStable':True,'currentWholeCensusCheckedAt':scope['checkedAt'],'wholeCurrentCount':2782,'excludedGraduateOnly05':32,'actualAttendanceConfirmed':False,'registrationScope':'Preserved r21 individually reviewed dates plus current school-published planned regular timetable. Planned times do not confirm actual attendance or individual exam dates.','policyReview':'skku-regular-published-timetable-policy-review-20261008.md','campuses':[]}
    decisions = []
    counts = collections.Counter()
    original_preserved = 0
    planned = 0
    for campus in CAMPUSES:
        old = read(f'skku-{campus}-2026-2.partial-audited-20261008-r21.json')
        preserved = {c['courseCode']+'-'+c['section']:c for c in old['courses'] if c['scheduleStatus']=='scheduled'}
        data = read(f'skku-{campus}-2026-2.metadata-safe-unregistered.json')
        for i, course in enumerate(data['courses']):
            key = course['courseCode']+'-'+course['section']
            row = current[key]
            r = evidence[key]
            detail = r['detail'][0] if r['detail'] else {}
            assert course['sourceSchedule'] == row['GYOSI_NAME'] and course['professor'] == row['PER_NAME']
            if key in preserved:
                data['courses'][i] = copy.deepcopy(preserved[key])
                original_preserved += 1
                decisions.append({'offeringCode':key,'decision':'preservedR21IndividualEvidence','actualAttendanceConfirmed':False})
                continue
            reasons = []
            raw = course['rawMeetingFrameForReviewOnly']
            if not raw:
                course['scheduleStatus']='unscheduled'
                decisions.append({'offeringCode':key,'decision':'noPublishedFixedClock','actualAttendanceConfirmed':False})
                continue
            if key in blocked:
                reasons.append({'kind':'individuallyReviewedOperatingException','basis':blocked[key]})
            if row['SUUP_TYPE_CD'] not in ('31','33'):
                reasons.append({'kind':'nonPhysicalOrUnmappedSourceMode','sourceType':row['SUUP_TYPE_CD']})
            if row['HAKBU_JIBJUNG_GB'] != 'N':
                reasons.append({'kind':'concentratedPeriodNeedsSpecificDates'})
            if not r['currentDetailIdentityConfirmed'] or not detail or frames(row['GYOSI_NAME']) != frames(detail.get('SUUP_YOIL_GYOSI','')) or detail.get('PER_NAME','').strip() != row['PER_NAME'].strip():
                reasons.append({'kind':'currentIdentityTeacherClockConflict'})
            if not all(f['classroom'] and '미지정' not in f['classroom'] for f in raw):
                reasons.append({'kind':'missingPublishedRoom'})
            residual = re.sub(r'([월화수목금토일])(\d{2}):(\d{2})-(\d{2}):(\d{2})【([^】]+)】','',row['GYOSI_NAME'])
            residual = re.sub(r'【[\d.]+h\(ON\)\+[\d.]+h\(OFF\)】','',residual).strip(', ')
            if residual:
                reasons.append({'kind':'moduleOrUnparsedScheduleToken','token':residual})
            if row['SUUP_TYPE_CD']=='33' and not any(x in row['GYOSI_NAME'] for x in ('h(ON)+1.5h(OFF)','1h(ON)+2h(OFF)','1h(ON)+3h(OFF)[4시간]')):
                reasons.append({'kind':'flippedPhysicalPartNotMapped'})
            sources = [('courseName',row['GWAMOK_NAME']),('sourceRemarks',row.get('BIGO','')),('method',detail.get('CLASS_INFO','')),('detailRemarks',detail.get('BIGO',''))]
            sources += [('weekly:'+str(w['PLAN_WEEK_CNT']),w.get('PLAN_WEEK_CONT','')+' '+w.get('BIGO','')) for w in r['weekly']]
            sources += [('attachmentEducationalContext',x) for a in r['attachments'] for x in a.get('educationalOperatingContexts',[])]
            flags=[]
            for source,text in sources:
                for pattern in (SIGNAL,PLACEMENT,TERM_CONFLICT):
                    for match in pattern.finditer(text):
                        flags.append({'field':source,'signal':match.group()})
            if flags:
                reasons.append({'kind':'unreviewedOperatingContextSignal','signals':flags})
            if any(x.get('privacySuppressedLineCount') for x in [detail]+r['weekly']) or any(a.get('privacySuppressedLineCount') or a.get('contextLimitReached') or a.get('contextTruncated') for a in r['attachments']):
                reasons.append({'kind':'filteredEducationalContextIncomplete'})
            if reasons:
                course['scheduleStatus']='unrecognized';course['schedules']=[]
                course['unresolvedReasons']=[x['kind'] for x in reasons]
                decisions.append({'offeringCode':key,'decision':'unresolvedSpecificOperatingOrSourceEvidence','reasons':reasons,'actualAttendanceConfirmed':False})
                continue
            meetings=[]
            day=start
            while day<=end:
                if day.weekday()!=6 and day.isoformat() not in closed:
                    meetings.extend({**f,'date':day.isoformat()} for f in raw if f['weekday']==day.isoweekday())
                day+=datetime.timedelta(days=1)
            assert meetings
            course.update({'scheduleStatus':'scheduled','schedules':meetings,'period':{'startDate':start.isoformat(),'endDate':end.isoformat()},'unresolvedReasons':[],'researchOnly':False,'scheduleEvidenceKind':'plannedRegularTimetable','actualAttendanceConfirmed':False,'operatingReviewBasis':'Current published normal physical timetable identity, teacher, original clock and room; official term/closure policy; no specific unresolved operating conflict in collected educational evidence. This is a planned class slot, not a confirmed individual attendance/exam.','commonClosureDatesApplied':True,'sourceEducationalOperatingEvidenceReference':{'file':'skku-public-operating-plan-audit.json','offeringCode':key,'detailInputType':detail.get('INPUT_TYPE_GB'),'weeklyTopicPresenceRequired':False}})
            for department,note in course['departmentRemarks'].items():
                course['departmentRemarks'][department]=note.replace('수업 운영 미확인: 실제 날짜·수업 방식·휴강·보강을 확인 중입니다.','학교 공시 정규 수업시간에 학기·휴업일을 적용했습니다. 실제 휴·보강 및 시험 시간은 학교 공지를 확인하세요.')
            planned+=1
            decisions.append({'offeringCode':key,'decision':'plannedRegularTimetable','actualAttendanceConfirmed':False,'plannedMeetingCount':len(meetings),'emptyTopicsDoNotCancelPublishedTime':True,'genericExamDoesNotCancelPublishedTime':True})
        campuscounts=collections.Counter(c['scheduleStatus'] for c in data['courses']);counts.update(campuscounts)
        data.update({'researchOnly':False,'productionActivationAllowed':True,'completionClaim':False,'wholeOperatingAuditFinished':False,'wholeCurrentDetailsFetched':True,'wholeCurrentCensusStable':True,'wholeCurrentCensusCheckedAt':scope['checkedAt'],'actualAttendanceConfirmed':False,'partialOperatingRegistration':True,'commonClosurePolicySource':rules,'registrationBoundaries':manifest['registrationScope']})
        path=P/f'skku-{campus}-2026-2.partial-audited-{CHECKPOINT}.json'
        digest=immutable(path,data)
        manifest['campuses'].append({'campus':campus,'campusName':data['campusName'],'path':str(path),'sha256':digest,'courseCount':len(data['courses']),'scheduleCounts':dict(campuscounts)})
    assert original_preserved==422 and len(decisions)==2782
    manifest.update({'counts':dict(counts),'verifiedScheduledCourseCount':counts['scheduled'],'preservedR21IndividualEvidenceCount':422,'plannedRegularTimetableCount':planned,'notApprovedForDatedMeetingsCount':2782-counts['scheduled'],'scopeDecisionCounts':dict(collections.Counter(x['decision'] for x in decisions))})
    immutable(P/f'skku-partial-audited-{CHECKPOINT}-sha-manifest.json',manifest)
    immutable(P/f'skku-planned-regular-{CHECKPOINT}-scope-decisions.json',{'researchOnly':True,'actualAttendanceConfirmed':False,'decisions':decisions})
    print({k:v for k,v in manifest.items() if k in ('counts','preservedR21IndividualEvidenceCount','plannedRegularTimetableCount','scopeDecisionCounts')})

if __name__=='__main__':
    main()
