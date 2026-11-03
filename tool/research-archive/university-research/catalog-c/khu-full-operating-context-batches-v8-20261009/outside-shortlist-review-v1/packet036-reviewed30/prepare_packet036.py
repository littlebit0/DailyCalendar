# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet036-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={1015: [(3, 600, 710, '네103')], 1024: [(1, 720, 795, '청404'), (3, 720, 795, '청404')], 1025: [(1, 630, 705, '청705'), (3, 630, 705, '청705')], 1026: [(2, 630, 705, '청704'), (4, 630, 705, '청704')], 1027: [(2, 720, 795, '청704'), (4, 720, 795, '청704')], 1028: [(1, 540, 615, '청704'), (3, 540, 615, '청704')], 1029: [(5, 720, 885, '청707')], 1030: [(4, 1170, 1305, '정403')], 1031: [(2, 630, 705, '청708'), (4, 630, 705, '청708')], 1032: [(2, 990, 1065, '청708'), (4, 990, 1065, '청708')], 1034: [(2, 900, 975, '청709'), (4, 900, 975, '청709')], 1035: [(2, 990, 1065, '청709'), (4, 990, 1065, '청709')], 1036: [(1, 810, 885, '청710'), (3, 810, 885, '청710')], 1037: [(1, 900, 975, '청710'), (3, 900, 975, '청710')], 1038: [(1, 630, 705, '청711'), (3, 630, 705, '청711')]}
weeks={1015: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], 1024: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 15], 1025: [1, 2, 3, 4, 5, 9, 10, 11, 12, 14, 15], 1026: [6], 1027: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1028: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1029: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1030: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1031: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1032: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1034: [1, 2, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16], 1035: [1, 2, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16], 1036: [1, 2, 3, 4, 5, 6, 8, 9, 11, 12, 13, 14], 1037: [1, 2, 3, 4, 5, 6, 8, 9, 11, 12, 13, 14], 1038: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
reasons={1011: '해외 교류 현재 native/기본정보 외 교육 공란, own HH 없음. 메타데이터 보존·예약 보류.', 1012: '봉사 현재 native만 확보, 전체 계획서 0·HH 미정. 수강 대상 제한 보존.', 1013: '봉사 현재 native만 확보, 전체 계획서 0·HH 미정. 수강 대상 제한 보존.', 1014: '봉사 현재 native만 확보, 전체 계획서 0·HH 미정. 수강 대상 제한 보존.', 1015: '자체 대면 이론+멘토링 기본, 수09? 실제 수10–11:50 네103. 주1–16 실제 이론·멘토링·모의면접·마감강의. 주8 적성검사는 교육 주제이며 실제 중간시험 배정 아님, 주16 마감강의. 웹 비대면 면접 주제는 모의 인터뷰 교육 내용이며 강좌 원격 배정 아님. 실제 수강 대상 상충 문구도 원문 보존.', 1016: '두 담당 자체 현재 기본 외 운영·주차/HH 교육 공란. native HH만으로 실제 운영 생성하지 않음.', 1017: '자체 계획 기본 외 운영·주차/HH 공란. native HH만으로 실제 운영 생성하지 않음.', 1018: '졸업논문 HH 없음·개별 논문 운영, 주간 출석 추정 0.', 1019: '현재 온라인 방법 선택·학생 수준/협의에 따라 운영 변경, 자체 대면/live 날짜 미확인. MPI 등 교육 주제를 운영 방식으로 전환하지 않음.', 1020: '졸업논문 HH 없음·기본 외 공란, 보류.', 1021: '대부분 대면이지만 현재 블렌디드 명시·날짜별 실제 배정 미확인, 보류.', 1022: '대부분 대면이지만 현재 블렌디드 명시·날짜별 실제 배정 미확인, 보류.', 1023: '자체 대부분 대면/블렌디드와 OFFLINE methods 문구·온라인 활동 병행이 함께 존재, actual 날짜 배정 우선순위 미확인. 임의 하나 선택하지 않음.', 1024: '자체 face-to-face 기본, 공휴일은 녹화 대체. 정상1–7/9–13/15만,14 개별 발표 배정·8/16 평가 보류. Oct5 녹화 HH 생성 0.', 1025: '자체 대면·현재 literal 날짜/wholegroup 일치하는 17개만. 과제 마감일은 출석 아님. Oct19 주8 불일치·Nov22 발표 일요일·Dec8 날짜 상충/개별 발표 배정은 보류, 도서관 위치 미확인 그룹 보류.', 1026: '자체 대면+동영상 병행의 전체 배정은 불명. 자체 주6 Oct6 화 실제 중앙도서관 정보교육실 교육 한 그룹만. Thu 및 다른 주차 대면 차용 0.', 1027: '자체 대면 기본+공휴일 녹화 명시. 정상1–7/9–14, 주6 TueOct6 자체 중앙도서관 정보교육실, 그 Thu 장소 배정 미확인으로 제외. 주15/시험 보류·동일 교수 다른 분반에 조건 전파 0.', 1028: '자체 대면+개별 literal 날짜 일치 19개. Sep30 도서관 정보교육 실제 위치 미공개라 classroom 빈값, 기존 청704 차용 0. 과거 평가 날짜와 현재 시험 문구 상충은 보존 보류; Dec2(월) 요일 상충 교정 0·표에 없는 Dec14 생성 0.', 1029: '자체 대면 기본, 조건부 원격 가능은 현재 배정 아님. 정상1–7/9–15, 전체 수업 내 발표/합평/교수 피드백. 공휴일/시험 제외·선수과목/1학년 수강불가 보존.', 1030: '자체 재직자전형 목19:30–21:45 정403 대면 기본·자체 전체 계획 정상1–7/9–15. 다른 분반 시각 차용 0, 대상 제한 보존.', 1031: '자체 주차 대면 표시, Sep24 녹화 제외. 정상1–7/9–14 발표+전체 토론/첨삭 수업, 주15 종강(기말고사)·8시험 보류.', 1032: '현재 S45 자체 HH·각 주차 대면 표시, 정상1–7/9–14만. S29와 교육 내용 정확 반복이어도 own identity/clock 독립 대조.', 1033: '30명 이하일 경우만 대면 조건, actual 현재 학생 수 미확인. 조건을 제거하지 않고 보류·개별 첨삭 배정 미확인도 보존.', 1034: '자체 현재 각 주차 대면 표시 1–3/5–7/9–16,16 실제 종합토론+최종 수정본은 시험 배정 아님.4 비대면+대면 혼합 actual그룹 미확인 제외. 조별 발표+전체 토론은 수업 내 전체 활동, 개별 출석 분할 추정 0.', 1035: '자체 현재 S46 각 주차 대면1–3/5–7/9–16,16 종합토론+최종수정은 실제 시험 배정 아님.4 혼합/8시험 제외. 전체 토론 유지·S42 HH 차용 0.', 1036: '자체 강의실 대면 기본, 네이버카페/영상/Zoom은 과제·조건부 사전공지. 정상1–6/8–9/11–14;7 중간·10도서관 장소 배정·15/16평가 제외.8 실제 음식 글쓰기 이론은 시험 배정 아님. 카페명의 과거 학기 문구 원문 보존.', 1037: '현재 S18 자체 대면 기본·HH/주차, 정상1–6/8–9/11–14. 외국인 전용반 제한 그대로. 조건부 원격·과거 카페명 보존·actual 원격 배정 주장 0.', 1038: '자체 대면 수업·조별토론 기본, 정상1–7/9–15. 교재·과정 글쓰기·합평은 수업 내 활동. 외국인/1학년 불가 제한 보존.', 1039: '교육 이론/팀활동은 있으나 온라인 방법 별도 선택·자체 대면/live 방식 배정 미확인. 보강 및 개별 피드백 HH 생성 0.', 1040: 'S12 자체 HH 있으나 실제 방식 미확인, 다른 교수 대면 차용 0. 현재 전체 원문/제약 보존.'}
groupWeeks={1015: {0: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]}, 1024: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 15]}, 1025: {0: [1, 2, 3, 4, 5, 9, 10, 11, 15], 1: [1, 2, 3, 4, 5, 10, 11, 12, 14]}, 1026: {0: [6]}, 1027: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 7, 9, 10, 11, 12, 13, 14]}, 1028: {0: [1, 2, 3, 4, 6, 7, 9, 10, 11, 14], 1: [1, 2, 3, 4, 5, 9, 12, 13, 15]}, 1029: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1030: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1031: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1032: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1034: {0: [1, 2, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16], 1: [1, 2, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16]}, 1035: {0: [1, 2, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16], 1: [1, 2, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16]}, 1036: {0: [1, 2, 3, 4, 5, 6, 8, 9, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 8, 9, 11, 12, 13, 14]}, 1037: {0: [1, 2, 3, 4, 5, 6, 8, 9, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 8, 9, 11, 12, 13, 14]}, 1038: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}}
groupPlan={1015: {0: 0}, 1024: {0: 0, 1: 0}, 1025: {0: 0, 1: 0}, 1026: {0: 0}, 1027: {0: 0, 1: 0}, 1028: {0: 0, 1: 0}, 1029: {0: 0}, 1030: {0: 0}, 1031: {0: 0, 1: 0}, 1032: {0: 0, 1: 0}, 1034: {0: 0, 1: 0}, 1035: {0: 0, 1: 0}, 1036: {0: 0, 1: 0}, 1037: {0: 0, 1: 0}, 1038: {0: 0, 1: 0}}
allowedWeekdays={};exceptDates={};holidayExceptions={};explicitDates={};roomUnconfirmedWeekdays={};roomOverride={1026: {6: '중앙도서관 정보교육실'}, 1027: {6: '중앙도서관 정보교육실'}, 1028: {5: ''}}
examExceptions={1015: {'2026-10-21', '2026-12-16'}, 1034: {'2026-12-15', '2026-12-17'}, 1035: {'2026-12-15', '2026-12-17'}, 1036: {'2026-10-21', '2026-10-26'}, 1037: {'2026-10-21', '2026-10-26'}}
allowedNativeGroups={1015: [0], 1024: [0, 1], 1025: [0, 1], 1026: [0], 1027: [0, 1], 1028: [0, 1], 1029: [0], 1030: [0], 1031: [0, 1], 1032: [0, 1], 1034: [0, 1], 1035: [0, 1], 1036: [0, 1], 1037: [0, 1], 1038: [0, 1]}
calendarPlan={1015: 0, 1024: 0, 1025: 0, 1026: 0, 1027: 0, 1028: 0, 1029: 0, 1030: 0, 1031: 0, 1032: 0, 1034: 0, 1035: 0, 1036: 0, 1037: 0, 1038: 0}
assert len(HH)==15 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-1011];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 ownGroupProof=[]
 for gi,pi in groupPlan[n].items():
  pl=plans[pi];bas=next(z['rows']for z in pl['educationalSections']if z['section']=='기본정보');clock=next(r[1]for r in bas if r[0]=='강의시간강의실');m=native[gi];hh=m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5];assert pl['queriedProfessorName']+' '+hh in clock,(n,gi,clock)
  pr=next(z['rows']for z in pl['educationalSections']if z['section']=='주별강의내용');gr={int(r[0][:-1]):r for r in pr if r and re.fullmatch(r'\d+주',r[0])}
  for ww in groupWeeks[n][gi]:assert gr[ww][1]==own[ww][1],(n,gi,ww)
  ownGroupProof.append({'nativeGroupIndex':gi,'ownProfessorPlanIndex':pi,'ownProfessor':pl['queriedProfessorName'],'ownBasicClockLiteral':clock,'ownPhysicalWeeklyRowsLiteral':[gr[w]for w in groupWeeks[n][gi]]})
 meetings=[];independent=[]
 for ni,m in enumerate(native):
  if n in allowedNativeGroups and ni not in allowedNativeGroups[n]:continue
  if n in allowedWeekdays and ('월화수목금토일'.index(m[1])+1) not in allowedWeekdays[n]:continue
  wd='월화수목금토일'.index(m[1])+1
  for a,b,r in spans:
   if int(r[0][:-1]) not in groupWeeks.get(n,{}).get(ni,ws):continue
   day=a
   while day<=b:
    if day.isoweekday()==wd and permitted(day):meetings.append({'date':day.isoformat(),'weekday':wd,'startMinute':int(m[2])*60+int(m[3]),'endMinute':int(m[4])*60+int(m[5]),'classroom':actualRoom(r,m[6].strip())})
    day+=dt.timedelta(days=1)
 for a,b,r in spans:
  for ni,(wd,st,en,room) in enumerate(HH[n]):
   if n in allowedNativeGroups and ni not in allowedNativeGroups[n]:continue
   if n in allowedWeekdays and wd not in allowedWeekdays[n]:continue
   if int(r[0][:-1]) not in groupWeeks.get(n,{}).get(ni,ws):continue
   day=a+dt.timedelta(days=(wd-a.isoweekday())%7)
   while day<=b:
    if permitted(day):independent.append((day.isoformat(),wd,st,en,actualRoom(r,room)))
    day+=dt.timedelta(days=7)
 assert len(set(independent))==len(meetings);assert set(independent)=={(r['date'],r['weekday'],r['startMinute'],r['endMinute'],r['classroom']) for r in meetings}
 selected[c['sourceId']]=meetings;count+=len(meetings)
 proof.append({'ownProfessorGroupProof':ownGroupProof,'packetOrdinal':n,'sourceId':c['sourceId'],'wholePlans':plans,'nativeClock':c['sourceSchedule'],'ownCampus':plans[0]['campus'],'literalNativeHH':HH[n],'allowedPhysicalWeeksLiteral':ws,'physicalRowsLiteral':[r for a,b,r in spans],'semanticReason':reasons[n],'explicitUnscheduledDatesLiteral':sorted(exceptDates.get(n,set())),'independentDates':sorted({k[0] for k in independent}),'literalIndependentMeetings':[list(k) for k in sorted(independent)],'ownExamNormalExceptionsLiteral':sorted(examExceptions.get(n,set())),'ownHolidayNormalExceptionsLiteral':sorted(holidayExceptions.get(n,set())),'ownExplicitDatesLiteral':sorted(explicitDates.get(n,set())),'ownRoomOverridesLiteral':roomOverride.get(n,{}),'roomUnconfirmedWeekdaysLiteral':sorted(roomUnconfirmedWeekdays.get(n,set())),'allowedWeekdaysLiteral':sorted(allowedWeekdays.get(n,set())),'allowedNativeGroupsLiteral':sorted(allowedNativeGroups.get(n,set(range(len(native))))),'ownGroupWeeksLiteral':groupWeeks.get(n,{}),'calendarPlanIndex':calendarPlan.get(n,0),'newDateCount':len(meetings),'previousResearchDepartmentRemarks':c['departmentRemarks'],'remoteHoursGenerated':0})
for campus in ['seoul','global']:
 old=json.load(open(P.parent/'packet034e-own-weekly-room-followup'/f'khu-{campus}-2026-2.followup958-prepared.json'));(P/f'packet036-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside036'}

 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet036-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet036-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2900,'baselineDates':54315,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2900+len(selected),'totalDates':54315+count})
