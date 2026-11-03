"""Research-only app-schema staging. Unreviewed operation remains individually blocked."""
import json,collections,datetime
from pathlib import Path
P=Path(__file__).resolve().parent
base=json.loads((P/'gachon-full-normalized-source-candidates.json').read_text())
audit=json.loads((P/'gachon-full-operating-report-audit.json').read_text())
reviews=json.loads((P/'gachon-full-operating-semantic-review.json').read_text())
proof={(r['campus'],r['sourceRow']['HAKSU_NO']):r for r in audit['reports']}
review={(r['campus'],r['officialOfferingCode']):r for r in reviews['rows']}
def write_json(path,value):
    temporary=path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value,ensure_ascii=False,indent=2))
    temporary.replace(path)

output=collections.defaultdict(list);summary=collections.Counter();gaps=[]
for course in base['courses']:
    key=(course['campusSourceCode'],course['officialOfferingCode']);p=proof.get(key);r=review.get(key)
    department=course['department'];assert department
    reasons=list(course['blockingReasons']);meetings=[];status='unrecognized'
    current_parser=p is not None and p.get('educationalParserVersion',0)>=6
    if course['schedulingDecision'] in ('asynchronousVerified','unscheduledUnposted'):
        # Previously verified actual asynchronous/no-clock semantics stay explicit,
        # but this fixture cannot grant production activation before whole audit.
        status='unscheduled'
    elif current_parser and r and r.get('sourceMeetingSemanticsApproved') and not reasons:
        meetings=[{k:v for k,v in m.items() if k in ('weekday','startMinute','endMinute','classroom','date')} for m in course['schedules']]
        if r['decision']=='current-live-weekly-frame-confirmed':
            dated=[]
            for week in p['weeklyRows']:
                begin=datetime.date(2026,*map(int,week['startMonthDay'].split('/')))
                end=datetime.date(2026,*map(int,week['endMonthDay'].split('/')))
                assert (end-begin).days==6
                for meeting in meetings:
                    date=begin+datetime.timedelta(days=(meeting['weekday']-begin.isoweekday())%7)
                    assert date<=end
                    if course['period'] is not None:
                        assert course['period']['startDate']<=date.isoformat()<=course['period']['endDate']
                    dated.append({**meeting,'date':date.isoformat(),'classroom':'','deliveryMode':'liveOnline'})
            meetings=dated
        status='scheduled' if meetings else 'unrecognized'
    else:
        if not current_parser:reasons.append('Current full operating audit parser6 evidence not yet available for this offering.')
        elif r:reasons.append(r['reason'])
        else:reasons.append('Current plan individual operating semantics not yet reviewed.')
    # The exact OT is an already independently verified dated exception, not a weekly video grid.
    if course['officialOfferingCode']=='12718001':
        e=json.loads((P/'gachon-12718001-ot-dated-evidence.json').read_text())
        assert all(e['currentReportIdentity'][k] for k in ('headerCourseCodeMatches','currentTermMatches','catalogProfessorAppearsInReport'))
        meetings=[e['dateMeetingCandidate']];status='scheduled';reasons=[]
    if status=='scheduled':assert meetings and not reasons
    if status=='unrecognized':assert not meetings
    remarks=[]
    if reasons:
        message='공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
        if current_parser and r:
            decision=r['decision']
            if decision=='mixed-video-and-in-person-slot-mapping-unresolved':message='영상 학습과 대면 수업·실습이 섞여 있어 각 요일·교시의 실제 수업 방식을 추가 확인해야 합니다.'
            elif decision=='live-lectures-with-physical-or-mixed-assessment':message='실시간 강의와 대면 평가가 함께 운영됩니다. 평가 날짜·종료 시각·장소 일부는 추가 확인이 필요합니다.'
            elif decision=='live-lecture-frame-with-assessment-clock-unresolved':message='실시간 수업은 확인했으나 평가의 실제 시각이나 진행 방식은 추가 확인이 필요합니다.'
            elif decision in ('actual-date-or-week-delivery-exception-requires-normalization','ordinary-current-operating-markers-need-review','live-title-with-per-week-operating-exceptions'):message='휴강·보강 또는 특정 주차의 수업 방식 변경이 있어 실제 날짜와 시각을 확인하고 있습니다.'
            elif decision=='individual-placement-or-service-operation-needs-proof':message='개별 실습·봉사 기간과 실제 운영 방식을 확인해야 합니다.'
        remarks.append('수업 운영 미확인: '+message)
    if r and r.get('enrollmentReview'):
        enrollment=r['enrollmentReview']
        remarks.extend(enrollment['contexts'])
        if enrollment.get('privacySuppressedContextCount') or enrollment.get('contextLimitReached') or enrollment.get('contextTruncationDetected'):
            remarks.append('수강 조건의 일부 문장은 추가 확인이 필요합니다. 공개된 조건만으로 수강 가능 여부를 확정하지 마세요.')
    if course.get('noTimedMeetingInfo'):remarks.append(course['noTimedMeetingInfo']['sourceText'])
    result={'sourceId':course['sourceId'],'universityId':'gachon','campus':course['campus'],'academicYear':2026,'semester':'2','courseCode':course['courseCode'],'section':course['section'],'courseName':course['courseName'],'professor':course['professor'],'credits':course['credits'],'sourceSchedule':course['rawSchedule'],'sourceClassroom':course['rawRoom'],'scheduleStatus':status,'schedules':meetings,'departments':[department],'departmentCredits':{department:course['credits']},'departmentClassifications':{department:course['classification']},'departmentRemarks':{department:'\n'.join(remarks)},'researchOnly':True,'unresolvedReasons':list(dict.fromkeys(reasons))}
    if course['period'] is not None:result['period']={k:course['period'][k] for k in ('startDate','endDate')}
    output[course['campus']].append(result);summary[status]+=1
    if reasons:gaps.append({'officialOfferingCode':course['officialOfferingCode'],'campus':course['campus'],'reasons':list(dict.fromkeys(reasons))})
assert sum(map(len,output.values()))==3809
for campus,courses in output.items():
    payload={'schemaVersion':2,'universityId':'gachon','campus':campus,'campusName':'글로벌캠퍼스' if campus=='global' else '메디컬캠퍼스','academicYear':2026,'semester':'2','publishedDate':datetime.date.today().isoformat(),'sourceUrl':'https://info.gachon.ac.kr/ssu/showTimetable.do','researchOnly':True,'productionActivationAllowed':False,'completionClaim':False,'currentFullOperatingAuditFinished':audit['allCurrentReportsFetched'],'courses':courses}
    write_json(P/f'gachon-{campus}-2026-2.safe-unregistered.json',payload)
manifest={'researchOnly':True,'productionActivationAllowed':False,'completionClaim':False,'wholeCount':3809,'parser6CurrentVerifiedCount':audit.get('currentParserVerifiedCount',0),'allCurrentReportsFetched':audit['allCurrentReportsFetched'],'counts':dict(summary),'campusCounts':{k:len(v) for k,v in output.items()},'blocked':gaps}
write_json(P/'gachon-safe-candidate-status.json',manifest)
print(dict(summary))
