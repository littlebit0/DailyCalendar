import pathlib,json,copy,shutil,datetime
p=pathlib.Path('work/university-research/catalog-c/skku-held-own-operation-v48-20261009');old=p.parent/'skku-held-own-operation-v47-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v47.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json');a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');keys=['DAT2054-01','FTM2045-02'];rs={x['offeringCode']:x for x in a['records'] if x['offeringCode'] in keys};write('source-current-attachment-identity.json',{'records':list(rs.values()),'sourceOnly':True});ds=copy.deepcopy(bs);proof=[]
dates={'DAT2054-01':['09-01','09-08','09-15','09-22','09-29','10-06','10-13','10-20','10-27','11-03','11-10','11-17','11-24','12-01','12-08'],'FTM2045-02':['09-03','09-10','09-17','10-01','10-08','10-15','10-22','10-29','11-05','11-12','11-19','11-26','12-03','12-10','12-17']}
for c in [x for d in ds.values() for x in d['courses']]:
 key=c['courseCode']+'-'+c['section']
 if key not in keys:continue
 prior=copy.deepcopy(c);r=rs[key];f=read(p/(key.lower()+'-full-education.json'));t=f['educationFullText'];assert key in t and '2026년 2학기' in t and f['fullEducationalTextRead'] and f['fontUnicodeRepair']['ownFontOrderingVerified'];assert not c['schedules'];assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];assert r['detail'][0]['BUNBAN']==c['section'];plans=[]
 for md in dates[key]:
  date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert len(frames)==2;plans.extend({**x,'date':date.isoformat(),'deliveryMode':'inPerson'} for x in frames)
 note='자체2026년2학기 '+key+' 강의계획 전체2쪽의정확학수번호분반/요일HH/literal일반수업15일과오프라인 직접명시를검증했습니다. PDF자체Korea1 Ordering 확인후설치된Adobe-Korea1 Unicode표로글꼴문자만결정복구/언어추정0. native2개75분HH각각그대로 planned대면30개, 교수·수업교실은원문미인쇄/native현재배정만사용하며실제current분반공개첨부association exact. DAT12/15보강주차는실제수업내용미확정으로예약0, FTM9/24휴강0. 원문명시일반수업Oct20/22/Dec17은공통시험주와별개plannedordinary/실제시험시간발명0. 전체제출발표평가진행변경조건보존/partialCoverage=true/actualattendancefalse/ordinal추정0/과목간교수및clock차용0.'
 c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV48']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'sourceActualLiteralDates':dates[key],'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':True,'ownProfessorPrinted':False,'nativeProfessorUnchanged':prior['professor'],'ownHHPrinted':True,'ownClassroomPrinted':False,'classroomFromCurrentNativeOnly':True,'primaryJoinExactCodeSectionSemesterHHObservedAttachment':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'heldDates':{'12-15':'DAT only: makeup week no assigned actual ordinary class','09-24':'FTM only: Chuseok no class'}};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':plans})
for camp in ds:
 if any(c['courseCode']+'-'+c['section'] in keys for c in ds[camp]['courses']):write(f'skku-{camp}-2026-2.own-operation-v48.json',ds[camp])
# Independent literal dates and independently stated own/native classroom and split frames.
literals={'DAT2054-01':(['2026-09-01','2026-09-08','2026-09-15','2026-09-22','2026-09-29','2026-10-06','2026-10-13','2026-10-20','2026-10-27','2026-11-03','2026-11-10','2026-11-17','2026-11-24','2026-12-01','2026-12-08'],2,[(720,795),(810,885)],'61801'),'FTM2045-02':(['2026-09-03','2026-09-10','2026-09-17','2026-10-01','2026-10-08','2026-10-15','2026-10-22','2026-10-29','2026-11-05','2026-11-12','2026-11-19','2026-11-26','2026-12-03','2026-12-10','2026-12-17'],4,[(900,975),(990,1065)],'61415')}
for row in proof:
 dd,w,frames,room=literals[row['offeringCode']];expected=[]
 for date in dd:
  assert datetime.date.fromisoformat(date).isoweekday()==w
  for start,end in frames:expected.append({'weekday':w,'startMinute':start,'endMinute':end,'classroom':room,'date':date,'deliveryMode':'inPerson'})
 assert expected==row['expectedSchedulesLiteral'];row['expectedSchedulesLiteral']=expected
count=meetings=other=0
for camp in bs:
 for x,y in zip(bs[camp]['courses'],ds[camp]['courses']):
  if x['courseCode']+'-'+x['section'] not in keys:assert x==y;other+=1
  if x['schedules']:count+=1;meetings+=len(x['schedules'])
assert (other,count,meetings)==(2780,1797,49364)
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':proof,'priorWholeCourses':1797,'priorMeetings':49364,'unchangedOtherWholeObjects':2780,'newWholeCourses':2,'newMeetings':60,'resultWholeCourses':1799,'resultMeetings':49424,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True});write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'newCourses':2,'newMeetings':60,'completionClaim':False});print('PASS2/60=>1799/49424 allother2780exact')
