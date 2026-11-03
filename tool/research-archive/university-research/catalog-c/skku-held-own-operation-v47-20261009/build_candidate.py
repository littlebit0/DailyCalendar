import pathlib,json,copy,shutil,datetime
p=pathlib.Path('work/university-research/catalog-c/skku-held-own-operation-v47-20261009');old=p.parent/'skku-held-own-operation-v46-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v46.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json');a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');r=next(x for x in a['records'] if x['offeringCode']=='PSY3051-01');write('source-current-attachment-identity.json',{'records':[r],'sourceOnly':True});assert len([x for x in a['records'] if x['offeringCode'].startswith('PSY3051-')])==1
f=read(p/'psy3051-01-full-education.json');t=f['educationFullText'];assert 'PSY3051-1' in t and 'Fall 2026' in t and 'Instructor: Sunkyung Yoon' in t and 'Tues/Thurs In-person Lectures' in t;assert f['fullEducationalTextRead']
ds=copy.deepcopy(bs);c=next(x for d in ds.values() for x in d['courses'] if x['courseCode']=='PSY3051' and x['section']=='01');prior=copy.deepcopy(c);assert not c['schedules'];assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];assert r['detail'][0]['BUNBAN']=='01'
mds=['09-01','09-03','09-08','09-10','09-15','09-17','09-22','09-29','10-01','10-06','10-08','10-13','10-15','10-22'];plans=[]
for md in mds:
 date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert len(frames)==1
 plans.append({**frames[0],'date':date.isoformat(),'deliveryMode':'inPerson'})
note='Source current Fall2026 PSY3051-1 ModuleC Tue/Thu In-person full seven pages read. Original literal fourteen ordinary dates only; numeric section1 to01 leading-zero normalization documented, exact current01 public attachment association. Source Instructor Sunkyung Yoon and native professor retained independently, bilingual identity unconfirmed. Own HH and classroom not printed; current native Tue13:30–14:45 Thu12–13:15 room61602 used only. Oct20 Exam1 not reserved. Oct22 Self-compassion ordinary topic separate from Oct25 report deadline. Recorded lectures, individual makeup appointments and all assessment/attendance/policy conditions preserved. No16-week expansion or ordinal calendar mapping. partialCoverage true, actual attendance unconfirmed. 원문 preserved.'
c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV47']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'sourceActualLiteralDates':mds,'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':True,'ownProfessorEnglish':'Sunkyung Yoon','nativeProfessorKorean':prior['professor'],'bilingualIdentityConfirmed':False,'ownHHPrinted':False,'ownClassroomPrinted':False,'classroomAndHHFromCurrentNativeOnly':True,'primaryJoinExactCodeSectionSemesterObservedAttachment':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'heldDates':{'10-20':'Exam1 actual examination slot not independently assigned'},'printedSectionNumericLeadingZeroNormalizationOnly':True}
write('skku-humanities-2026-2.own-operation-v47.json',ds['humanities'])
expected=[]
for date,day,start,end in [('2026-09-01', 2, 810, 885), ('2026-09-03', 4, 720, 795), ('2026-09-08', 2, 810, 885), ('2026-09-10', 4, 720, 795), ('2026-09-15', 2, 810, 885), ('2026-09-17', 4, 720, 795), ('2026-09-22', 2, 810, 885), ('2026-09-29', 2, 810, 885), ('2026-10-01', 4, 720, 795), ('2026-10-06', 2, 810, 885), ('2026-10-08', 4, 720, 795), ('2026-10-13', 2, 810, 885), ('2026-10-15', 4, 720, 795), ('2026-10-22', 4, 720, 795)]:
 assert datetime.date.fromisoformat(date).isoweekday()==day;expected.append({'weekday':day,'startMinute':start,'endMinute':end,'classroom':'61602','date':date,'deliveryMode':'inPerson'})
assert plans==expected
count=meetings=other=0
for camp in bs:
 for x,y in zip(bs[camp]['courses'],ds[camp]['courses']):
  if x['sourceId']!=c['sourceId']:assert x==y;other+=1
  if x['schedules']:count+=1;meetings+=len(x['schedules'])
assert (other,count,meetings)==(2781,1796,49350)
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':[{'offeringCode':'PSY3051-01','sourceId':c['sourceId'],'expectedSchedulesLiteral':expected}],'priorWholeCourses':1796,'priorMeetings':49350,'unchangedOtherWholeObjects':2781,'newWholeCourses':1,'newMeetings':14,'resultWholeCourses':1797,'resultMeetings':49364,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True})
write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'newCourses':1,'newMeetings':14,'completionClaim':False,'printedSectionExact':True,'HHAndRoomCurrentNativeOnly':True,'sourceExplicitOffline':True})
print('PASS1/14 =>1797/49364; allother2781 whole exact')
