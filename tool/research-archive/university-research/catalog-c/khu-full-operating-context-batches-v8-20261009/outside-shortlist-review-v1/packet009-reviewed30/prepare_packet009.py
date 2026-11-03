# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet009-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={203: [(5, 840, 975, '스357')], 204: [(3, 840, 975, '스356')], 221: [(2, 600, 770, '스358')]}
weeks={203: [1, 2, 3, 5, 7, 9, 10, 11, 12, 13, 14, 15], 204: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 221: [1, 2, 3, 4, 9, 10, 11, 12, 15]}
allowedWeekdays={};exceptDates={};examExceptions={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
allowedNativeGroups={}
calendarPlan={203:0,204:0,221:0}
reasons={201: 'Held: native HH blank; actual hospital rotation and OSCE/CPX with no absolute HH or individual dispatch mapping.', 202: 'Held: four actual current clinical plans; native HH blank; total durations and reflection 30min are not clock.', 203: 'Candidate: Friday 14:00–16:15 스357, physical principle; homework upload is not replacement; weekly 4 explicitly asynchronous, 6 Oct7 makeup has no HH. Keep weeks1,2,3,5,7,9,10,11,12,13,14,15 only, normal Friday12 dates; no makeup time invented.', 204: 'Candidate: Wednesday14:00–16:15 스356, complete current physical weekly plan; holiday-only async clause, no Wednesday closure; normal14 dates excluding exam8/16.', 205: 'Held: physical operation confirmed in all three plans but native HH blank and no absolute HH in full educational plans.', 206: 'Held: four physical clinical plans but native and own plan HH blank.', 207: 'Held: full17 plans read. Native Mon18–18:50 and physical principle are printed, but multiple current plans explicitly Block lecture immediately before clinical internship 15/16hours; own actual date range unknown. Other full weekly topic sequence does not resolve block-operating contradiction. No whole semester inference.', 208: 'Held: full3 plans describe hospital rotation/CPX/OSCE/VR and actual physical practice, no absolute HH.', 209: 'Held: full3 plans describe hospital practice; native and own HH blank.', 210: 'Held: actual Monday arrival08:30 and explicitly override weekly label by literal dates8/31–12/14 incl10/5holiday. No end HH; arrival alone not whole clinical attendance start-end. Other plan current morning/afternoon practice plus video/live unallocated. Friday15:00 report deadline is not class.', 211: 'Held: all4 plans actual13groups each assigned one clinical week; explicit Mon–Fri08–12/13:30–17:30 published, but individual group→week/teacher/location dispatch unknown. Do not schedule all13weeks for each student; no firstweek intro HH.', 212: 'Held: all4 fullplans actual13groups each only one clinical week, HH08–12/13:30–17:30 published but group→week allocation unknown and source teacher-specific activity choices differ; no all-semester rotation inference.', 213: 'Held: all4 actual current clinical plans one week per13groups; some explicit08–12/13:30–17:30 but individual assignment unknown.', 214: 'Held: all4 actualcurrent clinical plans same one-week13group limit; no individual date assignment and conflicting/varied clinical activity timetable preserved.', 215: 'Held: physical theory/research instruction confirmed; native Saturday only, no clock. Professor graduate affiliation is not graduate offering; current undergraduate metadata retained.', 216: 'Held: physical principle and actual AI instruction current weekly plans; Saturday noHH; no clinicaltitle assumptions.', 217: 'Held: two physical hospitalpractice plans, no absolute clock in ownsource/native.', 218: 'Held: native09:00–09:05 published without weekday, own actual clinical planning does not resolve weekday/whole attendance clock; preserve literal no correction.', 219: 'Held: four fullplans actual one-week group split4hospitalparts, native HHblank, personalweek/date allocationunknown.', 220: 'Held: four fullplans actual one-week group split4hospitalparts, explicit physical+Zoom+content unallocated and HHblank.', 221: 'Partial physical weeks1,2,3,4,9,10,11,12,15 explicitly assigned by all five current plans; whole native Tuesday10:00–12:50 room스358. Weeks5–7 hybrid/flipped unallocated;13–14 nonlive e-campus unclear live timing remain held. Exams excluded. All professor variants retained, no picked teacher.', 222: 'All six current full hospital bedside clinical/theory/CPX plans read; actual duration1–2h not absolute HH; native weekday/HH absent, held.', 223: 'All six current full physical/online clinical/theory plans read; native weekday/HH absent, held.', 224: 'All four full plans physical group hospital/outpatient weekly practice; no published weekday/start/end HH, held.', 225: 'Both full current graduation-thesis plans read; own meeting weekday and HH absent, held. Graduate teacher affiliation is not offering-level graduate scope.', 226: 'Own current physical theory/practical weekly plan read; native weekday and absolute HH absent. Midterm remote instruction also unallocated, held.', 227: 'Own physical discussion plan Saturday only, no start/end HH. Held without replacing publication gap by title inference.', 228: 'Own full physical discussion plan Saturday only, no absolute HH, held.', 229: 'Separate exact section01 current full physical discussion plan Saturday only, no HH. Section02 clock not borrowed, held.', 230: 'Actual each-group one-week hospital clinical teaching explicitly stated; native HH/weekday and individual week assignment absent. Arrival conference mention not clock, held.'}
assert len(HH)==3 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-201];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet008-reviewed30'/f'khu-{campus}-2026-2.packet008-physical-groups-prepared.json'));(P/f'packet009-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside009'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet009-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet009-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2688,'baselineDates':50702,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2688+len(selected),'totalDates':50702+count})
