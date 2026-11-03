import pathlib,json,copy,shutil,datetime
p=pathlib.Path('work/university-research/catalog-c/skku-held-own-operation-v52-20261009');old=p.parent/'skku-held-own-operation-v48-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v48.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json');a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');r=next(x for x in a['records'] if x['offeringCode']=='BIZ3019-01');write('source-current-attachment-identity.json',{'records':[r],'sourceOnly':True});assert len([x for x in a['records'] if x['offeringCode'].startswith('BIZ3019-')])==1
f=read(p/'biz3019-01-full-education.json');t=f['educationFullText'];assert 'Fall 2026 BIZ 3019' in ' '.join(t.split()) and f['ownPrintedEducationalInstructorNames']==['심수옥'];assert f['fullEducationalTextRead']
ds=copy.deepcopy(bs);c=next(x for d in ds.values() for x in d['courses'] if x['courseCode']=='BIZ3019' and x['section']=='01');prior=copy.deepcopy(c);assert not c['schedules'];assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];assert r['detail'][0]['BUNBAN']=='01'
mds=['09-02','09-09','09-16','09-23','09-30','10-07','10-14','10-21','10-28','12-09'];plans=[]
for md in mds:
 date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert len(frames)==1
 plans.append({**frames[0],'date':date.isoformat(),'deliveryMode':'inPerson'})
note='자체2026년2학기/Fall2026 BIZ3019 교수심수옥/실제current01공개첨부association+sourceWednesday10:30–11:45 offline배정 exact. 실제literalWednesday 일반수업10일만 native10:30–11:45 교실33405 planned대면. 원문Monday09–10:30는영상/리서치/팀활동으로native09–10:15와불일치하므로Monday예약0/전체clock일치주장0, source전체불일치보존. 원문분반·수업교실미인쇄/nativeonly 유지,office33313교실아님. Week10–14 Feedback/Rehearsal 일자미인쇄는ordinal계산0/개별팀실제시각미확정,원문literalDec9수요일projectpresentation은wholeWedphysical배정하의계획수업일뿐개별실제발표시간확정0. sourcepartialweekdayWednesday/partialCoverage=true/actualattendancefalse,전체프로젝트평가업데이트조건보존.'
c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV52']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'sourceActualLiteralDates':mds,'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':False,'ownProfessorEnglish':'심수옥','nativeProfessorKorean':prior['professor'],'bilingualIdentityConfirmed':False,'ownHHPrinted':True,'ownClassroomPrinted':False,'classroomAndHHFromCurrentNativeOnly':True,'primaryJoinExactCodeSectionSemesterObservedAttachment':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'heldOperationScopes':{'Monday':'native09–10:15 vsown09–10:30 discrepancy; recording/research noappointments','Weeks10–14':'feedback/rehearsal exactdates and individualslots unprinted'},'partialWeekdayExplicit':'Wednesday','wholeClockConsistentClaim':False}
write('skku-humanities-2026-2.own-operation-v52.json',ds['humanities'])
expected=[]
for date,day,start,end in [('2026-09-02', 3, 630, 705), ('2026-09-09', 3, 630, 705), ('2026-09-16', 3, 630, 705), ('2026-09-23', 3, 630, 705), ('2026-09-30', 3, 630, 705), ('2026-10-07', 3, 630, 705), ('2026-10-14', 3, 630, 705), ('2026-10-21', 3, 630, 705), ('2026-10-28', 3, 630, 705), ('2026-12-09', 3, 630, 705)]:
 assert datetime.date.fromisoformat(date).isoweekday()==day;expected.append({'weekday':day,'startMinute':start,'endMinute':end,'classroom':'33405','date':date,'deliveryMode':'inPerson'})
assert plans==expected
count=meetings=other=0
for camp in bs:
 for x,y in zip(bs[camp]['courses'],ds[camp]['courses']):
  if x['sourceId']!=c['sourceId']:assert x==y;other+=1
  if x['schedules']:count+=1;meetings+=len(x['schedules'])
assert (other,count,meetings)==(2781,1799,49424)
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':[{'offeringCode':'BIZ3019-01','sourceId':c['sourceId'],'expectedSchedulesLiteral':expected}],'priorWholeCourses':1799,'priorMeetings':49424,'unchangedOtherWholeObjects':2781,'newWholeCourses':1,'newMeetings':10,'resultWholeCourses':1800,'resultMeetings':49434,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True})
write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'newCourses':1,'newMeetings':10,'completionClaim':False,'printedSectionExact':True,'HHAndRoomCurrentNativeOnly':True,'sourceExplicitOffline':True})
print('PASS1/10 =>1800/49434; allother2781 whole exact')
