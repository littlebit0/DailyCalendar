# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet030-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={838: [(3, 780, 890, '스B120'), (1, 630, 705, '스B113(계단)'), (3, 630, 705, '스B113(계단)')], 839: [(3, 780, 890, '스B121'), (1, 630, 705, '스B113(계단)'), (3, 630, 705, '스B113(계단)')], 840: [(2, 990, 1065, '스B114(계단)'), (4, 990, 1065, '스B114(계단)')], 841: [(5, 780, 890, '스B216'), (1, 720, 795, '스B112'), (3, 720, 795, '스B112')], 842: [(1, 780, 890, '스B245'), (4, 630, 795, '스B114(계단)')], 843: [(1, 900, 1010, '스B245'), (4, 630, 795, '스B114(계단)')], 844: [(1, 540, 615, '스B103'), (3, 540, 615, '스B103'), (5, 600, 710, '스B103')], 845: [(2, 660, 770, '스B216'), (2, 900, 1065, '스B113(계단)')], 848: [(2, 900, 975, '스B111'), (4, 900, 975, '스B111')], 849: [(4, 900, 1010, '스B211'), (4, 540, 705, '스B112')], 850: [(2, 660, 770, '스B211'), (2, 900, 1065, '스B113(계단)')], 851: [(4, 780, 890, '스B121'), (2, 900, 975, '스B114(계단)'), (4, 780, 890, '스B121'), (4, 900, 975, '스B114(계단)'), (2, 900, 975, '스B114(계단)'), (4, 900, 975, '스B114(계단)')], 852: [(4, 780, 890, '스B122'), (2, 900, 975, '스B114(계단)'), (4, 780, 890, '스B122'), (4, 900, 975, '스B114(계단)'), (2, 900, 975, '스B114(계단)'), (4, 900, 975, '스B114(계단)')], 853: [(1, 900, 1010, '스B216'), (1, 630, 705, '스B110(계단)'), (3, 630, 705, '스B110(계단)')], 854: [(2, 540, 705, '스B112'), (2, 780, 890, '스B245')], 855: [(2, 630, 795, '스B114(계단)'), (5, 540, 650, '스B245')], 856: [(2, 630, 795, '스B114(계단)'), (5, 660, 770, '스B245')], 857: [(2, 630, 795, '스B114(계단)'), (3, 900, 1010, '스B245')], 859: [(1, 810, 885, '스B102'), (3, 810, 885, '스B102')]}
weeks={838: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 839: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 840: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 841: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 842: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 843: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 844: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 845: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 848: [1, 3, 4, 6, 7, 9, 10, 11, 12, 13, 14, 15], 849: [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16], 850: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 851: [11, 12, 13, 14, 15], 852: [11, 12, 13, 14, 15], 853: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 854: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 855: [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15], 856: [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15], 857: [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15], 859: [2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13]}
reasons={837: '자체100%대면 문구와 실제수업안내 비대면강의·자료업로드가 상충하고 현재요일별모드배정이 없음.하나를선택하지않고 전체held.', 838: '자체김정민100%대면과 박영석대면원칙에 해당하는 월수10:30–11:45스B113 이론만.실험교수김은영공란을다른교수원칙으로채우지않으며 수13–14:50labheld.화학/자율전공외수강제한원문보존.', 839: '자체분반04 김정민100%대면/박영석대면원칙 월수10:30–11:45theory만.수13–14:50김은영실험운영공란held;수강제한/전체교수원문보존.', 840: '대면진행과 출장시만녹화 조건을구분, 화목16:30–17:45 자체정규주만.스펙트럼/대학원수준은학문내용이지현재학부개설배제사유가아님.시험8/16제외.', 841: '박승민대면강의및실험과 하상수대면원칙 각각현분반전체시각/운영일치.월수12–13:15이론+금13–14:50실험.학과장승인/자율전공제한원문보존;8/16시험제외.', 842: '안정선theory-only 계획의 영상사전학습과 스B114강의실대면활동을구분해 목10:30–13:15만.김낙우lab운영 실험수업문구만으로 physical배정확정하지않고월실험held.', 843: '안정선명시강의실대면활동 목10:30–13:15만.녹화사전학습시각생성0.월15–16:50김낙우lab별도계획모드미확인held.', 844: '대면기본/상황시원격조건을구분한 자체월수09–10:15금10–11:50 정규공통주.화학과외수강제한보존;과제퀴즈를원격수업으로오인하지않음.', 845: '신혜영대면theory+송재규대면수업및실험/세미나가자체분반화11–12:50/15–17:45와일치.8/16시험제외,수강제한학교문구삭제0.', 848: '자체Offline수업원칙·주별recorded 실제배정구분.2주영상+혼합의요일불명 전체제외,5주9/29·10/1영상둘다제외,9주10/29영상제외하고10/27정규만.8/16시험제외.녹화시각생성0.', 849: 'Walker대면lab 목15–16:50만,김용준theory실제대면/비대면/실험혼합요일배정미확인held.자체8주Electrochemistry10/22·16주CourseReview12/17 정규시험기간예외만.', 850: '자체신혜영대면theory와 양지은추가설명 실험대면을각그룹에대조.화11–12:50lab/15–17:45theory 정상공통주만;다른강좌양지은혼합문구전파0.', 851: '김은영자체실험대면원칙과 현목13–14:50스B121 lab그룹.11–15주배아관찰/전기영동/결과분석 정상계획만부분;1–10실내외안전·트랩·생태조사위치불확정held.다른교수theory실제비실시간/전반기원격혼합일정미확인held.중복lab원문둘다보존하고한동일group만배치.', 852: '김은영자체실험대면원칙 현분반01목13–14:50스B122 lab11–15주만부분.1–10주생태실험실외배정불확정held;한창석혼합/박영석전반기비대면theory일정held.중복원문6전체보존;다른분반room차용0.', 853: '정민석이론실험모두대면·이재열대면원칙 각현재HH일치.월15–16:50lab 월수10:30–11:45theory.이론공동분반과실험별도분반원문보존;8/16시험제외.', 854: '김태중theory각주강의실과 김진교명시대면실험 각각자체화clock.공통1–7/9–14주만우선;lab8정규와theory15정규는교수별날짜추가검증lead로별도보존.시험/공란을다른그룹에전파0.', 855: '안정선사전영상과강의실대면활동/손석균실제대면실험각자체화theory금lab.공통1–6/9–15주만;lab7중간보충실험혼합held.교수별theory7/lab8 정상은추가lead 보존.', 856: '자체분반03 화theory10:30–13:15·금lab11–12:50 각명시대면 공통1–6/9–15주.중간보충실험7주미확정held;영상사전학습은시간생성0.', 857: '자체분반01 화theory10:30–13:15·수lab15–16:50 각명시대면 공통1–6/9–15주.원격사전영상과physical활동구분;교수별7/8일정lead보존.', 858: '캡스톤고정HH/프로젝트주제만있으며실험수업유형이외실제대면/live/녹화배정근거미확인.온라인열과전체학교원문보존held.', 859: '자체24대면강의명시,월수13:30–14:45 2–7/9–13주만.1/14/15휴강요일특정불가하여wholeweekheld.8퀴즈와정규혼합시험주배정미확인held,16기말12/21 18:30–21별도원문보존/시험시각생성0.', 831: '자체개별연구/졸업지도운영·교육주제전체확인했으나 절대요일시작/종료HH없음.대면/온라인표기만으로개별시간생성0.', 832: '자체개별연구/졸업지도운영·교육주제전체확인했으나 절대요일시작/종료HH없음.대면/온라인표기만으로개별시간생성0.', 833: '자체개별연구/졸업지도운영·교육주제전체확인했으나 절대요일시작/종료HH없음.대면/온라인표기만으로개별시간생성0.', 834: '자체개별연구/졸업지도운영·교육주제전체확인했으나 절대요일시작/종료HH없음.대면/온라인표기만으로개별시간생성0.', 835: '자체개별연구/졸업지도운영·교육주제전체확인했으나 절대요일시작/종료HH없음.대면/온라인표기만으로개별시간생성0.', 836: '자체개별연구/졸업지도운영·교육주제전체확인했으나 절대요일시작/종료HH없음.대면/온라인표기만으로개별시간생성0.', 846: '자체개별연구/졸업지도운영·교육주제전체확인했으나 절대요일시작/종료HH없음.대면/온라인표기만으로개별시간생성0.', 847: '자체개별연구/졸업지도운영·교육주제전체확인했으나 절대요일시작/종료HH없음.대면/온라인표기만으로개별시간생성0.', 860: '자체개별연구/졸업지도운영·교육주제전체확인했으나 절대요일시작/종료HH없음.대면/온라인표기만으로개별시간생성0.'}
allowedWeekdays={};exceptDates={848:{'2026-10-29'}};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
examExceptions={849: {'2026-10-22', '2026-12-17'}}
allowedNativeGroups={838: [1, 2], 839: [1, 2], 842: [1], 843: [1], 849: [0], 851: [0], 852: [0]}
calendarPlan={838: 3, 839: 2, 842: 0, 843: 0, 849: 0, 850: 0, 851: 1, 852: 0, 853: 1, 854: 1, 855: 0, 856: 1, 857: 1}
assert len(HH)==19 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-831];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet029-reviewed30'/f'khu-{campus}-2026-2.packet029-physical-groups-prepared.json'));(P/f'packet030-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside030'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet030-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet030-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2824,'baselineDates':52872,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2824+len(selected),'totalDates':52872+count})
