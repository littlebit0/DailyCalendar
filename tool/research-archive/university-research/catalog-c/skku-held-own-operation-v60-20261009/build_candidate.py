import pathlib,json,copy,shutil,datetime
p=pathlib.Path(__file__).parent;old=p.parent/'skku-held-own-operation-v57-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v57.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
loc={r['offeringCode']:r for r in read(p/'current-primary-public-locators.json')['records']};keys=list(loc);a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');rs={x['offeringCode']:x for x in a['records'] if x['offeringCode'] in keys};write('source-current-attachment-identity.json',{'sourceOnly':True,'records':list(rs.values())});ds=copy.deepcopy(bs);proof=[]
dates={'GEDC010-02':['09-07','09-14','09-21','10-26','11-02','11-09','11-16','11-23','11-30','12-07']}
for c in [x for d in ds.values() for x in d['courses']]:
 key=c['courseCode']+'-'+c['section']
 if key not in keys:continue
 prior=copy.deepcopy(c);f=read(p/(key.lower()+'-full-education.json'));l=loc[key];r=rs[key];assert not c['schedules'] and l['currentLocatorBytesEqualFrozenEducation'];row=l['actualObservedCurrentFileRows'][0];assert (row['GAESUL_YEAR'],row['GAESUL_TERM'],row['HAKSU_NO'],row['BUNBAN'])==('2026','20',c['courseCode'],c['section']);assert key in l['currentNativeSameCodeSections'];plans=[]
 for md in dates[key]:
  date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames;plans.extend({**x,'date':date.isoformat(),'deliveryMode':'inPerson'} for x in frames)
 note='학교현재2026/20/GEDC010/02에직접연결된공개첨부rawSHA동일하고원문26학년도2학기/GEDC010-02/김가람실제인쇄확인. 원문10개literal오프라인날짜만native월09–09:50/10–10:50/50307현재배정으로planned예약. 원문HH/교실미인쇄사실구분/타분반시간차용0. Aug31Sep28Oct5녹화·Oct12성균관투어actualHH/venue미정·Oct19대체에세이·Dec14시험예약0. 온라인0시공개23:59마감은실시간수업시각아님. 그룹별발표세부배정·교안추후업로드·출석조건원문보존,ordinal추정0/partialCoverage=true/actualattendance확인0.'
 c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV60']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'directSchoolCurrentPrimaryLocatorEvidence':l,'sourceActualLiteralDates':dates[key],'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':True,'ownCodePrinted':True,'ownTermPrinted':True,'currentSchoolCodeSectionLocatorConfirmed':True,'bilingualIdentityConfirmed':False,'nativeProfessorUnchanged':prior['professor'],'ownHHPrinted':False,'ownClassroomPrinted':False,'primaryJoinCurrentReturnedCodeSectionLocatorRawSHA':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'otherSemesterSharingAbsentClaim':False};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':plans})
write('skku-humanities-2026-2.own-operation-v60.json',ds['humanities'])
manual={'GEDC010-02':(['2026-09-07','2026-09-14','2026-09-21','2026-10-26','2026-11-02','2026-11-09','2026-11-16','2026-11-23','2026-11-30','2026-12-07'],{1:[(540,590),(600,650)]},'50307','inPerson')}
for row in proof:
 dd,frames,room,mode=manual[row['offeringCode']];exp=[]
 for date in dd:
  w=datetime.date.fromisoformat(date).isoweekday();assert w in frames
  for s,e in frames[w]:exp.append({'weekday':w,'startMinute':s,'endMinute':e,'classroom':room,'date':date,'deliveryMode':mode})
 assert exp==row['expectedSchedulesLiteral'];row['expectedSchedulesLiteral']=exp
other=count=meetings=0
for camp in bs:
 for x,y in zip(bs[camp]['courses'],ds[camp]['courses']):
  if x['courseCode']+'-'+x['section'] not in keys:assert x==y;other+=1
  if x['schedules']:count+=1;meetings+=len(x['schedules'])
assert (other,count,meetings)==(2781,1807,49579);assert sum(len(r['expectedSchedulesLiteral']) for r in proof)==20
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':proof,'priorWholeCourses':1807,'priorMeetings':49579,'unchangedOtherWholeObjects':2781,'newWholeCourses':1,'newMeetings':20,'resultWholeCourses':1808,'resultMeetings':49599,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True});write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'newCourses':1,'newMeetings':20,'printedCodeSectionExact':True,'ownTermPrinted':True,'ownHHRoomPrinted':False,'nativeExactSectionHHRoomConfirmed':True,'allOrdinaryDatesExplicitOffline':True,'tourExamRecordedAppointmentsGenerated':False});print('PASS1/20=>1808/49599 other2781exact')
