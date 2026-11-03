"""Do not extrapolate two published contract offerings to all BU period clocks."""
import copy
import hashlib
import json
import pathlib
P = pathlib.Path(__file__).resolve().parent
base = json.loads((P / 'bu-current-whole-ordinary-app-notes-next-20261008.json').read_text())
allowed = {'08544-31':(540,650,'진리311'),'30188-03':(840,950,'진리506')}
courses = copy.deepcopy(base['courses'])
for c in courses:
    key = c['courseCode']+'-'+c['section']
    c['campus'] = 'unknown'
    c['sourceId'] = f"baekseok/unknown/2026/2/{c['courseCode']}/{c['section']}"
    original = c['sourceEducationalMetadata']['departmentRemarks']
    if key in allowed:
        a,b,room = allowed[key]
        assert len(c['schedules']) == 13
        for meeting in c['schedules']:
            assert (meeting['startMinute'],meeting['endMinute'],meeting['classroom'],meeting['weekday'])==(a,b,room,2)
            meeting.pop('deliveryMode',None)
        note = '학교 공시의 정규 수업 계획입니다. 같은 과목·교수·강의실·요일·교시가 현재 계약학과 시간표와 일치합니다. 입시 기간 VOD 수업과 12월 8·9일 금요일 보강 편성은 화요일 반복으로 만들지 않습니다. 기말시험 시각은 별도 확인이 필요합니다. 공개 강의실을 보존했으며 이후 변경 여부는 학교 공지에서 확인해 주세요.'
        if key=='30188-03':note+=' 일부 계약학과는 학교가 별도 지정한 수강 대상에 해당해야 합니다.'
        c['scheduleEvidenceKind']='publishedExactOfferingClockAndCentralRegularPlan'
        c['sourceClockProof']='https://early.bu.ac.kr/boardfiledownload.do?seq=30'
        c['actualAttendanceConfirmed']=False
        c['individualWeeklyOperationConfirmed']=False
    else:
        c['schedules']=[]
        c.pop('period',None)
        if c['scheduleStatus']=='scheduled':c['scheduleStatus']='unrecognized'
        note='학교 전체 교시 시각과 개별 운영·변경 사항을 검증하기 전으로 시간표 자동 추가를 보류합니다.'
        if '현재 폐강' in str(c.get('remarks','')):note+=' 현재 폐강된 강좌입니다.'
    c['departmentRemarks']={dept:('\n'.join(x for x in [original.get(dept,''),note] if x)) for dept in c['departments']}
    c.pop('remarks',None)
output={'schemaVersion':2,'universityId':'baekseok','campus':'unknown','campusName':'위치 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-10-08','sourceUrl':'https://www.bu.ac.kr/bbs/web/788/58368/artclView.do','completionClaim':False,'wholeOperatingAuditFinished':False,'finalRoomChangesVerified':False,'currentFullOfferingScopeVerified':False,'courses':courses}
file=P/'baekseok-unknown-2026-2.two-exact-reviewed-next.json'
file.write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
counts={k:sum(c['scheduleStatus']==k for c in courses) for k in ['scheduled','unrecognized','unscheduled']}
audit={'candidate':file.name,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'wholeSourceRows':len(courses),'counts':counts,'datedMeetings':sum(len(c['schedules']) for c in courses),'exactApprovedIds':list(allowed),'clockExtrapolationToOtherCourses':False,'productionRegistered':False,'completionClaim':False,'currentContractPDFRecheckedSHA256':'a6d01b3ccfa962f02f3d5312da71043b86581fd85c1c522d04052c71581da06b','jointIdentityFields':['courseName','professor','classroom','weekday','periodSpan'],'centralFinalRoomChangesPublished':False}
(P/'baekseok-two-exact-reviewed-next-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(audit,ensure_ascii=False))
