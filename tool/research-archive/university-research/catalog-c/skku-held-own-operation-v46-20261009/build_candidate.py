import pathlib,json,copy,shutil,datetime
p=pathlib.Path('work/university-research/catalog-c/skku-held-own-operation-v46-20261009');old=p.parent/'skku-held-own-operation-v45-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v45.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json');a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');r=next(x for x in a['records'] if x['offeringCode']=='ENG3081-01');write('source-current-attachment-identity.json',{'records':[r],'sourceOnly':True});assert len([x for x in a['records'] if x['offeringCode'].startswith('ENG3081-')])==1
f=read(p/'eng3081-01-full-education.json');t=f['educationFullText'];assert 'ENG3081-01' in t and 'Fall  2026' in t and 'Jeong, Hyojin' in t and 'There is no midterm exam' in t;assert f['fullEducationalTextRead']
ds=copy.deepcopy(bs);c=next(x for d in ds.values() for x in d['courses'] if x['courseCode']=='ENG3081' and x['section']=='01');prior=copy.deepcopy(c);assert not c['schedules'];assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];assert r['detail'][0]['BUNBAN']=='01'
mds=['08-31','09-09','09-16','09-23','09-30','10-07','10-14','10-21','10-28','11-11','11-18','11-25','12-07','12-09'];plans=[]
for md in mds:
 date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert len(frames)==1
 plans.append({**frames[0],'date':date.isoformat(),'deliveryMode':'inPerson'})
note='원문 Fall2026 ENG3081-01 공개강의계획 전체3쪽 및 명시된 literal offline 일반수업14일만 nativeMon16:30–17:45/Wed15:00–16:15,교실31703과 정확current분반공개첨부association으로 planned대면예약했습니다. 원문자체HH/수업교실미인쇄 사실을보존하며 native현재배정만사용합니다. 원문Jeong,Hyojin/native정효진은각각보존하고영한동일인확인주장0/이름만조인0. 일반Wednesdayoffline와 Aug31/Dec7 Mondayoffline 예외 직접명시, own학교Aug31–Dec18범위. 원문중간시험없음에Oct21ordinaryoffline유지. Sep2개별offline미표기/Nov4proposal due/Dec2개별meeting feedback/Dec14finalpaper due 및녹화수업·개별출석시간unknown은예약0. 전체PBL/학습평가/출결/시간표잠정변경조건 metadata보존,partialCoverage=true,ordinal추정0,실제출석확정0.'
c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV46']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'sourceActualLiteralDates':mds,'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':True,'ownProfessorEnglish':'Jeong, Hyojin','nativeProfessorKorean':prior['professor'],'bilingualIdentityConfirmed':False,'ownHHPrinted':False,'ownClassroomPrinted':False,'classroomAndHHFromCurrentNativeOnly':True,'primaryJoinExactCodeSectionSemesterObservedAttachment':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'heldDates':{'09-02':'general Wednesday default but individual row not explicitly offline','11-04':'proposal summary due only','12-02':'individual instructor meeting actual time unknown','12-14':'final paper due'}}
write('skku-humanities-2026-2.own-operation-v46.json',ds['humanities'])
expected=[]
for date,day,start,end in [('2026-08-31',1,990,1065),('2026-09-09',3,900,975),('2026-09-16',3,900,975),('2026-09-23',3,900,975),('2026-09-30',3,900,975),('2026-10-07',3,900,975),('2026-10-14',3,900,975),('2026-10-21',3,900,975),('2026-10-28',3,900,975),('2026-11-11',3,900,975),('2026-11-18',3,900,975),('2026-11-25',3,900,975),('2026-12-07',1,990,1065),('2026-12-09',3,900,975)]:
 assert datetime.date.fromisoformat(date).isoweekday()==day;expected.append({'weekday':day,'startMinute':start,'endMinute':end,'classroom':'31703','date':date,'deliveryMode':'inPerson'})
assert plans==expected
count=meetings=other=0
for camp in bs:
 for x,y in zip(bs[camp]['courses'],ds[camp]['courses']):
  if x['sourceId']!=c['sourceId']:assert x==y;other+=1
  if x['schedules']:count+=1;meetings+=len(x['schedules'])
assert (other,count,meetings)==(2781,1795,49336)
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':[{'offeringCode':'ENG3081-01','sourceId':c['sourceId'],'expectedSchedulesLiteral':expected}],'priorWholeCourses':1795,'priorMeetings':49336,'unchangedOtherWholeObjects':2781,'newWholeCourses':1,'newMeetings':14,'resultWholeCourses':1796,'resultMeetings':49350,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True})
write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'newCourses':1,'newMeetings':14,'completionClaim':False,'printedSectionExact':True,'HHAndRoomCurrentNativeOnly':True,'sourceExplicitOffline':True})
print('PASS1/14 =>1796/49350; allother2781 whole exact')
