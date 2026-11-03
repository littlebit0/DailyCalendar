import pathlib,json,copy,shutil,datetime
p=pathlib.Path(__file__).parent;old=p.parent/'skku-held-own-operation-v60-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v60.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
loc={r['offeringCode']:r for r in read(p/'current-primary-public-locators.json')['records']};keys=list(loc);a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');rs={x['offeringCode']:x for x in a['records'] if x['offeringCode'] in keys};write('source-current-attachment-identity.json',{'sourceOnly':True,'records':list(rs.values())});ds=copy.deepcopy(bs);proof=[]
dates={'CEK4108-01':['10-07','10-21','10-28','11-04','11-11','11-18','11-25','12-02']}
for c in [x for d in ds.values() for x in d['courses']]:
 key=c['courseCode']+'-'+c['section']
 if key not in keys:continue
 prior=copy.deepcopy(c);f=read(p/(key.lower()+'-full-education.json'));l=loc[key];r=rs[key];assert not c['schedules'] and l['currentLocatorBytesEqualFrozenEducation'];row=l['actualObservedCurrentFileRows'][0];assert (row['GAESUL_YEAR'],row['GAESUL_TERM'],row['HAKSU_NO'],row['BUNBAN'])==('2026','20',c['courseCode'],c['section']);assert key in l['currentNativeSameCodeSections'];plans=[]
 for md in dates[key]:
  date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames;plans.extend({**x,'date':date.isoformat(),'deliveryMode':'liveOnline' if md in ['10-07','10-21'] else 'inPerson'} for x in frames)
 note='현재학교native HAKWI_NAME학사/석사/JUKYONGHAKWI_GB04/ISU_NAME전공(대학원)공동강좌분류를학부전용으로변경하지않고모든필드그대로보존합니다. 자체첨부분류Major(Integrated Masters-PhD)와차이도그대로기록. 학교현재2026/20/CEK4108/01직접첨부locatorSHA동일,원문표의자체2026Fall/코드01명시와literal수요일운영만planned예약. ownHH/교실미인쇄native수18–19:15/19:30–20:45/31609만사용. ZoomOct7/21각2회·OFFOct28Nov4/11/18/25Dec2각2회총16예약. ON녹화6일·Dec9NoLessons·Dec18금요일특강actualHH미배정은예약0. 공통학부주차로별도강좌기간확장0/ordinal추정0/원문실제특강다른교수·실제평가방법·국제어/WAVE/변경조건전부보존. 분반코드원문표cell인쇄존재이며연속추출text가아닌분절표이므로학교현재primary링크도독립보호. 교수서희정/HeejungSEO alias확인주장0/partialCoverage=true/actualattendance확인0.'
 c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV61']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'directSchoolCurrentPrimaryLocatorEvidence':l,'sourceActualLiteralDates':dates[key],'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':True,'ownCodePrinted':True,'ownTermPrinted':True,'currentSchoolCodeSectionLocatorConfirmed':True,'bilingualIdentityConfirmed':False,'nativeProfessorUnchanged':prior['professor'],'ownHHPrinted':False,'ownClassroomPrinted':False,'primaryJoinCurrentReturnedCodeSectionLocatorRawSHA':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'otherSemesterSharingAbsentClaim':False};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':plans})
write('skku-humanities-2026-2.own-operation-v61.json',ds['humanities'])
manual={'CEK4108-01':(['2026-10-07','2026-10-21','2026-10-28','2026-11-04','2026-11-11','2026-11-18','2026-11-25','2026-12-02'],{3:[(1080,1155),(1170,1245)]},'31609','inPerson')}
for row in proof:
 dd,frames,room,mode=manual[row['offeringCode']];exp=[]
 for date in dd:
  w=datetime.date.fromisoformat(date).isoweekday();assert w in frames
  for s,e in frames[w]:exp.append({'weekday':w,'startMinute':s,'endMinute':e,'classroom':room,'date':date,'deliveryMode':'liveOnline' if date in ['2026-10-07','2026-10-21'] else mode})
 assert exp==row['expectedSchedulesLiteral'];row['expectedSchedulesLiteral']=exp
other=count=meetings=0
for camp in bs:
 for x,y in zip(bs[camp]['courses'],ds[camp]['courses']):
  if x['courseCode']+'-'+x['section'] not in keys:assert x==y;other+=1
  if x['schedules']:count+=1;meetings+=len(x['schedules'])
assert (other,count,meetings)==(2781,1808,49599);assert sum(len(r['expectedSchedulesLiteral']) for r in proof)==16
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':proof,'priorWholeCourses':1808,'priorMeetings':49599,'unchangedOtherWholeObjects':2781,'newWholeCourses':1,'newMeetings':16,'resultWholeCourses':1809,'resultMeetings':49615,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True});write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'newCourses':1,'newMeetings':16,'printedCodeSectionExact':True,'ownTermPrinted':True,'ownHHRoomPrinted':False,'nativeExactSectionHHRoomConfirmed':True,'literalZoomAndOfflineModesConfirmed':True,'nativeDegreeScope':'학사/석사','sourceGraduateClassificationPreserved':True,'tourExamRecordedAppointmentsGenerated':False});print('PASS1/16=>1809/49615 other2781exact')
