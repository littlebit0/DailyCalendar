"""Use original public native clocks only; retain unknown operation/campus claims."""
from pathlib import Path
import collections
import copy
import datetime as dt
import hashlib
import json
import re
D=Path(__file__).resolve().parent
C=D.parent
R=D.parents[4]
base_path=C/'ssu-main-2026-2.whole2219-partial-dated-v3.json'
raw_path=R/'work/university-research/catalog-c/ssu-all-2026-2.json'
base=json.loads(base_path.read_text())
raw=json.loads(raw_path.read_text())
candidate=copy.deepcopy(base)
head=re.compile(r'([월화수목금토일](?:\s+[월화수목금토일])*)\s+(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(')
def parse(text, professor):
    pos=0
    results=[]
    while pos<len(text):
        while pos<len(text) and text[pos] in ' ,\t\n':pos+=1
        if pos==len(text):break
        m=head.match(text,pos)
        if not m:return None
        idx=m.end()
        depth=1
        while idx<len(text) and depth:
            if text[idx]=='(':depth+=1
            if text[idx]==')':depth-=1
            idx+=1
        if depth:return None
        raw_room=text[m.end():idx-1].strip()
        professorNames=sorted(set([professor]+professor.split()),key=len,reverse=True)
        suffix=next(('-'+name for name in professorNames if name and raw_room.endswith('-'+name)),None)
        if suffix is None:return None
        room=raw_room[:-len(suffix)].strip()
        if not room:return None
        start=int(m[2])*60+int(m[3]);end=int(m[4])*60+int(m[5])
        if not 0<=start<end<=1440:return None
        for day in m[1].split():results.append({'weekday':'월화수목금토일'.index(day)+1,'startMinute':start,'endMinute':end,'classroom':room})
        pos=idx
    unique=[]
    for meeting in results:
        if meeting not in unique:unique.append(meeting)
    for i,first in enumerate(unique):
        for second in unique[i+1:]:
            if first['weekday']==second['weekday'] and first['startMinute']<second['endMinute'] and second['startMinute']<first['endMinute']:return None
    return unique or None
allowed=['이수구분(주전공)','이수구분(다전공)','공학인증','과목번호','과목명','수강유의사항','강좌유형정보','분반','교수명','개설학과','시간/학점(설계)','강의시간(강의실)','수강대상','교과영역']
def clean(value):
    for pattern in [r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}',r'(?<!\d)0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)',r'https?://[^\s<>]+']:
        value=re.sub(pattern,'[연락·접속 정보 제외]',value)
    return value
plans={}
for name in ['ssu-current-public-korean-major-plans-20261008.json','ssu-current-public-korean-major-next20-plans-20261008.json']:
    for plan in json.loads((C/name).read_text())['publicTeachingFields']:plans[plan['nativeCourseId']]=plan
