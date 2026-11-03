import pathlib,json,copy,shutil,datetime
p=pathlib.Path(__file__).parent;old=p.parent/'skku-held-own-operation-v71-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v71.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
loc={r['offeringCode']:r for r in read(p/'current-primary-public-locators.json')['records']};keys=['GEDN032-41'];a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');rs={x['offeringCode']:x for x in a['records'] if x['offeringCode'] in keys};write('source-current-attachment-identity.json',{'sourceOnly':True,'records':list(rs.values())});ds=copy.deepcopy(bs);proof=[]
dates={'GEDN032-41':['09-01','09-08','09-15','09-22','09-29','10-06','10-13','10-27','11-03','11-10','11-17','11-24','12-01','12-08']}
for c in [x for d in ds.values() for x in d['courses']]:
 key=c['courseCode']+'-'+c['section']
 if key not in keys:continue
 prior=copy.deepcopy(c);f=read(p/(key.lower()+'-full-education.json'));l=loc[key];r=rs[key];assert not c['schedules'] and l['currentLocatorBytesEqualFrozenEducation'];row=l['actualObservedCurrentFileRows'][0];assert (row['GAESUL_YEAR'],row['GAESUL_TERM'],row['HAKSU_NO'],row['BUNBAN'])==('2026','20',c['courseCode'],c['section']);assert key in l['currentNativeSameCodeSections'];plans=[]
 for md in dates[key]:
  date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames;plans.extend({**x,'date':date.isoformat(),'deliveryMode':None} for x in frames)
 note='학교current2026/20/GEDN032/41 직접반환공개첨부locatorSHA=전체9쪽교육원문SHA primary연결/title교수만조인0. 자체2026년도2학기/이상원교수/매주화09:00시작명시native시작정합. 자체code·분반·끝HH·교실미인쇄구분/native두HH09–10:15·10:30–11:45/26311사용. 사전동영상학습+대면강의(또는온라인)+실습과제퀴즈로정규접촉과사전녹화범위직접구분/실제단일대면또는라이브강제0/null사용자선택. 강의일정계획actual14literal화요일ordinary·발표·특강행만두HHplanned28예약;Oct20·Dec15과제제출only중간/기말0/사전영상관리슬롯발명0. Oct13·Nov17특강은자체같은강의일정표의수업이며별도장소/실제강연자시간배정미인쇄사실구분/외부장소추정0. own학번000양식은개인명단아님/실제학생자료0. source끝시각은native-only임을보존/ordinal날짜변환0/학사기간·actualweekday·holiday정합/시험보강예약0. 전체평가·프로젝트·수업선택조건보존/actualattendancefalse/partialCoverage=true.'
 c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV76']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'directSchoolCurrentPrimaryLocatorEvidence':l,'sourceActualLiteralDates':dates[key],'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':False,'ownCodePrinted':False,'ownTermPrinted':True,'currentSchoolCodeSectionLocatorConfirmed':True,'bilingualIdentityConfirmed':False,'nativeProfessorUnchanged':prior['professor'],'ownHHPrinted':False,'ownStartHHPrinted':True,'ownEndHHPrinted':False,'ownPrintedEducationalInstructorName':'이상원','ownClassroomPrinted':False,'primaryJoinCurrentReturnedCodeSectionLocatorRawSHA':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'otherSemesterSharingAbsentClaim':False};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':plans})
write('skku-naturalScience-2026-2.own-operation-v76.json',ds['naturalScience'])
manual={'GEDN032-41':(['2026-09-01','2026-09-08','2026-09-15','2026-09-22','2026-09-29','2026-10-06','2026-10-13','2026-10-27','2026-11-03','2026-11-10','2026-11-17','2026-11-24','2026-12-01','2026-12-08'],{2:[(540,615),(630,705)]},'26311',None)}
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
assert (other,count,meetings)==(2781,1819,49855);assert sum(len(r['expectedSchedulesLiteral']) for r in proof)==28
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':proof,'priorWholeCourses':1819,'priorMeetings':49855,'unchangedOtherWholeObjects':2781,'newWholeCourses':1,'newMeetings':28,'resultWholeCourses':1820,'resultMeetings':49883,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True});write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'newCourses':1,'newMeetings':28,'printedCodeSectionExact':False,'ownTermPrinted':True,'currentSchoolTermCodeSectionPrimarySHAConfirmed':True,'ownHHPrinted':False,'ownStartHHPrinted':True,'ownEndHHPrinted':False,'ownPrintedEducationalInstructorName':'이상원','ownRoomPrinted':False,'deliveryModeForced':False,'recordedNativeLabelPreserved':True,'examAppointmentsGenerated':False,'recordedPriorVideoAndContactChoiceClearlySeparated':True,'ownStartHHPrintedOnly':True,'nativeFullHHAndRoomPreserved':True,'twoEssayOnlyDatesHeld':True,'guestLecturesNativePlanDatesNotActualVenueConfirmed':True});print('PASS1/28=>1820/49883 other2781exact naturalScience actual')
