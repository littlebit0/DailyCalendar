import pathlib,json,copy,shutil,datetime,hashlib
p=pathlib.Path(__file__).parent;old=p.parent/'skku-held-own-operation-v65-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v65.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');r=next(x for x in a['records'] if x['offeringCode']=='GBE4018-41');write('source-current-attachment-identity.json',{'sourceOnly':True,'records':[r]});l=read(p/'current-primary-public-locators.json')['records'][0];f=read(p/'gbe4018-41-full-education.json');assert l['currentLocatorBytesEqualFrozenEducation'];row=l['actualObservedCurrentFileRows'][0];assert (row['GAESUL_YEAR'],row['GAESUL_TERM'],row['HAKSU_NO'],row['BUNBAN'])==('2026','20','GBE4018','41')
calendarPath=p.parent.parent/'catalog-g/skku-semester-calendar-extracted.json';cal=read(calendarPath);selected=[]
for month in [8,10,12]:
 for vals in cal.get('bachelor_'+str(month),[]):
  for k,v in vals.items():
   if k.startswith('con_') and any(s in str(v) for s in ['2학기 중간시험','2학기 기말시험','2학기 개강','2학기 종강','겨울방학']):
    suffix=k[4:];selected.append({'sourceMonth':month,'sourceRowKey':k,'sourceText':v,'startDate':vals.get('sd_'+suffix),'endDate':vals.get('ed_'+suffix)})
assert any(x['startDate']=='2026-10-19' and x['endDate']=='2026-10-23' for x in selected);assert any(x['startDate']=='2026-12-14' and x['endDate']=='2026-12-18' for x in selected)
write('own-current-exam-calendar-evidence.json',{'sourceOnly':True,'cachedOfficialCalendar':str(calendarPath),'cacheSHA256':hashlib.sha256(calendarPath.read_bytes()).hexdigest(),'actualOwnCalendarRows':selected,'commonExamExclusionAppliedConservatively':True,'specificCourseWeek8And16GregorianMappingConfirmed':False,'ownPrintedDates':False,'examReservationGenerated':False})
ds=copy.deepcopy(bs);c=next(x for x in ds['naturalScience']['courses'] if x['courseCode']=='GBE4018' and x['section']=='41');prior=copy.deepcopy(c);assert not c['schedules'];assert r['sourceRow']['CAMPUS_NM']=='자연과학';assert r['sourceRow']['HAKWI_NAME']=='학사/석사';assert 'both undergraduate and graduate' in f['educationFullText'];assert 'Tuesday 15:00-17:45\nRoom 86126' in f['educationFullText'];assert "before the offline session. Contact hours are for discussion" in f['educationFullText'];assert [(x['weekday'],x['startMinute'],x['endMinute'],x['classroom']) for x in c['rawMeetingFrameForReviewOnly']]==[(2,900,975,'86126'),(2,990,1065,'86126')]
plans=[];start=datetime.date(2026,8,31);end=datetime.date(2026,12,18);d=start
while d<=end:
 if d.isoweekday()==2 and not(datetime.date(2026,10,19)<=d<=datetime.date(2026,10,23) or datetime.date(2026,12,14)<=d<=datetime.date(2026,12,18)):
  plans.extend({**x,'date':d.isoformat(),'deliveryMode':'inPerson'} for x in c['rawMeetingFrameForReviewOnly'])
 d+=datetime.timedelta(days=1)
manualdates=['2026-09-01','2026-09-08','2026-09-15','2026-09-22','2026-09-29','2026-10-06','2026-10-13','2026-10-27','2026-11-03','2026-11-10','2026-11-17','2026-11-24','2026-12-01','2026-12-08'];expected=[]
for d in manualdates:
 assert datetime.date.fromisoformat(d).isoweekday()==2
 for s,e in [(900,975),(990,1065)]:expected.append({'weekday':2,'startMinute':s,'endMinute':e,'classroom':'86126','date':d,'deliveryMode':'inPerson'})
