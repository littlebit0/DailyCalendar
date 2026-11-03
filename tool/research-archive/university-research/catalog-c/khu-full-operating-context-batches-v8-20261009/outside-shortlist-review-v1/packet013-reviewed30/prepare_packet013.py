# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet013-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={322: [(3, 660, 770, '약B308-1')], 332: [(2, 540, 650, '약B209')], 335: [(4, 900, 1010, '약B308-1')], 349: [(1, 660, 770, '약410')]}
weeks={322: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 332: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 335: [1, 2, 3], 349: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
allowedWeekdays={};exceptDates={};examExceptions={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={322:{3}}
allowedNativeGroups={}
calendarPlan={322: 0, 332: 0, 335: 0, 349: 0}
reasons={321: 'Wholecurrentplan physicalindividualthesis read; ownweekdayHHabsent -(). Held.', 322: 'Wholecurrentplan explicitphysical+prospective nonlive substitute possible. Wed11–12:50, weeks1–7/9–14 only13;15blank8/16examheld. Originalnewroomassignmentpending retained, classroomblank/notnative약B308-1precision.', 323: 'Wholecurrentplan actualphysical+nonlive combination unallocated. ExplicitphysicalQ&A in7/8/9/13/14/15 but does not independently state wholeeachnativeWed/Fri group physical or actualabsoluteportion; no shorten/wholemixed clock guess. Heldpending.', 324: 'Owncurrentcode/prof envelope read, remainingeducation/operation/datecellsblank. NativeSun13–15:45 alone notoperation; held.', 325: 'Both fullplans read. Firstphysicalpractice+recordedtheory mixed withoutabsoluteallocation; secondoverview says1–8 whileownweekly actual9–16, instructor allocation conflicts. OwnTue15–18:50 notchosenagainstsource, heldwhole.', 326: 'Currentcode/prof envelope actualread, educational/operating/weekdatecellsblank, heldownoperationmissing.', 327: 'Wholecurrentplan read. Actualindividualresearchproject and preparationofpersonalpractice schedules; physicaldefaultdoesnotresolveindividualSunday19–21:45 fullattendanceallocation. Held.', 328: 'Exactownsection09 wholeplan independentlyread, sameactualindividualresearchproject/personalpracticeschedule assection11. NativeSun19–21:45 retained, held.', 329: 'Wholecurrentplan ownlaboratoryresearch, actual4/5personalexperimenttimingplanning+9additionalexperimentplanning. Sunday18–20:45 notindependentnormalfixedallocation; held.', 330: 'Exactownsection08 wholeplan independentlyread; samepersonalresearchexperimenttimingunconfirmed, notblankroom; held.', 331: 'Currentwholeenvelope read, educational/operating/weekdatecellsblank. NativeSun18–20:45 alone notactualoperation; held.', 332: 'Wholecurrentplan explicitphysical, prospectiveholidayrecordingonly. OwnTue09–10:50 약B209 normal1–7/9–14=13groups;15actualfinalexam16finalexcluded. Clinicalevaluationtopicnotpersonalpatientassignment.', 333: 'Wholecurrentplan actuallyread.100%physicalindividualexperimentdesign basedeachownhypothesis/researchplanning; noexactwholeSundayattendanceallocation, heldpendingnotblankroom.', 334: 'Currentwholecode/prof envelope actualread withblankeducational/operating/weekdatefields; held.', 335: 'Wholecurrentplan explicitphysicalonly1–3, ownThu15–16:50 약B308-1=3groups. Later4–7/9–15uploadedrecordings withnoHHgenerated,8/16examexcluded.', 336: 'Currentwholecode/prof envelope actualread withblankeducation/operating/datefields; held.', 337: 'Currentwholecode/prof envelope actualread withblankeducation/operating/datefields; held.', 338: 'Owncurrentcode/prof wholeenvelope read, educational/operating/weekdatecellsblank. Heldnotblankroom.', 339: 'Ownsection14 wholecurrentenvelope read, educational/operating/datecellsblank. Heldownoperationmissing.', 340: 'Ownsection23 wholeenvelope read, educational/operating/datecellsblank. NativeSun20–22:45 alone notoperation, held.', 341: 'Ownsection16 code/prof envelope read, education/operating/datecellsblank. Graduateprofaffiliation notactualgraduatescopeorblock; ownoperationmissingheld.', 342: 'Wholecurrentplan actualselfdirected researchandliteraturesurvey; operation 연구수행 alone doesnotconfirm live/physicalwholeSunday20–22:45 assignment. Held.', 343: 'Wholecurrentplan physicalmostly+flipvideo actualcombined, noexplicitpreparationbeforeclass vsreplacement or wholeweek/groupabsoluteallocation. OwnTue09:30–11:20 preservedheldpending, schoolvideosnotremoved.', 344: 'Wholecurrentcode/prof envelope read; educational/operating/currentdatecellsblank. NativeMon15–18:50 alone notoperation, held.', 345: 'Wholecurrentcode/prof envelope read; educational/operating/currentdatecellsblank. NativeTue09:30–10:45/Thu15–16:15 retainedheld.', 346: 'Wholecurrentcode/prof envelope read; educational/operating/currentdatecellsblank. NativeTue13–14:50 retainedheld.', 347: 'Wholecurrentplan read. Experiment/theory/teamtalk+online selected butactualfixeddeliveryallocationunknown; weeks2–14 TBA,15/16final. NativeWed14–17:50 notwholeactualoperation, held.', 348: 'Wholecurrentcode/prof envelope read; educational/operating/currentdatecellsblank, notgraduateprofaffiliation exclusion. OwnSun21–23:45 retainedheld.', 349: 'Wholecurrentplan physicaldefault andprospectiveevent/holidayremoteonly. OwnMon11–12:50 약410 normal14weeks exceptOct5 =13groups;8generalexamperiodwithoutliteralownnormalexceptionheld,16final. Historicalmedicine topicsnotclinicalassignment.', 350: 'Wholecurrentplan physicalpractice+onlineexperimentlecture explicitlymixed. OwnWed15–18:50 noabsolutephysicalvsrecordedallocation; afterOTactualdetailedannouncementnotavailable.15backup andassessment8/16held. Preservewholeactuallab/source nottitleexclusion.'}
assert len(HH)==4 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-321];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
 assert native and not re.sub(r'[\s,]','',slot.sub('',c['sourceSchedule']))
 assert [('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()) for m in native]==HH[n] or False,(n,c['sourceSchedule'],HH[n])
 if False:
  native=native[1:]
  assert [('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()) for m in native]==HH[n]
 for plan,z in zip(plans,x['plans']):
  assert plan['campus']=={'seoul':'서울','global':'국제'}[c['campus']];assert plan['header']==['2026학년도 2학기 강의계획서'] and plan['lectureCode']==c['sourceEducationalVariants'][0]['lecture_cd']
  assert plan['queriedProfessorName'] in [v['teach_na'] for v in c['sourceEducationalVariants']]
  basic=next(s['rows'] for s in plan['educationalSections'] if s['section']=='기본정보');assert [r[1] for r in basic if r[0]=='학수번호']==[plan['lectureCode']]
  clocks=[r[1] for r in basic if r[0]=='강의시간강의실']
  normal=re.sub(r'\s+','',clocks[0] if clocks else '')
  if re.search(r"[월화수목금토일]\d{2}:\d{2}-",normal):
   for i,m in enumerate(native):
    if n in allowedNativeGroups and i not in allowedNativeGroups[n]:continue
    assert m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5] in normal and re.sub(r'\s+','',m[6]) in normal,(n,normal)
  shas[z['file']]=hashlib.sha256(pathlib.Path(z['file']).read_bytes()).hexdigest()
 rows=next(s['rows'] for s in plans[calendarPlan.get(n,0)]['educationalSections'] if s['section']=='주별강의내용');own={int(r[0][:-1]):r for r in rows if r and re.fullmatch(r'\d+주',r[0])};spans=[]
 for w in ws:
  r=own[w];a,b,z,d=map(int,re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',r[1]).groups());spans.append((dt.date(2026,a,b),dt.date(2026,z,d),r))
 def permitted(day):
  if day.isoformat() in exceptDates.get(n,set()) or (day.isoformat() in closed and day.isoformat() not in holidayExceptions.get(n,set())):return False
  if n in explicitDates and day.isoformat() not in explicitDates[n]:return False
  return day.isoformat() in examExceptions.get(n,set()) or (not dt.date(2026,10,20)<=day<=dt.date(2026,10,26) and not dt.date(2026,12,15)<=day<=dt.date(2026,12,21))
 def actualRoom(r,base):
  w=int(r[0][:-1]);room=roomOverride.get(n,{}).get(w,base)
  if w in roomOverride.get(n,{}):assert room in ' '.join(r),(n,w,room)
  if any(k[0] in roomUnconfirmedWeekdays.get(n,set()) and k[3]==base for k in HH[n]):room=''
  return room
 meetings=[];independent=[]
 for ni,m in enumerate(native):
  if n in allowedNativeGroups and ni not in allowedNativeGroups[n]:continue
  if n in allowedWeekdays and ('월화수목금토일'.index(m[1])+1) not in allowedWeekdays[n]:continue
  wd='월화수목금토일'.index(m[1])+1
  for a,b,r in spans:
   day=a
   while day<=b:
    if day.isoweekday()==wd and permitted(day):meetings.append({'date':day.isoformat(),'weekday':wd,'startMinute':int(m[2])*60+int(m[3]),'endMinute':int(m[4])*60+int(m[5]),'classroom':actualRoom(r,m[6].strip())})
    day+=dt.timedelta(days=1)
 for a,b,r in spans:
  for ni,(wd,st,en,room) in enumerate(HH[n]):
   if n in allowedNativeGroups and ni not in allowedNativeGroups[n]:continue
   if n in allowedWeekdays and wd not in allowedWeekdays[n]:continue
   day=a+dt.timedelta(days=(wd-a.isoweekday())%7)
   while day<=b:
    if permitted(day):independent.append((day.isoformat(),wd,st,en,actualRoom(r,room)))
    day+=dt.timedelta(days=7)
 assert len(set(independent))==len(meetings);assert set(independent)=={(r['date'],r['weekday'],r['startMinute'],r['endMinute'],r['classroom']) for r in meetings}
 selected[c['sourceId']]=meetings;count+=len(meetings)
 proof.append({'packetOrdinal':n,'sourceId':c['sourceId'],'wholePlans':plans,'nativeClock':c['sourceSchedule'],'ownCampus':plans[0]['campus'],'literalNativeHH':HH[n],'allowedPhysicalWeeksLiteral':ws,'physicalRowsLiteral':[r for a,b,r in spans],'semanticReason':reasons[n],'explicitUnscheduledDatesLiteral':sorted(exceptDates.get(n,set())),'independentDates':sorted({k[0] for k in independent}),'literalIndependentMeetings':[list(k) for k in sorted(independent)],'ownExamNormalExceptionsLiteral':sorted(examExceptions.get(n,set())),'ownHolidayNormalExceptionsLiteral':sorted(holidayExceptions.get(n,set())),'ownExplicitDatesLiteral':sorted(explicitDates.get(n,set())),'ownRoomOverridesLiteral':roomOverride.get(n,{}),'roomUnconfirmedWeekdaysLiteral':sorted(roomUnconfirmedWeekdays.get(n,set())),'allowedWeekdaysLiteral':sorted(allowedWeekdays.get(n,set())),'allowedNativeGroupsLiteral':sorted(allowedNativeGroups.get(n,set(range(len(native))))),'calendarPlanIndex':calendarPlan.get(n,0),'newDateCount':len(meetings),'previousResearchDepartmentRemarks':c['departmentRemarks'],'remoteHoursGenerated':0})
for campus in ['seoul','global']:
 old=json.load(open(P.parent/'packet012-reviewed30'/f'khu-{campus}-2026-2.packet012-physical-groups-prepared.json'));(P/f'packet013-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside013'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet013-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet013-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2736,'baselineDates':51402,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2736+len(selected),'totalDates':51402+count})
