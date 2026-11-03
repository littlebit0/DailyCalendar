# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet007-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={145: [(1, 660, 770, '5강의실'), (3, 660, 770, '5강의실'), (1, 660, 770, '5강의실')], 146: [(2, 840, 1070, '실습실1'), (4, 840, 1070, '실습실1'), (2, 840, 1070, '실습실1')], 147: [(2, 660, 770, '5강의실'), (4, 660, 770, '5강의실'), (2, 660, 770, '5강의실')], 149: [(5, 960, 1010, '2강의실')], 150: [(1, 840, 950, '5강의실'), (3, 840, 950, '5강의실'), (1, 840, 950, '5강의실')], 152: [(2, 540, 650, '6강의실')], 155: [(2, 660, 710, '6강의실')], 157: [(4, 780, 870, '6강의실')], 158: [(5, 900, 930, '2강의실')], 164: [(1, 780, 890, '6강의실')], 166: [(5, 540, 650, '6강의실')]}
weeks={145: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 146: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 15], 147: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 149: [1, 2, 3, 4, 5, 6, 7], 150: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 152: [1, 2, 3, 4, 6, 9, 10, 11, 12, 13, 14, 15], 155: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 157: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 158: [1, 2, 3, 4], 164: [11], 166: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
allowedWeekdays={};exceptDates={};examExceptions={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
allowedNativeGroups={145:{0,1},146:{0,1},147:{0,1},150:{0,1}}
calendarPlan={146:8,152:6,155:4,157:15,164:3,166:9}
reasons={141: 'Held: field company experience own clock unpublished.', 142: 'Held: individual research own clock unpublished.', 143: 'Held: museum mentor field experience may combine weeks; own clock unpublished; all prerequisites retained.', 144: 'Held: research clock unpublished.', 145: 'Both complete current pharmacology theory plans physical; exact own Monday/Wednesday slots, duplicate Monday identical collapsed only for reservation; all original groups retained.', 146: 'Current basic medical laboratory coordinator physical whole plans share native Tue/Thu clocks; unrelated clinical rotation not inferred. Week14 department operating unit differs between full plans; hold that whole week. Identical duplicate Tue preserved raw and collapsed reservation only.', 147: 'Complete current microbiology theory physical; own Tue/Thu clocks; duplicate Tuesday retained raw only.', 148: 'Held: graduation evaluation own clock unpublished.', 149: 'Current clinical pharmacology physical theory only weeks1–7 assigned; future possible online replacement not actual. Other weeks empty/exams held; school holidays excluded.', 150: 'Two complete current pathology theory physical plans, same native Mon/Wed; duplicate Monday raw preserved.', 151: 'Held: actual clinical ward/outpatient two-week individual allocation; own exact dates and clock unpublished.', 152: 'Current whole physical endocrine theory; other full plan explicitly no lecture weeks5/7 conflicts remaining full plans, so both whole weeks held; exam weeks excluded.', 153: 'Held: native Friday13–13:50 conflicts individual current September30 first-period dated teaching; integrated operating allocation not established.', 154: 'Held: whole plan theory does not declare physical mode; individual CiscoWebex and empty physical teacher plans do not establish entire live/physical allocation.', 155: 'Two full current physical ENT theory plans and full offline mixed teaching plan preserve exact native Tuesday11–11:50; no actual hospital rotation mandated.', 156: 'Held: actual ward/outpatient practice; own clock and individual dates unpublished.', 157: 'Current responsible teacher complete whole physical theory with own Thursday13–14:30 and assigned weekly teaching; case video is auxiliary teaching material.', 158: 'Current complete physical chest surgery theory plan assigns weeks1–4 only; remaining weeks empty. Exact Friday15–15:30; September25 closed.', 159: 'Held: all22 plans operating/body/weekly fields empty and clock unpublished; title alone not clinical placement evidence.', 160: 'Held: one full current physical theory plan versus another actual clinical operation/individual practice and spring6/12–16 assessment text; no authority to choose whole source.', 161: 'Held: actual one week main hospital and one week Gangdong rotation; own allocation dates/clock unpublished.', 162: 'Held: actual clinical examination observation requires individual schedule confirmation and allocation; own clock unpublished.', 163: 'Held: all15 complete plan envelopes contain empty operating/weekly fields and native clock absent; no clinical operation inferred from title.', 164: 'Own physical teacher explicitly assigns week11 topic and same native Monday13–14:50; remaining coordinator weekly topics unallocated, preserve pending groups rather than infer all weeks.', 165: 'Held: all11 complete plan envelopes empty operating/weekly fields, own clock unpublished; no title-based clinical assertion.', 166: 'Complete current physical pediatric theory plan with16 assigned weeks, own Friday09–10:50; PPT video is classroom aid, not asynchronous replacement. Closures and exams excluded.', 167: 'Held: actual clinical assessment physical declared but own absolute clock unpublished.', 168: 'Held: actual hospital clinical practice with alternating hospital instructions and individual start orientation; native clock unpublished.', 169: 'Held: all13 complete plans operating/body/weekly empty; native Wednesday known but current teaching mode and whole operation unconfirmed.', 170: 'Held: actual3-week group clinical rotation and each professor date/time individually confirmed, workday08:30–17:30 is not allocated course meeting.'}
assert len(HH)==11 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-141];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet006-next50'/f'khu-{campus}-2026-2.packet006-physical-groups-prepared.json'));(P/f'packet007-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside007'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet007-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet007-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2666,'baselineDates':50401,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2666+len(selected),'totalDates':50401+count})