assert plans==expected
note='학교current2026/20/GBE4018/41 직접반환첨부locatorSHA=전체DOCX원문SHA primary연결/title·교수만조인0. 자체GBE4018/Tuesday15:00–17:45/86126교실 명시;분반·학기미인쇄구분/참고문헌2025를학기증거로사용0. 원문매주사전reading/video는offline session전에완료하고contact hours는discussion/pairprogramming/critique로명시하여정규오프라인교실예약만적용/사전영상관리슬롯0. 현재학교학사·석사공동강좌원문및ownUG+graduate범위그대로/학부전용변경0. 계획날짜는원문literal날짜가아닌실제native화요일두HH+자체정규기간2026-08-31–12-18에서파생된plannedlecture;교수own16주숫자를실제Gregorian주별운영으로확정하지않음. 공통중간10/19–23·기말12/14–18은보수적제외/ownWeek8·16본문일반내용은그대로보존하되Oct20·Dec15실제수업확정주장0/시험예약0/미확정보강0. native손한샘/ownHansemSohn교육역할명시보존/alias독립확인주장0. Office86333및Monday09–12를강의실·수업시간으로사용0. 모든원문운영·인체연구조건·변경가능사항보존/actualattendancefalse/partialCoverage=true.'
c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV67']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'directSchoolCurrentPrimaryLocatorEvidence':l,'sourceActualLiteralDates':[],'plannedDatesDerivedFromNativeSemester':True,'sourceSectionPrinted':False,'ownCodePrinted':True,'ownTermPrinted':False,'currentSchoolCodeSectionLocatorConfirmed':True,'bilingualIdentityConfirmed':False,'nativeProfessorUnchanged':prior['professor'],'ownPrintedEducationalInstructorName':'Hansem Sohn','ownHHPrinted':True,'ownClassroomPrinted':True,'primaryJoinCurrentReturnedCodeSectionLocatorRawSHA':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'otherSemesterSharingAbsentClaim':False,'explicitWeeklyOfflineContactSource':True,'schoolCurrentExamPeriodsConservativeExclusion':True,'courseSpecificExamGregorianDatesConfirmed':False}
write('skku-naturalScience-2026-2.own-operation-v67.json',ds['naturalScience']);other=count=meetings=0
for camp in bs:
 for x,y in zip(bs[camp]['courses'],ds[camp]['courses']):
  if x['sourceId']!=c['sourceId']:assert x==y;other+=1
  if x['schedules']:count+=1;meetings+=len(x['schedules'])
assert (other,count,meetings)==(2781,1813,49705)
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':[{'offeringCode':'GBE4018-41','sourceId':c['sourceId'],'expectedSchedulesLiteral':expected,'literalReceiptDatesAreIndependentExpectedPlanValuesNotPrintedSourceDates':True}],'priorWholeCourses':1813,'priorMeetings':49705,'unchangedOtherWholeObjects':2781,'newWholeCourses':1,'newMeetings':28,'resultWholeCourses':1814,'resultMeetings':49733,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':False,'datesDerivedFromNativeWeeklySemester':True,'courseSpecificOrdinalWeekMappingApplied':False})
write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'newCourses':1,'newMeetings':28,'printedCodeExact':True,'printedSectionExact':False,'ownTermPrinted':False,'currentSchoolTermCodeSectionPrimarySHAConfirmed':True,'ownHHPrinted':True,'ownRoomPrinted':True,'weeklyOfflineContactExplicit':True,'deliveryModeForced':True,'mode':'inPerson','recordedNativeLabelPreserved':True,'ownPrintedEducationalInstructorName':'Hansem Sohn','instructorAliasConfirmed':False,'nativeCombinedBachelorMasterScopePreserved':True,'literalSourceGregorianDateCount':0,'ordinaryPlanDerivedFromNativeWeeklyCurrentOwnSemester':True,'commonSchoolExamPeriodExcludedNotSpecificCourseExamConfirmed':True,'examAppointmentsGenerated':False,'privacySuppressedRoleNamesFieldEmptyButExplicitEducationRolePresent':True,'candidatePhysicallyWrittenCampuses':['naturalScience'],'otherCampusesActualBaselineUsed':True});print('PASS1/28=>1814/49733 other2781exact; naturalScience actual materialized')
