import pathlib,json,copy,shutil,datetime
p=pathlib.Path(__file__).parent;old=p.parent/'skku-held-own-operation-v70-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v70.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
loc={r['offeringCode']:r for r in read(p/'current-primary-public-locators.json')['records']};keys=['GEDH101-01'];a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');rs={x['offeringCode']:x for x in a['records'] if x['offeringCode'] in keys};write('source-current-attachment-identity.json',{'sourceOnly':True,'records':list(rs.values())});ds=copy.deepcopy(bs);proof=[]
dates={'GEDH101-01':['09-04','09-11','09-18','10-02','10-16','10-23','10-30','11-13','11-20','11-27','12-04']}
for c in [x for d in ds.values() for x in d['courses']]:
 key=c['courseCode']+'-'+c['section']
 if key not in keys:continue
 prior=copy.deepcopy(c);f=read(p/(key.lower()+'-full-education.json'));l=loc[key];r=rs[key];assert not c['schedules'] and l['currentLocatorBytesEqualFrozenEducation'];row=l['actualObservedCurrentFileRows'][0];assert (row['GAESUL_YEAR'],row['GAESUL_TERM'],row['HAKSU_NO'],row['BUNBAN'])==('2026','20',c['courseCode'],c['section']);assert key in l['currentNativeSameCodeSections'];plans=[]
 for md in dates[key]:
  date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames;plans.extend({**x,'date':date.isoformat(),'deliveryMode':None} for x in frames)
 note='학교current2026/20/GEDH101/01 직접반환첨부locatorSHA=전체4쪽교육원문SHA primary연결/title교수만조인0. 자체code·분반·학기·HH·교실미인쇄구분/actualcurrentnative금12:00–13:15·13:30–14:45/61802 사용/자체주당2시간30분수업scope보존. 원문literal금요일일반11날짜만planned;온라인및오프라인결합범위와매주별도과제영상·명상녹음자료제공조건전체보존/개별mode미지정null사용자선택/대면·실시간강제0/녹화요일발명0. Sep25추석·Oct9한글날과제only0,Nov6성균관retreat는native교실과별도야외운영scope미확정0,Dec11포트폴리오작성제출only0. Oct23은자체literal호흡수업행에만근거해일반planned/공통시험날짜로개별시험발명0. own숫자주차를Gregorian으로변환0/지원불가능확정0. nativecurrentdetail수업계획서작성중문구원문보존/첨부작성최종확정주장0/실제기말시험예약0. 교수native손혜숙그대로/own교수미인쇄사실보존. 같은검토GEDH101-41은own2026-2와6주추석/실제4주추석의mixedordinal불일치·각주별contactmodeactual날짜미확정으로heldwhole유지. actualattendancefalse/partialCoverage=true.'
 c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV71']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'directSchoolCurrentPrimaryLocatorEvidence':l,'sourceActualLiteralDates':dates[key],'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':False,'ownCodePrinted':False,'ownTermPrinted':False,'currentSchoolCodeSectionLocatorConfirmed':True,'bilingualIdentityConfirmed':False,'nativeProfessorUnchanged':prior['professor'],'ownHHPrinted':False,'ownClassroomPrinted':False,'primaryJoinCurrentReturnedCodeSectionLocatorRawSHA':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'otherSemesterSharingAbsentClaim':False};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':plans})
write('skku-humanities-2026-2.own-operation-v71.json',ds['humanities'])
manual={'GEDH101-01':(['2026-09-04','2026-09-11','2026-09-18','2026-10-02','2026-10-16','2026-10-23','2026-10-30','2026-11-13','2026-11-20','2026-11-27','2026-12-04'],{5:[(720,795),(810,885)]},'61802',None)}
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
assert (other,count,meetings)==(2781,1818,49833);assert sum(len(r['expectedSchedulesLiteral']) for r in proof)==22
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':proof,'priorWholeCourses':1818,'priorMeetings':49833,'unchangedOtherWholeObjects':2781,'newWholeCourses':1,'newMeetings':22,'resultWholeCourses':1819,'resultMeetings':49855,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True});write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'newCourses':1,'newMeetings':22,'printedCodeSectionExact':False,'ownTermPrinted':False,'currentSchoolTermCodeSectionPrimarySHAConfirmed':True,'ownHHPrinted':False,'ownRoomPrinted':False,'deliveryModeForced':False,'recordedNativeLabelPreserved':True,'examAppointmentsGenerated':False,'GEDH10141OrdinalModeDateConflictHeld':True,'ordinaryLiteralDatesScopeButModeUnassignedPreserved':True,'currentNativeDetailPlanWritingWarningPreserved':True,'sourceReviewRequiredBeforeProductProjection':True});print('PASS1/22=>1819/49855 other2781exact humanities actual; root source scope review required')
