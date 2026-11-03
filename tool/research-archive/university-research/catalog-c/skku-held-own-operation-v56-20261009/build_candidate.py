import pathlib,json,copy,shutil,datetime
p=pathlib.Path(__file__).parent;old=p.parent/'skku-held-own-operation-v55-20261009'
read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v55.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
loc={r['offeringCode']:r for r in read(p/'current-primary-public-locators.json')['records']};keys=list(loc)
a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');rs={x['offeringCode']:x for x in a['records'] if x['offeringCode'] in keys};write('source-current-attachment-identity.json',{'sourceOnly':True,'records':list(rs.values())})
ds=copy.deepcopy(bs);proof=[]
zoom=['09-10','09-17','10-08'];physical=['10-29','11-05','11-12','11-19','11-26','12-03','12-10']
cnt=['08-31','09-07','09-14','09-21','10-12','10-19','11-02','11-04','11-09','11-11','11-16','11-18','11-23','11-25','11-30','12-02','12-07','12-09']
for c in [x for d in ds.values() for x in d['courses']]:
 key=c['courseCode']+'-'+c['section']
 if key not in keys:continue
 prior=copy.deepcopy(c);f=read(p/(key.lower()+'-full-education.json'));l=loc[key];r=rs[key];assert not c['schedules'];assert l['currentLocatorBytesEqualFrozenEducation'];row=l['actualObservedCurrentFileRows'][0];assert (row['GAESUL_YEAR'],row['GAESUL_TERM'],row['HAKSU_NO'],row['BUNBAN'])==('2026','20',c['courseCode'],c['section']);assert l['currentNativeSameCodeSections']==[key]
 dates=zoom+physical if key.startswith('PSD') else cnt;plans=[]
 for md in sorted(dates):
  date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()]
  if key.startswith('PSD') and md=='12-03':frames=[x for x in frames if x['startMinute']==630]
  assert frames
  plans.extend({**x,'date':date.isoformat(),'deliveryMode':'liveOnline' if md in zoom and key.startswith('PSD') else 'inPerson'} for x in frames)
 assert len(plans)==(19 if key.startswith('PSD') else 18)
 note='학교가현재2026/20/코드분반에직접반환한개별공개첨부와전체원문SHA동일함을확인한primary연결이며제목/교수명만조인아닙니다. 원문code/section미인쇄·교수영한alias미확인사실보존. 원문literal일반수업날짜만nativeHHplanned예약,ordinal/요일추정날짜0,녹화/시험/제출전용예약0. PSD 자체Fall2026/목HH/61604표기·Zoom3일각2회·대면6일각2회·Dec3는10:30단일1회명시. 녹화3/4·live총횟수서술불일치와최종시험Recorded/inperson충돌모두교육원문보존/시험예약0. CNT 학기/연도/code/section/HH/교실자체미인쇄이며2026연구경력을학기근거사용0. 현재학교직접첨부연결이학기identity근거;원문MMDD/16주수업계획과현재2026원래요일/기간/현재nativeMonWed교시를독립대조했습니다. 일반offline명시18회만반영,시험Oct26·16주최종제출·모든녹화예약0. 향후수정가능조건및발표대상개별배정조건보존;partialCoverage=true/actualattendance확인0/상대강좌clock차용0.'
 c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV56']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'directSchoolCurrentPrimaryLocatorEvidence':l,'sourceActualLiteralDates':dates,'sourceDateYearFromCurrentSchoolOffering':True,'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':False,'ownCodePrinted':False,'ownTermPrinted':key.startswith('PSD'),'currentSchoolCodeSectionLocatorConfirmed':True,'bilingualIdentityConfirmed':False,'nativeProfessorUnchanged':prior['professor'],'ownHHPrinted':key.startswith('PSD'),'ownClassroomPrinted':key.startswith('PSD'),'primaryJoinCurrentReturnedCodeSectionLocatorRawSHA':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'otherSemesterSharingAbsentClaim':False};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':plans})
write('skku-humanities-2026-2.own-operation-v56.json',ds['humanities'])
# Independent explicit HH and dates, no builder frame borrowing.
manualPSD=[('2026-09-10','liveOnline'),('2026-09-17','liveOnline'),('2026-10-08','liveOnline'),('2026-10-29','inPerson'),('2026-11-05','inPerson'),('2026-11-12','inPerson'),('2026-11-19','inPerson'),('2026-11-26','inPerson'),('2026-12-03','inPerson'),('2026-12-10','inPerson')]
manualCNT=['2026-08-31','2026-09-07','2026-09-14','2026-09-21','2026-10-12','2026-10-19','2026-11-02','2026-11-04','2026-11-09','2026-11-11','2026-11-16','2026-11-18','2026-11-23','2026-11-25','2026-11-30','2026-12-02','2026-12-07','2026-12-09']
for row in proof:
 exp=[]
 if row['offeringCode'].startswith('PSD'):
  for date,mode in manualPSD:
   assert datetime.date.fromisoformat(date).isoweekday()==4
   for s,e in ([(630,705)] if date=='2026-12-03' else [(540,615),(630,705)]):exp.append({'weekday':4,'startMinute':s,'endMinute':e,'classroom':'61604','date':date,'deliveryMode':mode})
 else:
  for date in manualCNT:
   w=datetime.date.fromisoformat(date).isoweekday();assert w in (1,3);s,e=(720,795) if w==1 else (810,885);exp.append({'weekday':w,'startMinute':s,'endMinute':e,'classroom':'9B215','date':date,'deliveryMode':'inPerson'})
 assert exp==row['expectedSchedulesLiteral'];row['expectedSchedulesLiteral']=exp
count=meetings=other=0
for camp in bs:
 for x,y in zip(bs[camp]['courses'],ds[camp]['courses']):
  if x['courseCode']+'-'+x['section'] not in keys:assert x==y;other+=1
  if x['schedules']:count+=1;meetings+=len(x['schedules'])
assert (other,count,meetings)==(2780,1803,49504)
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':proof,'priorWholeCourses':1803,'priorMeetings':49504,'unchangedOtherWholeObjects':2780,'newWholeCourses':2,'newMeetings':37,'resultWholeCourses':1805,'resultMeetings':49541,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True})
write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'newCourses':2,'newMeetings':37,'printedSectionExact':False,'currentSchoolCodeSectionDirectPublicLocatorSHAConfirmed':True,'PSDSourceTermHHRoomPrinted':True,'CNTSourceTermCodeHHRoomPrinted':False,'CNTCurrentTermFromDirectSchoolAssociation':True,'CNTResearch2026UsedAsTermEvidence':False,'PSDCountNarrativeConflictsPreserved':True,'examAppointmentsGenerated':False})
print('PASS 2/37 =>1805/49541; other2780 whole exact')
