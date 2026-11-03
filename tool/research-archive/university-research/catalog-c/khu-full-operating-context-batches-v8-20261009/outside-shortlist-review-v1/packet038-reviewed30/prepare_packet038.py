# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet038-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={1072: [(1, 630, 705, '청207'), (3, 630, 705, '청207')], 1073: [(1, 630, 705, '청207'), (3, 630, 705, '청207')], 1081: [(2, 720, 795, '청309'), (4, 720, 795, '청309')], 1082: [(2, 720, 795, '청309'), (4, 720, 795, '청309')], 1089: [(5, 540, 705, '청203')], 1090: [(5, 900, 1065, '청503')], 1091: [(6, 780, 945, '호703')], 1092: [(1, 720, 885, '청502')], 1093: [(1, 900, 1065, '청502')]}
weeks={1072: [1, 2, 3, 5, 9, 10, 12, 13, 15], 1073: [1, 2, 4, 6, 7, 9, 10, 11, 13, 14], 1081: [1, 2, 5, 6, 7], 1082: [1, 9], 1089: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1090: [1, 2, 3, 5, 6, 7, 8, 11, 12, 14, 15], 1091: [1, 2, 3, 5, 6, 7, 8, 11, 12, 14, 15], 1092: [1, 2, 3, 4, 5, 6, 7, 8, 14], 1093: [1, 2, 3, 4, 5, 6, 7, 14]}
reasons={1071: '대면 강의실 활동 일정이1주차 조편성 후 최종확정 예정이며 주차는 온라인/대면 혼합. 실제 물리 그룹 날짜 배정 미확인으로 보류.', 1072: '두 교수 current literal 날짜와 대면 운영이 일치하는 자체 그룹만. 특강/박물관 방문·시험·녹화는 예약0. S05 Oct19 대면/비실시간 상충 및 중간시험10/21vs10/26 상충을 선택/교정하지 않고 제외하여 보존.', 1073: '두 교수 current literal 날짜와 대면 운영이 일치하는 자체 그룹만. 특강/박물관 방문·시험·녹화는 예약0. S05 Oct19 대면/비실시간 상충 및 중간시험10/21vs10/26 상충을 선택/교정하지 않고 제외하여 보존.', 1074: '현재 native 전체·교수별 전체교육계획과 자체 운영·주차·제한을 읽음. 실제 정규 대면 날짜와 녹화·별도 운영의 배정이 불명확하거나 상충하여 이번 후보 보류; 원문·전체 비고 보존.', 1075: '현재 native 전체·교수별 전체교육계획과 자체 운영·주차·제한을 읽음. 실제 정규 대면 날짜와 녹화·별도 운영의 배정이 불명확하거나 상충하여 이번 후보 보류; 원문·전체 비고 보존.', 1076: '현재 native 전체·교수별 전체교육계획과 자체 운영·주차·제한을 읽음. 실제 정규 대면 날짜와 녹화·별도 운영의 배정이 불명확하거나 상충하여 이번 후보 보류; 원문·전체 비고 보존.', 1077: '현재 native 전체·교수별 전체교육계획과 자체 운영·주차·제한을 읽음. 실제 정규 대면 날짜와 녹화·별도 운영의 배정이 불명확하거나 상충하여 이번 후보 보류; 원문·전체 비고 보존.', 1078: '현재 native 전체·교수별 전체교육계획과 자체 운영·주차·제한을 읽음. 실제 정규 대면 날짜와 녹화·별도 운영의 배정이 불명확하거나 상충하여 이번 후보 보류; 원문·전체 비고 보존.', 1079: '현재 native 전체·교수별 전체교육계획과 자체 운영·주차·제한을 읽음. 실제 정규 대면 날짜와 녹화·별도 운영의 배정이 불명확하거나 상충하여 이번 후보 보류; 원문·전체 비고 보존.', 1080: '현재 native 전체만 확인, 계획서0. 기존 currentOperatingCorrection 보류 사유/전체 객체 유지, 철회0.', 1081: '두 교수 자체 첫7주 literal 강의실 날짜가 일치하는9/1,9/8,9/29,10/6,10/13만. 후반부 한 원문은 실제 방식 공란으로 과학과 상상력 주제만 대면으로 추론하지 않음.', 1082: '두 교수 literal 강의실이 모두 명시된9/1과10/27만. 9/8vs9/10,9/29vs10/1,10/6vs10/8,10/13vs10/15 강의실/e-campus 역배정은 임의 선택 없이 보류. 나머지 주제명만으로 대면 추론0.', 1083: '현재 native 전체·교수별 전체교육계획과 자체 운영·주차·제한을 읽음. 실제 정규 대면 날짜와 녹화·별도 운영의 배정이 불명확하거나 상충하여 이번 후보 보류; 원문·전체 비고 보존.', 1084: '현재 native 전체·교수별 전체교육계획과 자체 운영·주차·제한을 읽음. 실제 정규 대면 날짜와 녹화·별도 운영의 배정이 불명확하거나 상충하여 이번 후보 보류; 원문·전체 비고 보존.', 1085: '현재 native 전체·교수별 전체교육계획과 자체 운영·주차·제한을 읽음. 실제 정규 대면 날짜와 녹화·별도 운영의 배정이 불명확하거나 상충하여 이번 후보 보류; 원문·전체 비고 보존.', 1086: '현재 native 전체·교수별 전체교육계획과 자체 운영·주차·제한을 읽음. 실제 정규 대면 날짜와 녹화·별도 운영의 배정이 불명확하거나 상충하여 이번 후보 보류; 원문·전체 비고 보존.', 1087: '중국유학생 전용 실제 대면+온라인 강의 병행과 온라인강의 별도선택은 있으나 자체날짜별 배정 미확인. 대상 제한을 보존하여 held유지.', 1088: '중국유학생 전용 실제 대면+온라인 강의 병행과 온라인강의 별도선택은 있으나 자체날짜별 배정 미확인. 대상 제한을 보존하여 held유지.', 1089: '강의 참석 전 자료 시청 권고는 사전학습으로, 전체 토론 강의와 조별 토론 후 전체 발표 실제 운영을 명시. 자체 정규 이론·토론 주차만,8/16시험과휴일은 제외. 영상 시각 생성0.', 1090: '모든 수업 강의실 대면 원칙과 현재 각주 이론·모둠토론·현장활동 중간점검·발표는 명확.10/13 실제 현장수업·9중간고사·16기말고사 제외.8주 자체 정상 정치영역 강의는 학교 시험기간 내 예외 근거로만 예약, 현장활동 주제/중간점검과 실제 교외수업 구분.', 1091: '모든 수업 강의실 대면 원칙과 현재 각주 이론·모둠토론·현장활동 중간점검·발표는 명확.10/13 실제 현장수업·9중간고사·16기말고사 제외.8주 자체 정상 정치영역 강의는 학교 시험기간 내 예외 근거로만 예약, 현장활동 주제/중간점검과 실제 교외수업 구분.', 1092: '명시 대면1–8주와14주 수업 내 GCP발표만.8주 자체 대면수업+중간대체과제 제출은 시험시각 생성 아닌 정상수업 예외.9–13주 대면/GCP현장 혼합 배정과15휴강·16시험은 보류. 공휴일 원격 가능성은 실제 배정으로 간주0.', 1093: '학교 자체 offline대면 원칙 및1–7주 정규이론/14주 GCP수업발표만.8midterm명시와9–13field혼합 및15no class/16final제외. 영어트랙 제한·모든 학교 교육필드 보존.', 1094: '현재 native 전체·교수별 전체교육계획과 자체 운영·주차·제한을 읽음. 실제 정규 대면 날짜와 녹화·별도 운영의 배정이 불명확하거나 상충하여 이번 후보 보류; 원문·전체 비고 보존.', 1095: '현재 native 전체·교수별 전체교육계획과 자체 운영·주차·제한을 읽음. 실제 정규 대면 날짜와 녹화·별도 운영의 배정이 불명확하거나 상충하여 이번 후보 보류; 원문·전체 비고 보존.', 1096: '온오프라인 실천은 시민캠페인/현장운영과 관련이나 현재 강의방식 표의 online강의 선택과 확정 regular lecture 배정 미확인. 실제 방문은별도확정예정. 교수코드전체보존 후 후보 보류.', 1097: '온오프라인 실천은 시민캠페인/현장운영과 관련이나 현재 강의방식 표의 online강의 선택과 확정 regular lecture 배정 미확인. 실제 방문은별도확정예정. 교수코드전체보존 후 후보 보류.', 1098: '필요시 동영상 자료공유/과제는 전체remote운영과구분하되, online강의 별도선택·현장조사 병행의 regular delivery 배정 명시 없음. 미확인으로 보류.', 1099: '필요시 동영상 자료공유/과제는 전체remote운영과구분하되, online강의 별도선택·현장조사 병행의 regular delivery 배정 명시 없음. 미확인으로 보류.', 1100: '현재 native 전체·교수별 전체교육계획과 자체 운영·주차·제한을 읽음. 실제 정규 대면 날짜와 녹화·별도 운영의 배정이 불명확하거나 상충하여 이번 후보 보류; 원문·전체 비고 보존.'}
groupWeeks={1072: {0: [3, 10, 13], 1: [1, 2, 5, 9, 12, 15]}, 1073: {0: [2, 11, 14], 1: [1, 4, 6, 7, 9, 10, 13]}, 1081: {0: [1, 2, 5, 6, 7]}, 1082: {0: [1, 9]}, 1089: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1090: {0: [1, 2, 3, 5, 6, 7, 8, 11, 12, 14, 15]}, 1091: {0: [1, 2, 3, 5, 6, 7, 8, 11, 12, 14, 15]}, 1092: {0: [1, 2, 3, 4, 5, 6, 7, 8, 14]}, 1093: {0: [1, 2, 3, 4, 5, 6, 7, 14]}}
groupPlan={1072: {0: 0, 1: 0}, 1073: {0: 0, 1: 0}, 1081: {0: 0}, 1082: {0: 0}, 1089: {0: 0}, 1090: {0: 0}, 1091: {0: 0}, 1092: {0: 0}, 1093: {0: 0}}
allowedWeekdays={};exceptDates={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
examExceptions={1090: {'2026-10-23'}, 1091: {'2026-10-24'}, 1092: {'2026-10-26'}}
allowedNativeGroups={1072: [0, 1], 1073: [0, 1], 1081: [0], 1082: [0], 1089: [0], 1090: [0], 1091: [0], 1092: [0], 1093: [0]}
calendarPlan={1072: 0, 1073: 0, 1081: 0, 1082: 0, 1089: 0, 1090: 0, 1091: 0, 1092: 0, 1093: 0}
assert len(HH)==9 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-1071];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet037-reviewed30'/f'khu-{campus}-2026-2.packet037-physical-groups-prepared.json'));(P/f'packet038-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside038'}

 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet038-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet038-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2937,'baselineDates':54960,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2937+len(selected),'totalDates':54960+count})
