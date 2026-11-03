# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet029-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={801: [(2, 630, 705, '오307'), (4, 630, 705, '오307')], 803: [(3, 660, 770, '스B216'), (1, 900, 1065, '스B101(계단)')], 804: [(4, 540, 650, '스B245'), (3, 900, 1065, '스B101(계단)')], 805: [(1, 660, 770, '스B245'), (3, 900, 1065, '스B101(계단)')], 806: [(3, 900, 1065, '스B101(계단)'), (5, 900, 1010, '스B245')], 807: [(3, 660, 770, '스B211'), (1, 900, 1065, '스B101(계단)')], 808: [(1, 900, 1065, '스B101(계단)'), (3, 780, 890, '스B216')], 812: [(2, 810, 885, '스B111'), (4, 810, 885, '스B111')], 813: [(2, 900, 1010, '스B120'), (1, 810, 885, '스B113(계단)'), (3, 810, 885, '스B113(계단)')], 814: [(2, 900, 1010, '스B121'), (1, 810, 885, '스B113(계단)'), (3, 810, 885, '스B113(계단)')], 815: [(2, 900, 1010, '스B122'), (1, 810, 885, '스B113(계단)'), (3, 810, 885, '스B113(계단)')], 819: [(4, 660, 770, '스B216'), (4, 900, 1065, '스B113(계단)')], 822: [(1, 810, 885, '스B108'), (3, 810, 885, '스B108')], 825: [(5, 540, 705, '스B114(계단)'), (2, 660, 770, '스B245')], 827: [(4, 780, 890, '스B211'), (4, 900, 1065, '스B113(계단)')]}
weeks={801: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15], 803: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 804: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 805: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 806: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 807: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 808: [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16], 812: [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14], 813: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 814: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 815: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 819: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 822: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 825: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 827: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
reasons={801: '자체 화목10:30–11:45오307 대면위주 원칙·휴일과결강시만 비실시간보강.8시험9공란16시험 제외;Excel필수·학년권고·재수강 성적/제한 원문 유지.', 802: '동료코칭 이론/실습/토론 주제와 고정HH 존재하지만 온라인별도선택 실제 대면/live/VOD배정 미확인.학년및외국학생우선권 원문유지.', 803: '자체 이재열 대면수업원칙인 수11–12:50스B216만 부분.다른교수 월15–17:45 이론 운영추가 공란·별도온라인열 유지하며 전체전파0.8/16시험 제외.', 804: '자체 김태중 theory-only 계획 각정규주 강의실 명시인 수15–17:45스B101만.육순형 목실험 Zoom예정/대면방역미정 및 자체실험주차 보존/예약0.', 805: '자체 김태중 theory-only 계획 각정규주 강의실 명시인 수15–17:45스B101만.육순형 월실험 원격/대면방역미정 보존/예약0.다른분반 목시각차용0.', 806: '자체 김태중 각이론주 강의실·고정환 추가 이론강의실/실험실 진행 명시.각수이론15–17:45·금실험15–16:50 own전체보존.8/16시험및금휴일제외.', 807: '자체 구현주 수11–12:50스B211 대면실험/세미나각주명시.안전교육영상은대면시청이며VOD예약아님.이제승 월이론모드미확인 보존/예약0.', 808: '자체 WALKER 수13–14:50스B216 대면원칙 lab만부분.계획 주8정규Electrochemistry·주16CourseReview명시인10/21·12/16만 own시험기간정규예외;9시험제외.이제승월운영모드미확인전파0.', 809: '주정민 실제실험내용/안전과제 있으나 대면실제방식 미명시·온라인선택 유지;이제승 이론운영공란.물리실험주제만으로모드확정0.', 812: '자체각주대면+대면원칙 화목13:30–14:45스B111.8Directedmutagenesis 정상수업10/20·22만 예외;9actualmid15/16reportfinal 제외.가능기관견학은조건부만이며정규강의원문보존.', 813: '자체 김정민/채소연·박영석 currentcode/전체HH 대면 이론 월수13:30–14:45만부분.김은영 공란실험원문 유지하고화15–16:50실험배정전파0;팀티칭두교수원문모두보존.', 814: '자체 김정민/채소연·박영석 현재분반06/HH 대면이론 월수13:30–14:45만.김은영실험공란 전체보존·화실험예약0.생물학과외수강불허 보존.', 815: '자체 김정민/채소연·박영석 분반07대면이론월수13:30–14:45만.공란김은영실험계획과화스B122원문보존/실험예약0.', 819: '자체양지은 이론대면·실험대면및온라인 혼합을 명시하므로 목15–17:45스B113 theory만.이재열 대면원칙계획과 양지은실험mixed원문상충그대로보존·목11–12:50실험예약0.', 822: '실제 currentOperatingCorrection source전체추가검토,자체 대면수업진행명시·각정규주운영일치 월수13:30–14:45스B108.온라인열만blankethold 과거연구경고교정 전체archive,학교비고삭제0.8/16시험제외.', 825: '자체 정의헌 세미나와실험모두 일반물리실험실에서대면 명시인 화11–12:50스B245만.8실험RLC세미나10/20자체정규예외.원창연금theory운영공란 보존/예약0.', 827: '자체양지은 theory대면 목15–17:45스B113만.김영미 lab실제1/2온라인안전·6추석표기와datedmode미확인 전부보존,lab예약0.', 810: '자체 독립심화연구/실험/지도 원문 전체확인,weekly주제는있으나 요일·절대시작/종료HH 미공표.온라인/대면문구만으로 개별연구시간생성0.', 811: '자체 독립심화연구/실험/지도 원문 전체확인,weekly주제는있으나 요일·절대시작/종료HH 미공표.온라인/대면문구만으로 개별연구시간생성0.', 816: '자체 독립심화연구/실험/지도 원문 전체확인,weekly주제는있으나 요일·절대시작/종료HH 미공표.온라인/대면문구만으로 개별연구시간생성0.', 817: '자체 독립심화연구/실험/지도 원문 전체확인,weekly주제는있으나 요일·절대시작/종료HH 미공표.온라인/대면문구만으로 개별연구시간생성0.', 818: '자체 독립심화연구/실험/지도 원문 전체확인,weekly주제는있으나 요일·절대시작/종료HH 미공표.온라인/대면문구만으로 개별연구시간생성0.', 820: '자체 독립심화연구/실험/지도 원문 전체확인,weekly주제는있으나 요일·절대시작/종료HH 미공표.온라인/대면문구만으로 개별연구시간생성0.', 821: '자체 독립심화연구/실험/지도 원문 전체확인,weekly주제는있으나 요일·절대시작/종료HH 미공표.온라인/대면문구만으로 개별연구시간생성0.', 823: '자체 독립심화연구/실험/지도 원문 전체확인,weekly주제는있으나 요일·절대시작/종료HH 미공표.온라인/대면문구만으로 개별연구시간생성0.', 824: '자체 독립심화연구/실험/지도 원문 전체확인,weekly주제는있으나 요일·절대시작/종료HH 미공표.온라인/대면문구만으로 개별연구시간생성0.', 826: '자체 독립심화연구/실험/지도 원문 전체확인,weekly주제는있으나 요일·절대시작/종료HH 미공표.온라인/대면문구만으로 개별연구시간생성0.', 828: '자체 독립심화연구/실험/지도 원문 전체확인,weekly주제는있으나 요일·절대시작/종료HH 미공표.온라인/대면문구만으로 개별연구시간생성0.', 829: '자체 독립심화연구/실험/지도 원문 전체확인,weekly주제는있으나 요일·절대시작/종료HH 미공표.온라인/대면문구만으로 개별연구시간생성0.', 830: '자체 독립심화연구/실험/지도 원문 전체확인,weekly주제는있으나 요일·절대시작/종료HH 미공표.온라인/대면문구만으로 개별연구시간생성0.'}
allowedWeekdays={};exceptDates={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
examExceptions={808: {'2026-10-21', '2026-12-16'}, 812: {'2026-10-22', '2026-10-20'}, 825: {'2026-10-20'}}
allowedNativeGroups={803: [0], 804: [1], 805: [1], 807: [0], 808: [1], 813: [1, 2], 814: [1, 2], 815: [1, 2], 819: [1], 825: [1], 827: [1]}
calendarPlan={804: 1, 805: 1, 807: 1, 808: 1, 813: 2, 814: 0, 815: 2, 819: 1, 825: 1, 827: 1}
assert len(HH)==15 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-801];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet028b-fixed-physical-qa'/f'khu-{campus}-2026-2.packet028b-physical-groups-prepared.json'));(P/f'packet029-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside029'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet029-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet029-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2809,'baselineDates':52576,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2809+len(selected),'totalDates':52576+count})
