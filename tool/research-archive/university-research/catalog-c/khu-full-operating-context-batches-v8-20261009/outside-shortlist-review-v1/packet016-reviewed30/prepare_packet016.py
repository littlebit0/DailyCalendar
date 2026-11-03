# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet016-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={411: [(2, 960, 1070, '음B101')], 413: [(2, 840, 950, '음B102')]}
weeks={411: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13], 413: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}
allowedWeekdays={};exceptDates={};examExceptions={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
allowedNativeGroups={}
calendarPlan={411:0,413:0}
reasons={411: '자체 원문 대면 불가한 주에 한하여 비대면비실시간이라고 명시. 현재 화16–17:50 음B101 정상1–7/9–13주12회만.14과제수행대체15강의없음16기말 및8일반시험은 제외. 공연관람비평 과제는 수업시간으로 만들지 않음.', 412: '매주대면 졸업논문 지도와10/11주연주 자체원문이나 절대요일HH 미공표.0학점·졸업예정자 제한 유지, 제목만으로 배제 아님.', 413: '현재 화14–15:50 음B102 정상1–7/9–14주13회. 임시공휴일/학과행사 일부 주차의 불가피한 온라인 가능 조건과 자료PDF를 실제 비동기 수업 배정과 구분.15자체기말8일반시험16일반기말기간 답안요해 제외. 선수 화성법1–3 또는 대응과목 반드시 이수 제한 보존.', 414: '건반화성학 자체 화16–17:50 전체창 있으나 학생별10분·1:1/2–3그룹, 첫주 개인시간 조정 명시. 개인배정 미확정으로 전체창 또는 임의10분 예약0.', 415: '현재 두 담당교수 전체계획 모두 읽음. 손정범1:1격주40분 절대HH/위상 미공표,육민경주차별듀오도HH 미공표. 다른교수시간 차용0.', 416: '자체 다른코드 두계획 모두읽음. 손정범격주40분/육민경파트너 수업의 절대HH 배정없음. 지속시간을 시작시각으로 추정0.', 417: '현재 강좌코드/교수는 원문에 있으나 교육·운영·주차 자체 공란,요일HH도 미공표. 실제 운영확인 보류.', 418: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 419: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 420: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 421: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 422: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 423: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 424: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 425: '현재 화11–12:50 창 있으나 자체계획 교육/운영/주차 공란. 강의실 공란만이 보류사유 아님;다른 동일교수 강좌 운영 차용0.', 426: '425와 구분된 자체 분반 현재전체원문 공란 확인. 화11–12:50 있으나 운영방식·주차 확정없어 보류.', 427: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 428: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 429: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 430: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 431: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 432: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 433: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 434: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 435: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 436: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 437: '해당 분반의 현재 전체 운영·주차·교육조건을 실제 확인. 대면 개인 성악/기악 실기이나 자체 절대 요일·시작종료HH가 미공표되어 보류. 자료·곡목·실기평가를 시간배정으로 사용하지 않음.', 438: '자체 일대일 학생역량별 성악수업 및 모든주차 확인. 절대요일HH 없어서 보류.', 439: '자체 코드·교수 및 전체교육을 직접확인,438과 동일본문이어도 독립identity 유지. 일대일HH 미공표.', 440: '자체 현재 성악실기8 전체교육/주차 확인. 일대일 수업의 절대요일HH 미공표. 같은교수/이전분반 시간 차용0.'}
assert len(HH)==2 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-411];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet015-reviewed30'/f'khu-{campus}-2026-2.packet015-physical-groups-prepared.json'));(P/f'packet016-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside016'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet016-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet016-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2758,'baselineDates':51712,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2758+len(selected),'totalDates':51712+count})
