# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet033-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={923: [(2, 540, 650, '스222(계단)'), (3, 660, 770, '스B129(계단)')], 924: [(2, 660, 770, '스220(계단)'), (3, 540, 650, '스124')], 928: [(1, 570, 740, '스124')], 930: [(3, 540, 650, '스220(계단)')], 931: [(3, 660, 770, '스220(계단)')], 932: [(3, 540, 650, '스B129(계단)')], 933: [(3, 660, 770, '스124')], 937: [(1, 780, 950, '스222(계단)')], 938: [(2, 540, 710, '스B126')], 941: [(2, 650, 755, '계단강의실(B128호)')], 942: [(2, 1030, 1135, '계단강의실(B128호)')], 943: [(3, 540, 645, '계단강의실(B128호)')], 945: [(3, 1140, 1245, '계단강의실(B128호)')], 946: [(4, 1080, 1245, '미209')], 947: [(1, 960, 1125, '미504')], 949: [(3, 660, 825, '미209')]}
weeks={923: [5, 6, 7, 13, 14, 15], 924: [5, 6, 7, 13, 14, 15], 928: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15], 930: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 931: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 932: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 933: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 937: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 938: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 941: [1, 2, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 942: [1, 2, 4, 5, 9, 10, 11, 13, 14], 943: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 945: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 946: [1, 2, 3, 4, 5, 7, 9, 10, 11, 12, 13, 14, 15], 947: [1, 2, 3, 4, 5, 6, 7], 949: [1, 2, 3, 4, 5, 7, 9, 10, 11, 12, 13, 14, 15]}
reasons={921: '병원임상 developmental 개인차수 및 현장기간 미공표; native Mon/Thu 전체16주추정0.', 922: '두 교수 자체 임상2주·차수별OT운영, 실제개인기간 미공표.', 923: '두 자체교수계획 공통 이론5–7/13–15주만, 임상1–4/9–12·자습시험8/16주held. 과거요일과제마감은 출석기간으로변환0.', 924: '현02 자체HH/두교수이론블록5–7/13–15주만, 다른분반시각차용0. 임상/자습/시험 보존held.', 925: '졸업시험·자격성취도 평가, HH미공표.', 926: '병원ICU/CPX실습 및감염조건원격, 개별차수실습일 미공표.', 927: '1일9시간병원실습·차수별유인물별도, 실제개인날짜미공표.', 928: '대면강의·실습 실제원문,1–7/10–15정규만.9주현장체험HH연결미확인held;개별최소2주과제는수업기간아님.', 929: '병동관리현장 배정·개별실습시기 미공표,4교수전체보존.', 930: '명시대면기본,필요시비대면가능 조건은현재실시간/VOD배정아님.15주실제자율학습 제외1–7/9–14.', 931: '현00 자체Wed11–12:50 대면기본·조건부비대면,15자율학습held.', 932: '현재김보현계획 명시대면1–7/9–14주;곽정민교육공란은반대운영아님.15주과제제출-only 실제대면미확인held.', 933: '현02 자체HH와김보현대면1–7/9–15실제명시. 다른분반15주문구차용0.', 934: '여성임상1주·교내시뮬레이션혼합 및1주전배정,실제개인날짜미공표.', 935: '실제병원DAY07–16/08–17·EVE13–22·교내09–18 vsnative09–19 충돌 및개인배정미공표;07–06오타선택교정0. hybrid simulation은마네킹+표준화환자임.', 936: '호스피스 원문교육운영·주차·자체HH 대부분공란, native만으로 모드미확인.', 937: '대면기본과필요시온라인 조건,현재실제원격배정아님.정규1–7/9–15주,공휴일/시험보류.', 938: '현02자체화09–11:50 명시대면기본조건원격·정규1–7/9–15주.', 939: '아동각론이론문구만 실제대면/live확정아님;nativeThu추가group ownbasicclock미표시.', 940: '현01 ownTue만basicHH,Thu추가group미확인;이론교육주제만대면확정0.', 941: '두교수현재자체대면명시·같은화10:50–12:35.별도온라인열로만과거철회했던원문재검토,담당교수상이휴일3/4주양쪽제외·시험8/16제외.과제12/13금요일표기는출석기준아님.', 942: '자체정혜진대면/이지아운영공란,두원문모드배정충돌온라인3/7/12/15·6주휴일양쪽제외.공통정규1/2/4/5/9/10/11/13/14만.과제제출기한으로시각생성0.', 943: '자체명시대면정규1–7/9–15. E-campus는자료·제출,상담교육주제는외부현장날짜아님.', 944: '졸업논문대면평가지만시작/끝HH미공표.', 945: '대면기본및불가시에만원격가능조건.정규1–7/9–14만,15주공란·8/16시험보류.시청각은보조자료.', 946: '명시대면미술실기/발표 정규1–5/7/9–15.6주원문휴강을현재목요일공휴일로수정0,4주공휴일제외.영상제작은수업주제.', 947: '모든수업대면명시나9–15주전시관람배정과실제장소/기간불명,일단1–7교내정규만;레포트8/16일정생성0.', 948: '대면실습기본+영상사전학습이지만수업진행비대면운영·개별면담도공존,실제주차별전체group대면/원격배정미확인held.영상시각생성0.', 949: '대면기본/부득이할때원격 조건.정규1–5/7/9–15,6readingweek/8개별면담/16기록보류.견학/현장가능설명은현재주차배정으로만들지않음.', 950: '졸업작품검증HH08–08:05 native vswhole교육HH/운영공란,실제주간수업인지미확인held.'}
allowedWeekdays={};exceptDates={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={};examExceptions={};allowedNativeGroups={};calendarPlan={932:1,933:1};groupWeeks={}
assert len(HH)==16 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-921];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 proof.append({'packetOrdinal':n,'sourceId':c['sourceId'],'wholePlans':plans,'nativeClock':c['sourceSchedule'],'ownCampus':plans[0]['campus'],'literalNativeHH':HH[n],'allowedPhysicalWeeksLiteral':ws,'physicalRowsLiteral':[r for a,b,r in spans],'semanticReason':reasons[n],'explicitUnscheduledDatesLiteral':sorted(exceptDates.get(n,set())),'independentDates':sorted({k[0] for k in independent}),'literalIndependentMeetings':[list(k) for k in sorted(independent)],'ownExamNormalExceptionsLiteral':sorted(examExceptions.get(n,set())),'ownHolidayNormalExceptionsLiteral':sorted(holidayExceptions.get(n,set())),'ownExplicitDatesLiteral':sorted(explicitDates.get(n,set())),'ownRoomOverridesLiteral':roomOverride.get(n,{}),'roomUnconfirmedWeekdaysLiteral':sorted(roomUnconfirmedWeekdays.get(n,set())),'allowedWeekdaysLiteral':sorted(allowedWeekdays.get(n,set())),'allowedNativeGroupsLiteral':sorted(allowedNativeGroups.get(n,set(range(len(native))))),'ownGroupWeeksLiteral':groupWeeks.get(n,{}),'calendarPlanIndex':calendarPlan.get(n,0),'newDateCount':len(meetings),'previousResearchDepartmentRemarks':c['departmentRemarks'],'remoteHoursGenerated':0})
for campus in ['seoul','global']:
 old=json.load(open(P.parent/'packet032-reviewed30'/f'khu-{campus}-2026-2.packet032-physical-groups-prepared.json'));(P/f'packet033-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside033'}

  if c['sourceId'].endswith('/NURS403701'):c['currentOperatingCorrection']={'reason':'Current own two professor full plans explicitly state physical instruction; common confirmed normal groups only; previous separately selected online-column blanket hold reviewed', 'sourcePlan':'work/university-research/catalog-u/public-plans-v2/1c69ed72667a2b8aee98.json','actualAttendanceConfirmed':False,'priorWholeObjectArchive':'packet033-prior-seoul-whole.json','previousSchoolOriginalsUnchanged':True}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet033-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet033-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2855,'baselineDates':53574,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2855+len(selected),'totalDates':53574+count})
