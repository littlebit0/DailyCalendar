# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet005-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={81: [(4, 810, 975, '생B105')], 82: [(3, 810, 975, '생510')], 85: [(1, 810, 885, '생B105'), (3, 810, 885, '생B105')], 90: [(1, 780, 890, '첨단강의실')], 91: [(4, 600, 710, '4강의실')], 92: [(2, 630, 740, '첨단강의실')], 93: [(2, 870, 980, ''), (2, 810, 860, '첨단강의실')], 95: [(3, 840, 950, '제1의학관 cbt실'), (3, 720, 830, '첨단강의실')], 97: [(2, 960, 1070, ''), (2, 900, 950, '4강의실')], 100: [(2, 960, 1070, ''), (2, 900, 950, '4강의실')], 102: [(2, 870, 990, ''), (2, 810, 860, '첨단강의실')], 108: [(5, 780, 890, '4강의실'), (5, 900, 1010, '')], 109: [(5, 900, 1010, ''), (5, 780, 890, '4강의실')], 110: [(4, 540, 590, '첨단강의실'), (4, 600, 710, '')]}
weeks={81: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 82: [1, 2, 3, 4, 5, 7, 9, 10, 11, 12, 13, 14], 85: [1, 2, 3, 4, 6, 7, 9, 10, 11, 12, 13, 14, 15], 90: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 91: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 92: [1, 2, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 93: [1, 2, 4, 5, 6, 7, 9, 10, 11, 12, 13], 95: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 97: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 100: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 102: [1, 2, 4, 5, 6, 7, 9, 10, 11, 12, 13], 108: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 109: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 110: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
allowedWeekdays={};exceptDates={};examExceptions={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
allowedNativeGroups={95:{1},97:{1},108:{0}}
calendarPlan={90:2,92:0,93:1,95:1,97:0,100:0,102:0,108:0,109:0,110:0}
reasons={81: 'Own exactMMDD whole physical Thursday13:30–16:15; physicalchildwelfare theory not childclinicalplacement.4closure8/16exams held.', 82: 'Own physical normal principle; scholarship8monthapplication/prereq not classperiod.6mixedmid15empty16finalpresentationheld;8regularAIclass own exam exception possible independentfollowup, noautomaticexamclock.', 83: 'Held: own grading video-upload-time attendance1/2days defines async vs own physical top; allocation conflict.3room rawnotchosen, no physical230minuteextent invented.', 84: 'Held: same explicit async attendance vs physicaltop currentplan conflict; nativeMonday230minute not VODfixedclock.5explicitholiday preserved.', 85: 'Own physical whole inclass default. Own5row sequential Inclass activity/No class matchesWedOct? WednesdaySep30 vsMonOct5closure but only ownweekday literal unallocated; holdwhole5 conservative.4teamconsultation+lecture whole group normal;8exam16finalheld.', 86: 'Held: sourceexplicitly not operated asclass; graduationshow prerequisite/courseeligibility not literalclassattendance. No HH.', 87: 'Held: actualinternship participation confirmation /fieldpractice no ownHH or individualplacements. Postreflectivemeetings likewise noHH.', 88: 'Held: actualexperiment/research/thesis noHH; field-practice rubric text not basis for semester recurring class.', 89: 'Held: actualmedicalresearch experiment ownHH absent; diseasehistorytopics not clinicalplacement claim.', 90: 'Own exact nativeMonday13–14:50 and two current full plans samewholecourse+14normalteachingweeks, one explicitteacherbyweekallocation. Two otherteacherempty plans preserved notclockproof. Microbiology topic not clinicalplacement. Choose teacherplan2 for wholecalendar currentproof;8/16examhold.', 91: 'Own regularcurrent physicaldefault, flipped e-campus video materials auxiliary rather than definite unknown replacedclass. NativeThursday10–11:50/currentweeks normal;8/16examhold.', 92: 'Own regularphysical current full-coordinatorplan explicitteacherbyweek andnativeTue10:30–12:20. Secondfullplan3Chuseok conflictscurrentcalendar/coordinatoractualclass: entire3groupheld withoutselectingone. Othersnormalweeks;empty3teacherplansretained.', 93: 'Own current anatomy lecture+animalmodel lab has two separatelypublishedTuesday13:30–14:20knownroomand14:30–16:20blankroom assigneddifferentteachers. Secondaryfull plan3wrongChuseokheld. Normalothergroups possible; blankroomnotblockbutlabdatedoperationreviewrequired, no clinicalcalendarborrow.', 94: 'Held: firstteacher definite mixed physical+recording scheduledbutunallocated, otherteachersphysicalplans do not overridewholeteamcurrentoperation; no teacher-to-weekallocationpriorityproof. All4ownplans/nativeHH preserved.', 95: 'Only separate own theory Wednesday12–13:50 whole current groups. Lab14–15:50 held: unspecified foursection rotation and own September3/10 Thursday dates conflict nativeWednesday. Theory 20minute early finish is possible future, not actual revised clock.', 96: 'Held: own proseMonday15–18 vs nativeending17:45 actual clock conflict; no contiguouspartialend invented.', 97: 'Only current full teacherplan own physical theory15–15:50. Other teacherlab16–17:50 lacks current operatingplan allocation, held with raw fullsource preserved.', 98: 'Held: actual research/field/recording tasks with no ownHH, no clinicalclock guess.', 99: 'Held: physical declared but ownHH unpublished, not borrowing same title section.', 100: 'Both current wholeteacherplans explicitly physical, exactsame two separate native clocks; blanklabroom preserved, laboratory/biologysubject not clinicalrotation.8/16examsheld.', 101: 'Held: individualresearch/mixed mode announcedafterorientation; even firstphysicalorientation lacks ownHH.', 102: 'Only normal theory/practice weeks with native clocks and own coordinator fullcurrentplan.3Chuseok conflictsactualcalendar held;14/15 anatomy lab allocation held pending specific dated operations. No othersection duration reused.', 103: 'Held: independentresearchcurrentweeklytopics but no absoluteHH.', 104: 'Held: individualtasklength-based researchmeetings, ownHH absent; attendance/clinicaltopics not a semesterclassclock.', 105: 'Held: weekly individualresearchmeeting noHH.', 106: 'Held: explicit class hoursnotfixed and individualprofessorappointments, noHH; second emptyteacherplan retained.', 107: 'Held: individualresearchmeetings noHH, all teacherplansretained.', 108: 'Only own full current plan explicit13–14:50 physicaltheory block. Native15–16:50 absent from allteacherplan HH and emptyco-teacheroperations: held, not inferredfromothersection. Wholeclinicalphysicstopics are theory/practice not clinicalfieldrotation.', 109: 'Own complete current coordinator explicitphysical lecture/experiment with both exactFriday independent blocks. Otheremptyteacherplan retained; roomunpublished blank.4closure8/16exam andOct9holiday excluded.', 110: 'Own complete current physicaltheory/project guide both explicitThursday blocks; videos are auxiliaryslides/material, not recordedclassreplacement.4closure8/16examheld.'}
assert len(HH)==14 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-81];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/('packet004b-whole-media-live' if campus=='seoul' else 'packet004-next50')/(f'khu-{campus}-2026-2.media-live-prepared.json' if campus=='seoul' else f'khu-{campus}-2026-2.packet004-physical-groups-prepared.json')));(P/f'packet005-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside004'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet005-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet005-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2641,'baselineDates':49940,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2641+len(selected),'totalDates':49940+count})
