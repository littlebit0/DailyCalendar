import pathlib,json,copy,shutil,datetime,hashlib
p=pathlib.Path('work/university-research/catalog-c/skku-held-own-operation-v45-20261009');old=p.parent/'skku-held-own-operation-v44-20261009'
read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v44.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
audit=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');r=next(x for x in audit['records'] if x['offeringCode']=='ECO3001-01');write('source-current-attachment-identity.json',{'records':[r],'sourceOnly':True});assert len([x for x in audit['records'] if x['offeringCode'].startswith('ECO3001-')])==1
f=read(p/'eco3001-01-full-education.json');t=f['educationFullText'];assert 'ECO3001 (Fall Semester, 2026)' in t and 'Friday 09:00 – 11:45' in t and f['ownPrintedEducationalInstructorNames']==['Joosung Lee'];assert f['fullEducationalTextRead']
ds=copy.deepcopy(bs);c=next(x for d in ds.values() for x in d['courses'] if x['courseCode']=='ECO3001' and x['section']=='01');prior=copy.deepcopy(c);assert not c['schedules'];assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];assert r['detail'][0]['BUNBAN']=='01'
mds=['09-04','09-11','10-02','10-30','11-27','12-04'];plans=[]
for md in mds:
 date=datetime.date.fromisoformat('2026-'+md);assert date.isoweekday()==5
 for x in c['rawMeetingFrameForReviewOnly']:
  assert x['weekday']==5 and (x['startMinute'],x['endMinute']) in [(540,615),(630,705)] and x['classroom']=='9B208'
  plans.append({**x,'date':date.isoformat(),'deliveryMode':None})
note='자체 Fall Semester 2026 ECO3001 공개강의계획 전체3쪽 및 Friday09:00–11:45 일반 In-class 원문을 확인했습니다. current학교 동일코드 sole01과 그분반 실제공개첨부 association 및 native시간 전체범위의 독립 일치에 따른 좁은 조인입니다. 원문분반/수업교실 미인쇄, native01/9B208만 사용하며 Office90304는교실아님. 원문교육역할 Instructor의 Joosung Lee와 native이주성은각각보존/영한동일인검증주장0/이름만조인0. 원문literal일반수업6일만 native2개75분시간대 planned12개로 보존하며 원문대면/실시간명시없음에 mode=null 사용자선택준수. 녹화selfstudy,75분시험+Discussion,개별Meeting,개별개발가능Nov20,NoClass/기말제출 등은실제수업예약으로확정하지않았습니다. 전체평가/교과운영변경/팀연구/후속URP조건과원문교육본문 metadata보존,partialCoverage=true,실제출석확정0,ordinal달력추정0.'
c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()}
c['reservationEvidenceV45']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'sourceActualLiteralDates':mds,'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':False,'ownProfessorEnglish':'Joosung Lee','nativeProfessorKorean':prior['professor'],'bilingualIdentityConfirmed':False,'primaryJoinExactCodeCurrentSoleSectionSemesterHHObservedAttachment':True,'ownClassroomPrinted':False,'classroomFromCurrentNativeOnly':True,'uniqueJoinNotTitleOnly':True,'ordinalProjectionApplied':False,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'heldDates':{'09-18':'75 minute exam + discussion allocation unknown','10-16':'75 minute exam + discussion allocation unknown','11-06':'75 minute exam + discussion allocation unknown','11-13':'individual meeting time unknown','11-20':'project development individual allocation unclear','09-25':'No Class','10-09':'No Class','10-23':'No Class','12-11':'No Class','12-18':'No Class'},'sourceModeNotRewritten':True}
for camp,d in ds.items():
 if any(x['courseCode']=='ECO3001' for x in d['courses']):write(f'skku-{camp}-2026-2.own-operation-v45.json',d)
# Independent manually specified dates and native frame literals, separate from source-generation loop.
expected=[{'weekday':5,'startMinute':a,'endMinute':b,'classroom':'9B208','date':date,'deliveryMode':None} for date in ['2026-09-04','2026-09-11','2026-10-02','2026-10-30','2026-11-27','2026-12-04'] for a,b in [(540,615),(630,705)]]
assert plans==expected
count=meetings=other=0
for camp in bs:
 for a,b in zip(bs[camp]['courses'],ds[camp]['courses']):
  if a['sourceId']!=c['sourceId']:assert a==b;other+=1
  if a['schedules']:count+=1;meetings+=len(a['schedules'])
assert (other,count,meetings)==(2781,1794,49324)
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':[{'offeringCode':'ECO3001-01','sourceId':c['sourceId'],'expectedSchedulesLiteral':expected}],'priorWholeCourses':1794,'priorMeetings':49324,'unchangedOtherWholeObjects':2781,'newWholeCourses':1,'newMeetings':12,'resultWholeCourses':1795,'resultMeetings':49336,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True})
write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'newCourses':1,'newMeetings':12,'completionClaim':False,'primaryJoinNotNameOnly':True,'missingPrintedSectionAndClassroomPreserved':True,'roleNameRecoveredWithoutContact':True,'unknownModeNull':True})
print('PASS 1/12 => 1795/49336; 2781 other whole objects preserved')
