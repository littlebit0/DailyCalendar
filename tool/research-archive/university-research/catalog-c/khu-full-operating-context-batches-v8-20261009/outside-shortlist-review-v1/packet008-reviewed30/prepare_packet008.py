# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet008-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={173: [(1, 540, 650, '6강의실')], 174: [(3, 660, 710, '6강의실')], 176: [(1, 540, 650, '5강의실'), (3, 540, 650, '5강의실'), (1, 540, 650, '5강의실'), (3, 540, 650, '5강의실'), (5, 540, 650, '5강의실'), (3, 540, 650, '5강의실'), (5, 540, 650, '5강의실'), (1, 540, 650, '5강의실')], 178: [(4, 540, 650, '6강의실')], 182: [(4, 660, 710, '6강의실')], 191: [(4, 540, 615, '스356'), (1, 840, 915, '스356')], 192: [(4, 630, 720, '스357'), (1, 930, 1020, '스357')], 193: [(5, 840, 1005, '스356')], 195: [(2, 540, 705, '스357')], 198: [(4, 780, 855, '스357')], 199: [(4, 870, 945, '스356')]}
weeks={173: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 174: [2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 176: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 178: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 182: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 191: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 192: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 193: [1, 14, 15], 195: [1, 14, 15], 198: [1, 2, 3, 5, 6, 7], 199: [1, 2, 3, 5, 6, 7]}
allowedWeekdays={};exceptDates={};examExceptions={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
allowedNativeGroups={176:{0,1,4},191:{0},192:{0}}
calendarPlan={173: 1, 174: 4, 176: 2, 178: 2, 182: 0, 191: 3, 192: 2, 193: 2, 195: 2, 198: 0, 199: 1}
reasons={171: 'All6 complete plans operating/weekly empty; native HH absent. Held, no title-based clinical inference.', 172: 'All9 complete envelopes operating/weekly empty including repeated same-professor envelope. Native HH absent. Held.', 173: 'Complete physical responsible-teacher whole 1–15 weekly plan Monday09–10:50. Individual teacher8 literal10/21 Wednesday1stperiod conflicts ownnativeMonday; hold8 plus exams and closures, preserve all source conflicts. Narrow remaining physical candidate pending fullpacket.', 174: 'Full physical theory plan Wednesday11–11:50. Week1 remark2교시 unspecified whether duration/period, hold1 without clockguess; remaining assigned regular weeks candidate pending fullpacket.', 175: 'Individual physical theory declared but all weekly topics empty/remaining3 envelopes empty; individual dates allocation unconfirmed, held.', 176: 'Full current physical-centred theory coordinator regular Mon/Wed/Fri09–10:50; duplicate native8groups exactlysameweekdayHH collapse onlyreservation. Possiblevideo makeup and future changes after studentreturn not actual datedreplacement; prerequisite attendees may substitute reports, preserve restriction without declaring individual attendance. Narrow currentphysical groups candidate pending fullpacket.', 177: 'Held: actual clinical ward/outpatient/centre dispatch A/B group rotation; own clocks absent; contingency Zoom not current fixed live.', 178: 'Complete current physical theory whole plan Thursday09–10:50, all16 weekly topics assigned. Clinical disorders are instructional topics, not clinical placement. Normal weeks candidate; exam/holiday exclude.', 179: 'Held: hospital 5-day allocated clinical dispatch; other teacher explicitly only dispatched weeks taught, no absolute HH and individual dispatch-week allocation. Wednesday topic is not exact clock.', 180: 'Held: self-study/mock clinical evaluation with no allocated native clock.', 181: 'Held: current physical principle explicitly permits live or asynchronous online delivery without dated allocation; independent physical plan has empty weekly assignment.', 182: 'Candidate: current complete physical theory, Thursday11–11:50 room6; all16 weekly topics. Preserve explicit dermatology-major-only enrollment restriction, normal nonexam weeks only.', 183: 'Held: clinical preparation practical/three-day activity notes but no published own weekday/HH.', 184: 'Held: physical clinical-preparation instruction and four-day activity note, no own weekday/HH.', 185: 'Held: explicitly spans third-year second semester and fourth-year two semesters, assessments individually operated; no published own HH.', 186: 'Held: current full envelope contains empty educational operation and no own HH.', 187: 'Held: own Friday15:30–16:00 published but another current complete plan explicitly combines physical and online modes without per-date allocation; no independent selected physical weeks.', 188: 'Held: full educational operation/weekly body empty and no native HH.', 189: 'Held: actual hospital bedside/outpatient clinical practice; no own HH; report deadlines Friday09 and Tuesday17 not course clocks.', 190: 'Held: current clinical group hospital/outpatient/CPX/OSCE, no own HH; no analogous-course clock borrowing.', 191: 'Partial candidate Thursday09–10:15 room스356 explicitly assigned 심범상 physical whole1–15 and holidays recording. Monday teacher plans partly asynchronous without date allocation, hold that independent group; preserve raw all.', 192: 'Partial candidate Thursday10:30–12:00 room스357 explicitly assigned 심범상 physical whole1–15, holiday recording excluded. Monday15:30–17 unallocated remote groups held.', 193: 'Partial candidate only full physical theory weeks1,14,15; weeks2–11 explicitly flipped/assignments duration cannot allocate whole native165min; team presentation60min not whole165min.', 194: 'Held: complete shared plans physical+flipped mixed operation with online method, no individual dated full physical allocation.', 195: 'Partial candidate theory weeks1,14,15 same source assigned instructors/nativeTuesday09–11:45; flipped/team duration not whole165min, preserve all.', 196: 'Held: real hospital group practice/rounds/outpatient, no own HH.', 197: 'Held: Saturday only, individual1:1 coaching and published seminar room but no start/end clock.', 198: 'Current first teacher physical principle and midterm-before half assigned by own evaluation; own first1–7 weekly plan. Later teacher explicitly physical+async9–15, hold whole later groups; holiday4 excluded. Future necessary remote possibility not selected replacement; all source preserved.', 199: 'Current first teacher physical principle and midterm-before half assigned by own evaluation; own first1–7 weekly plan. Later teacher explicitly physical+async9–15, hold whole later groups; holiday4 excluded. Future necessary remote possibility not selected replacement; all source preserved.', 200: 'Held: all three plans select nonreal-time online; individual statement physical contradicts same plan operation selection, no fixed native slot projection.'}
assert len(HH)==11 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-171];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet007-next30'/f'khu-{campus}-2026-2.packet007-physical-groups-prepared.json'));(P/f'packet008-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside008'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet008-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet008-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2677,'baselineDates':50567,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2677+len(selected),'totalDates':50567+count})