start,end=dt.date(2026,9,1),dt.date(2026,12,21)
excluded={dt.date(2026,9,d)for d in [24,25,26]}|{dt.date(2026,10,d)for d in [3,5,9]}|{dt.date(2026,12,d)for d in range(8,22)}
classification=[]
receipts=[]
for before,course in zip(base['courses'],candidate['courses']):
    cid=course['sourceEducation']['nativeTenDigitCourseId']
    rows=course['sourceEducation']['allPublicQueryEducation']
    assert rows==[{k:clean(r[k])for k in allowed if k in r}for r in raw['recordsByCode'][cid]]
    assert len({(r['과목名']if '과목名'in r else r['과목명'],r['교수명'],r['시간/학점(설계)'],r['강의시간(강의실)'])for r in rows})==1
    geometry=parse(course['sourceSchedule'],course['professor'])
    reasons=[]
    if before['schedules']:status='existing17DatedPreserved'
    else:
        if any('녹화'in r['강좌유형정보']for r in rows):reasons.append('explicitRecordedOrMixedRecordedSourceType')
        if not geometry:reasons.append('actualClockRoomOrProfessorSuffixAllocationUnresolved')
        text=' '.join(r.get('수강유의사항','')+' '+r.get('수강대상','')for r in rows)
        special=re.search(r'집중\s*(?:이수|수업|강의)|격주|원격\s*(?:수업|강의)|온라인\s*(?:수업|강의)|녹화|별도\s*(?:시간|배정)|자율\s*(?:학습|수업)',text)
        if special:reasons.append('nativeIndividualSpecialOperatingCondition')
        plan=plans.get(cid)
        if plan:
            assert plan['academicYear']==2026 and plan['semester']=='2' and plan['numericSection']==course['section']
            # Known per-course exams/video/self-study with unfinished day/allocation need their own semantic pass.
            if re.search(r'고사|시험|자율학습|동영상\s*(?:강의|학습)|학습\s*영상|녹화|온라인\s*강의|비대면|휴강|보강|격주|집중',plan['weeklyTeachingPlan']):
                reasons.append('currentIndividualPlanExamOrSpecialOperationNeedsExactExclusions')
        status='heldKnownOrUnreviewedException'if reasons else'ordinaryNativeWeeklyReservation'
    classification.append({'nativeCourseId':cid,'sourceId':course['sourceId'],'status':status,'reasons':reasons,'originalSourceSchedule':course['sourceSchedule'],'sourceLectureTypes':sorted({r['강좌유형정보']for r in rows})})
    if status!='ordinaryNativeWeeklyReservation':
        assert course==before
        continue
    schedules=[]
    for offset in range((end-start).days+1):
        date=start+dt.timedelta(days=offset)
        if date in excluded:continue
        for meeting in geometry:
            if date.isoweekday()==meeting['weekday']:schedules.append({**meeting,'date':date.isoformat()})
    assert schedules
    course['schedules']=schedules
    course['scheduleStatus']='scheduled'
    course['period']={'startDate':str(start),'endDate':str(end)}
    note='현재2026-2 공개native요일·정확시각·강의실과 자체9/1개강~12/21종강 범위의 정규 주간 예약입니다. 개별원문에 직접 게시된 실제출석 날짜가 아닙니다. 직접기말12/8~14·보강주12/15~21·공휴일은 정규예약에서 제외하며 시험/보강 시각은 추정하지 않습니다. 자체중간시험일이 미게시이므로 주차번호로 날짜를 만들지 않았습니다. 원문에 알려진 녹화/혼합녹화 및 개별시험/영상/자율학습 등 운영예외는 별도 보류했습니다. 사용자3종강의방식 유지. 기존main은본교식별이며 강좌별물리캠퍼스·누적폐강전체·당일전체재조회·실제출석확정은 미확인입니다.'
    course['remarks']=note
    old='현재 공개 강의의 수강 조건을 보존했습니다. 개별 수업 운영 검토 전으로 자동 시간표 추가는 아직 지원하지 않습니다.'
    course['departmentRemarks']={k:v.replace(old,note)for k,v in course['departmentRemarks'].items()}
    course['reservationEvidence']={'dateMeaning':'derivedRegularWeeklyReservationNotSourcePublishedAttendance','sourceWeekIndexUsed':False,'sourcePublishedIndividualDatesClaim':False,'nativeTenDigitCourseId':cid,'parsedNativeWeeklyGeometry':geometry,'ownTermStart':str(start),'ownTermEnd':str(end),'physicalCampusClaim':False,'individualNumericSectionPrintClaim':course['sourceEducation']['directNumericSectionIndividuallyPrinted']}
    receipts.append({'nativeCourseId':cid,'sourceId':course['sourceId'],'originalNativeTeachingRows':rows,'sourceGeometry':geometry,'reservationCount':len(schedules),'currentWholeDayRecheckClaim':False,'sourceIndividualAttendanceClaim':False})
    for field in ['sourceId','courseCode','section','courseName','professor','campus','credits','classification','departmentClassifications','departmentCredits','sourceSchedule','sourceClassroom','sourceEducation']:
        assert course.get(field)==before.get(field)
candidate.update(researchOnly=True,productionIntegrationEnabled=False,completionClaim=False,wholeUniversitySupportComplete=False,candidateRevision='native-weekly-reservations-v4')
p=D/'ssu-main-2026-2.whole2219-weekly-reservations-v4.json';p.write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
for name,value in [('all2219-classification-v4.json',classification),('ordinary-native-teaching-receipts-v4.json',receipts)]:
    (D/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
audit={'researchOnly':True,'completionClaim':False,'impossibleClaim':False,'baseFile':str(base_path.relative_to(R)),'baseSHA256':sha(base_path),'candidateFile':p.name,'candidateSHA256':sha(p),'nativeWhole':2219,'prior17Courses121MeetingsDeepEqual':True,'newReservationCourses':len(receipts),'newReservationMeetings':sum(r['reservationCount']for r in receipts),'totalScheduled':sum(bool(c['schedules'])for c in candidate['courses']),'totalMeetings':sum(len(c['schedules'])for c in candidate['courses']),'classificationCounts':dict(collections.Counter(r['status']for r in classification)),'heldReasonCountsOverlapping':dict(collections.Counter(reason for r in classification for reason in r['reasons'])),'sourceRawFile':str(raw_path.relative_to(R)),'sourceRawSHA256':sha(raw_path),'all5561WhitelistedNativeQueryRowsIndependentlySame':True,'globalExcludedDates':sorted(map(str,excluded)),'calendarSourceFile':'../ssu-current-official-term-boundary-20261008.json','calendarSourceSHA256':sha(C/'ssu-current-official-term-boundary-20261008.json'),'wholeCurrentDayRecheckComplete':False,'sectionMetadataPreservedNotReinterpreted':True,'sdkCalls':0,'actualModelFixture':'not run','productEdited':False};(D/'weekly-reservation-audit-v4.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print(json.dumps(audit,ensure_ascii=False))
