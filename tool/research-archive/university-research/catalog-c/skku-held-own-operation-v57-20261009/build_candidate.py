import pathlib,json,copy,shutil,datetime
p=pathlib.Path(__file__).parent;old=p.parent/'skku-held-own-operation-v56-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v56.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
loc={r['offeringCode']:r for r in read(p/'current-primary-public-locators.json')['records']};keys=list(loc);a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');rs={x['offeringCode']:x for x in a['records'] if x['offeringCode'] in keys};write('source-current-attachment-identity.json',{'sourceOnly':True,'records':list(rs.values())});ds=copy.deepcopy(bs);proof=[]
dates={'IKS3012-01':['10-27','10-29','11-03','11-05','11-10','11-12','11-17','11-19','11-24','11-26','12-01','12-03','12-08','12-10'],'ART2034-01':['09-01','09-08','09-15','09-22','09-29','10-13','10-27','11-03','11-10','11-24','12-01','12-08']}
for c in [x for d in ds.values() for x in d['courses']]:
 key=c['courseCode']+'-'+c['section']
 if key not in keys:continue
 prior=copy.deepcopy(c);f=read(p/(key.lower()+'-full-education.json'));l=loc[key];r=rs[key];assert not c['schedules'] and l['currentLocatorBytesEqualFrozenEducation'];row=l['actualObservedCurrentFileRows'][0];assert (row['GAESUL_YEAR'],row['GAESUL_TERM'],row['HAKSU_NO'],row['BUNBAN'])==('2026','20',c['courseCode'],c['section']);assert l['currentNativeSameCodeSections']==[key];plans=[]
 for md in dates[key]:
  date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames;plans.extend({**x,'date':date.isoformat(),'deliveryMode':'inPerson' if key.startswith('IKS') else None} for x in frames)
 note='학교current2026/20/코드분반반환row→관찰된개별공개첨부locator→전체원문SHA동일한직접primary연결확인. 원문code-section미인쇄사실/교수영한alias미확인보존,교수명/title만조인0. 자체현재학기와요일HH명시,IKS교강사박소현/32422A자체인쇄. IKS ModuleB Oct27이후직접literal14일만오프라인예약;일반11·12월표현보다직접Oct27시작및날짜별표우선,9·10월녹화및Dec15시험예약0,외국인수강대상조건보존. ART 자체가을2026/화09–11:45와literal12일일반강의만native두HH로예약,대면문구미인쇄mode=null/default. Oct6국립현대미술관현장견학및Nov17미정전시견학은actualvenue/time미확인으로예약0;Oct20Dec15시험예약0/Nov23제출마감일정0. 계획변경조건/사전시험가이드/개별발표배정미확인보존,전체학기날짜/ordinal추정0/actualattendance확인0/partialCoverage=true.'
 c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV57']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'directSchoolCurrentPrimaryLocatorEvidence':l,'sourceActualLiteralDates':dates[key],'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':False,'ownCodePrinted':False,'ownTermPrinted':True,'currentSchoolCodeSectionLocatorConfirmed':True,'bilingualIdentityConfirmed':False,'nativeProfessorUnchanged':prior['professor'],'ownHHPrinted':True,'ownClassroomPrinted':key.startswith('IKS'),'primaryJoinCurrentReturnedCodeSectionLocatorRawSHA':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'otherSemesterSharingAbsentClaim':False};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':plans})
write('skku-humanities-2026-2.own-operation-v57.json',ds['humanities'])
manual={'IKS3012-01':(['2026-10-27','2026-10-29','2026-11-03','2026-11-05','2026-11-10','2026-11-12','2026-11-17','2026-11-19','2026-11-24','2026-11-26','2026-12-01','2026-12-03','2026-12-08','2026-12-10'],{2:[(810,885)],4:[(720,795)]},'32422A','inPerson'),'ART2034-01':(['2026-09-01','2026-09-08','2026-09-15','2026-09-22','2026-09-29','2026-10-13','2026-10-27','2026-11-03','2026-11-10','2026-11-24','2026-12-01','2026-12-08'],{2:[(540,615),(630,705)]},'62705',None)}
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
assert (other,count,meetings)==(2780,1805,49541);assert sum(len(r['expectedSchedulesLiteral']) for r in proof)==38
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':proof,'priorWholeCourses':1805,'priorMeetings':49541,'unchangedOtherWholeObjects':2780,'newWholeCourses':2,'newMeetings':38,'resultWholeCourses':1807,'resultMeetings':49579,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True});write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'newCourses':2,'newMeetings':38,'printedSectionExact':False,'currentSchoolCodeSectionDirectPublicLocatorSHAConfirmed':True,'ownTermHHPrinted':True,'ARTOwnClassroomPrinted':False,'ARTModeForced':False,'IKSOwnClassroomPrinted':True,'fieldtripAppointmentsGenerated':False,'examAppointmentsGenerated':False});print('PASS2/38=>1807/49579 other2780exact')
