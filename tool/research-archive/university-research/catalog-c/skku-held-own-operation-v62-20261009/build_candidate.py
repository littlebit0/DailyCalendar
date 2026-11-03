import pathlib,json,copy,shutil,datetime
p=pathlib.Path(__file__).parent;old=p.parent/'skku-held-own-operation-v61-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v61.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
loc={r['offeringCode']:r for r in read(p/'current-primary-public-locators.json')['records']};keys=list(loc);a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');rs={x['offeringCode']:x for x in a['records'] if x['offeringCode'] in keys};write('source-current-attachment-identity.json',{'sourceOnly':True,'records':list(rs.values())});ds=copy.deepcopy(bs);proof=[]
dates={'PHR3152-41':['09-03','09-10','09-17','10-01','10-08','10-15','10-29','11-05','11-12','11-19','11-26','12-03','12-10','12-17']}
for c in [x for d in ds.values() for x in d['courses']]:
 key=c['courseCode']+'-'+c['section']
 if key not in keys:continue
 prior=copy.deepcopy(c);f=read(p/(key.lower()+'-full-education.json'));l=loc[key];r=rs[key];assert not c['schedules'] and l['currentLocatorBytesEqualFrozenEducation'];row=l['actualObservedCurrentFileRows'][0];assert (row['GAESUL_YEAR'],row['GAESUL_TERM'],row['HAKSU_NO'],row['BUNBAN'])==('2026','20',c['courseCode'],c['section']);assert key in l['currentNativeSameCodeSections'];plans=[]
 for md in dates[key]:
  date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames;plans.extend({**x,'date':date.isoformat(),'deliveryMode':None} for x in frames)
 note='학교현재2026/20/PHR3152/41에직접반환한공개첨부locatorSHA=전체교육원문SHA를primary로연결하며교수/title만조인0. 원문학기/year/code/section/교실미인쇄사실명시,연도는현재학교직접연결로확인/원문MMDD16주순서와현재2026목요일·자체native목HH대조. 자체목09–11:50명시,currentnative목09–09:50/10–10:50/11–11:50/530154. 공동교수정상전·이소아및주별담당영역원문전부보존/nativeprof변경0. Sep24추석연휴·Oct22약학회중간시험예약0,나머지14개literal일반강의/조별발표planned예약. Dec17명시일반조별발표II로반영하되원문부록기말고사는실제일자/HH미배정상태원문보존/시험예약0. NativePBL사전제작혼합표시는보존,자체원문전체목HH수업명시·날짜별녹화/시간분할미인쇄이며실제대면명시주장0/nullmode사용자선택. 발표15분·조별세부배정미확인전체lectureplanned외개별예약0. wholeconditions/partialCoverage=true/actualattendance확인0/ordinal추정0.'
 c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV62']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'directSchoolCurrentPrimaryLocatorEvidence':l,'sourceActualLiteralDates':dates[key],'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':False,'ownCodePrinted':False,'ownTermPrinted':False,'currentSchoolCodeSectionLocatorConfirmed':True,'bilingualIdentityConfirmed':False,'nativeProfessorUnchanged':prior['professor'],'ownHHPrinted':True,'ownClassroomPrinted':False,'primaryJoinCurrentReturnedCodeSectionLocatorRawSHA':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'otherSemesterSharingAbsentClaim':False};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':plans})
write('skku-humanities-2026-2.own-operation-v62.json',ds['humanities'])
manual={'PHR3152-41':(['2026-09-03','2026-09-10','2026-09-17','2026-10-01','2026-10-08','2026-10-15','2026-10-29','2026-11-05','2026-11-12','2026-11-19','2026-11-26','2026-12-03','2026-12-10','2026-12-17'],{4:[(540,590),(600,650),(660,710)]},'530154',None)}
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
assert (other,count,meetings)==(2781,1809,49615);assert sum(len(r['expectedSchedulesLiteral']) for r in proof)==42
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':proof,'priorWholeCourses':1809,'priorMeetings':49615,'unchangedOtherWholeObjects':2781,'newWholeCourses':1,'newMeetings':42,'resultWholeCourses':1810,'resultMeetings':49657,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True});write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'newCourses':1,'newMeetings':42,'printedCodeSectionExact':False,'ownTermPrinted':False,'currentSchoolTermCodeSectionPrimarySHAConfirmed':True,'ownHHPrinted':True,'ownRoomPrinted':False,'bothInstructorsAndWeeklyAssignmentPreserved':True,'nativeRecordedPBLLabelPreserved':True,'deliveryModeForced':False,'recordedAllocationUnknownNotePreserved':True,'examAppointmentsGenerated':False});print('PASS1/42=>1810/49657 other2781exact')
