import pathlib,json,copy,shutil,datetime
p=pathlib.Path(__file__).parent;old=p.parent/'skku-held-own-operation-v62b-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/(f'skku-{camp}-2026-2.own-operation-v62b.json' if camp=='naturalScience' else f'skku-{camp}-2026-2.own-operation-v62.json')
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
loc={r['offeringCode']:r for r in read(p/'current-primary-public-locators.json')['records']};keys=list(loc);a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');rs={x['offeringCode']:x for x in a['records'] if x['offeringCode'] in keys};write('source-current-attachment-identity.json',{'sourceOnly':True,'records':list(rs.values())});ds=copy.deepcopy(bs);proof=[]
dates={'GEDW002-03':['08-31','09-07','09-14','09-21','10-26','11-02','11-09','11-16','11-23'],'GEDW002-09':['09-01','09-08','09-15','09-22','09-29','10-06','10-27','11-03','11-10','11-17','11-24']}
for c in [x for d in ds.values() for x in d['courses']]:
 key=c['courseCode']+'-'+c['section']
 if key not in keys:continue
 prior=copy.deepcopy(c);f=read(p/(key.lower()+'-full-education.json'));l=loc[key];r=rs[key];assert not c['schedules'] and l['currentLocatorBytesEqualFrozenEducation'];row=l['actualObservedCurrentFileRows'][0];assert (row['GAESUL_YEAR'],row['GAESUL_TERM'],row['HAKSU_NO'],row['BUNBAN'])==('2026','20',c['courseCode'],c['section']);assert key in l['currentNativeSameCodeSections'];plans=[]
 for md in dates[key]:
  date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames;plans.extend({**x,'date':date.isoformat(),'deliveryMode':None} for x in frames)
 note='학교current2026/20/코드분반별직접첨부locator→전체원문SHA동일확인. 원문자체2026학년2학기/GEDW002-03또는09/HHroom인쇄확인. source03수13–14:45·09목13–14:45와native각13:30–14:45는실제30분충돌이라두번째요일전체예약0/오타추정0/시각변경0. 정확일치source03월12–13:15/61602및09화12–13:15/33301의일반literal각9일·11일만partialplanned예약. 대면명시강제0/nulldefault. 모든individual면담8일/분반·Sep28Oct5공휴일/09Sep24휴일/16주보강반성활동actual운영미확정예약0. 원문weekday충돌/개별평가·구두브리핑·피드백·과제조건전체metadata보존,공통시험기간과충돌하는개인면담으로시험/일반수업추정0. nativeallfields/actualattendancefalse/partialCoverage=true/ordinal추정0.'
 c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV63']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'directSchoolCurrentPrimaryLocatorEvidence':l,'sourceActualLiteralDates':dates[key],'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':True,'ownCodePrinted':True,'ownTermPrinted':True,'currentSchoolCodeSectionLocatorConfirmed':True,'bilingualIdentityConfirmed':False,'nativeProfessorUnchanged':prior['professor'],'ownHHPrinted':True,'ownClassroomPrinted':True,'ownHHOnlyFirstWeekdayConfirmed':True,'secondWeekdayHHConflictPreserved':True,'secondWeekdayReservations':0,'primaryJoinCurrentReturnedCodeSectionLocatorRawSHA':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'otherSemesterSharingAbsentClaim':False};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':plans})
write('skku-humanities-2026-2.own-operation-v63.json',ds['humanities'])
manual={'GEDW002-03':(['2026-08-31','2026-09-07','2026-09-14','2026-09-21','2026-10-26','2026-11-02','2026-11-09','2026-11-16','2026-11-23'],{1:[(720,795)]},'61602',None),'GEDW002-09':(['2026-09-01','2026-09-08','2026-09-15','2026-09-22','2026-09-29','2026-10-06','2026-10-27','2026-11-03','2026-11-10','2026-11-17','2026-11-24'],{2:[(720,795)]},'33301',None)}
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
assert (other,count,meetings)==(2780,1810,49657);assert sum(len(r['expectedSchedulesLiteral']) for r in proof)==20
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':proof,'priorWholeCourses':1810,'priorMeetings':49657,'unchangedOtherWholeObjects':2780,'newWholeCourses':2,'newMeetings':20,'resultWholeCourses':1812,'resultMeetings':49677,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True});write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'newCourses':2,'newMeetings':20,'printedSectionExact':True,'currentSchoolCodeSectionDirectPublicLocatorSHAConfirmed':True,'ownTermPrinted':True,'firstWeekdayHHRoomPrintedExact':True,'secondWeekdayHH30MinuteConflictPreserved':True,'secondWeekdayAppointments':0,'individualConsultationMakeupHolidayAppointments':0,'deliveryModeForced':False});print('PASS2/20=>1812/49677 other2780exact')
