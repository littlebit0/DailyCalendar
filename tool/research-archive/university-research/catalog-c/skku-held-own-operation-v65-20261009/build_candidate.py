import pathlib,json,copy,shutil,datetime
p=pathlib.Path(__file__).parent;old=p.parent/'skku-held-own-operation-v63-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v63.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
loc={r['offeringCode']:r for r in read(p/'current-primary-public-locators.json')['records']};keys=['GEDS003-01'];a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');rs={x['offeringCode']:x for x in a['records'] if x['offeringCode'] in keys};write('source-current-attachment-identity.json',{'sourceOnly':True,'records':list(rs.values())});ds=copy.deepcopy(bs);proof=[]
dates={'GEDS003-01':['09-01','09-03','09-08','09-10','09-15','09-17','09-22','09-29','10-01','10-06','10-08','10-13','10-15','10-22','10-27','10-29','11-03','11-05','11-10','11-12','11-17','11-19','11-24','11-26','12-01','12-03','12-08','12-10']}
for c in [x for d in ds.values() for x in d['courses']]:
 key=c['courseCode']+'-'+c['section']
 if key not in keys:continue
 prior=copy.deepcopy(c);f=read(p/(key.lower()+'-full-education.json'));l=loc[key];r=rs[key];assert not c['schedules'] and l['currentLocatorBytesEqualFrozenEducation'];row=l['actualObservedCurrentFileRows'][0];assert (row['GAESUL_YEAR'],row['GAESUL_TERM'],row['HAKSU_NO'],row['BUNBAN'])==('2026','20',c['courseCode'],c['section']);assert key in l['currentNativeSameCodeSections'];plans=[]
 for md in dates[key]:
  date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames;plans.extend({**x,'date':date.isoformat(),'deliveryMode':None} for x in frames)
 note='학교current2026/20/GEDS003/01에직접반환공개첨부locatorSHA=전체5쪽원문SHA exactprimary연결/교수title만조인0. 자체Fall2026/Tue12–13:15·Thu13:30–14:45명시nativeHHexact;원문코드분반/교실미인쇄사실구분/native31406교실만사용/32515교수office를교실로사용0. 원문모든일반literal28날짜만planned/nativePBL녹화라벨보존/실제대면명시강제0/nulldefault. Sep24온라인upload는정규실시간예약0,Oct20및Dec15시험예약0,Oct22는영화상영ordinary수업행로만예약/영화상영장소추정0. 교수DrMaxAltenhofen/native교수alias확인주장0,원문교수교육role명시/전체교육정책·읽기자료변경·발표모더레이션배정미확정조건보존/individualtime발명0/ordinal날짜추정0/partialCoverage=true/actualattendancefalse. 동일검토GEDM001-08은ownroom50304vsnative31302충돌이어느시각/교실선택도하지않고전체held그대로유지.'
 c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV65']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'directSchoolCurrentPrimaryLocatorEvidence':l,'sourceActualLiteralDates':dates[key],'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':False,'ownCodePrinted':False,'ownTermPrinted':True,'currentSchoolCodeSectionLocatorConfirmed':True,'bilingualIdentityConfirmed':False,'nativeProfessorUnchanged':prior['professor'],'ownHHPrinted':True,'ownClassroomPrinted':False,'primaryJoinCurrentReturnedCodeSectionLocatorRawSHA':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'otherSemesterSharingAbsentClaim':False};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':plans})
write('skku-humanities-2026-2.own-operation-v65.json',ds['humanities'])
manual={'GEDS003-01':(['2026-09-01','2026-09-03','2026-09-08','2026-09-10','2026-09-15','2026-09-17','2026-09-22','2026-09-29','2026-10-01','2026-10-06','2026-10-08','2026-10-13','2026-10-15','2026-10-22','2026-10-27','2026-10-29','2026-11-03','2026-11-05','2026-11-10','2026-11-12','2026-11-17','2026-11-19','2026-11-24','2026-11-26','2026-12-01','2026-12-03','2026-12-08','2026-12-10'],{2:[(720,795)],4:[(810,885)]},'31406',None)}
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
assert (other,count,meetings)==(2781,1812,49677);assert sum(len(r['expectedSchedulesLiteral']) for r in proof)==28
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':proof,'priorWholeCourses':1812,'priorMeetings':49677,'unchangedOtherWholeObjects':2781,'newWholeCourses':1,'newMeetings':28,'resultWholeCourses':1813,'resultMeetings':49705,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True});write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'newCourses':1,'newMeetings':28,'printedCodeSectionExact':False,'ownTermPrinted':True,'currentSchoolTermCodeSectionPrimarySHAConfirmed':True,'ownHHPrinted':True,'ownRoomPrinted':False,'deliveryModeForced':False,'recordedNativeLabelPreserved':True,'examAppointmentsGenerated':False,'GEDM001RoomConflictHeld':True});print('PASS1/28=>1813/49705 other2781exact')
