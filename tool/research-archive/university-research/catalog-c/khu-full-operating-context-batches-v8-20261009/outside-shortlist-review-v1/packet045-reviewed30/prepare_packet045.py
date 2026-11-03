# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet045-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={1281: [(2, 810, 885, '공176호'), (4, 810, 885, '공176호')], 1282: [(2, 900, 975, '공B104호'), (4, 900, 975, '공B104호')], 1285: [(5, 810, 975, '공176-3호')], 1286: [(2, 630, 740, '공B101호'), (4, 630, 740, '공B101호')], 1287: [(2, 780, 890, '공B101호'), (4, 780, 890, '공B101호')], 1293: [(1, 900, 1010, '공244호실'), (3, 900, 1010, '공244호실')], 1294: [(2, 540, 615, '공B101호'), (4, 540, 615, '공B101호')], 1295: [(5, 900, 1065, '공150호')], 1296: [(1, 780, 890, '공150호'), (3, 780, 890, '공127호')], 1297: [(2, 900, 975, '공365호'), (4, 900, 975, '공365호')], 1298: [(5, 540, 705, '공150호')], 1301: [(1, 630, 705, '공363호'), (3, 630, 705, '공363호')], 1302: [(1, 990, 1280, '실124호')], 1305: [(1, 630, 705, '공102-1호'), (3, 630, 705, '공102-1호')], 1307: [(2, 990, 1280, '실124호')], 1308: [(1, 810, 885, '공363호'), (3, 810, 885, '공363호')], 1309: [(1, 900, 975, '공B102호'), (3, 900, 975, '공B102호')], 1310: [(1, 900, 975, '공363호'), (3, 900, 975, '공363호')]}
weeks={1281: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1282: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1285: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1286: [1, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1287: [1, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1293: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14], 1294: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1295: [1, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15], 1296: [1, 2, 3, 4, 5, 7, 8, 9, 10, 12, 13, 15], 1297: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1298: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1301: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1302: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], 1305: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1307: [1, 2, 3, 4, 5, 9, 10, 12, 13], 1308: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13], 1309: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13], 1310: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
reasons={1281: 'AE11200 김대진 국제화목13:30–14:45공176호대면원칙.1–7/9–15 정상27날짜후보.8중간/16기말held. 타과전공불인정/전체강의2/3시험자격제한보존,정역학힘평형주제는운영기간아님.', 1282: 'AE25200 김대진 국제화목15–16:15공B104호대면원칙 자체별도code-clock확인.1–7/9–15정상27날짜후보.8중간16기말held;재료역학1·기초물리선수와전체출석조건보존. 필요시VOD조건부현재배정0.', 1283: 'AE27202 박상현 국제월10:30–13:15공149호. 운영대면중심vs2026가을대면+Zoom/VOD혼합미확정실제추가설명·날짜별방식없음held.01김곤과원문일부같아도교수/분반/clock다름보존;음향field는교육주제,혼합문구삭제0.', 1284: 'AE10100 연문숙 비대면이론영상+실습 실제혼합의 날짜별 배정미확인 held. 교육코딩주제나 e-campus만이 사유 아님, 학과수강제한 보존.', 1285: 'AE35300 박진호 국제금13:30–16:15공176-3호 대면원칙 1–7/9–15 정상12날짜 후보(공휴일4/6제외).8/16시험held. 자체Oct9온라인·주6휴일온라인·Zoom3영역명시1회는별도futurelive후보,045정상에서는미배치.', 1286: 'CE25201 정영훈/남부현 국제화목10:30–12:20공B101호 자체두교수계획sameHH·대면원칙.1/3–7/9–15 정상25후보;주2labtour배정미확인,8/16시험보류. 주9Site investigation는교육주제일뿐별도실제현장배정명시0. 실험교실다른원문0,자체knownblock보존.', 1287: 'CE25202 남부현/정영훈 두교수계획own화목13–14:50공B101호 대응.01clock전파0,각own필드보존.1/3–7/9–15 정상25후보;주2tour8/16exam보류.', 1288: 'CE21000 오승대 현재묶음wholeplan0 priorcurrentOperatingCorrection온라인미배정 그대로held. routingcontext만wholeplan으로세지않음.', 1289: 'CE27400 오승대 현재온라인별도선택+실제운영첫주확정·견학예정/원문room공150(공147) 배정미확인held. 환경이론주제를현장수업으로오인0.', 1290: "CE30340 오승대 원문'강의시간은토요일이아니며' 지도교수개별연수시간/장소협의, native토clock전체held. 이전연구타년도예시는current운영아님.", 1291: "CE40000 오승대 원문'강의일시는토요일이아니며' 졸업논문개별팀연구, native토요일미배치held.", 1292: 'CE48603 오승대 개인팀자료수집·QUESTactual운영첫주협의+roomB101/176-4배정미확인,wholecurrent정규physicalclock지정부족held.', 1293: 'CE38700 김석현 국제월수15–16:50공244호실 대면원칙·컴퓨터활용실습 자체원문.1–6/8–14 정상25날짜;7/15혼합exam과16시험held.8주수학2/3명시정상으로Oct21/26자체시험기간예외,평가퀴즈는전체강의대체아님.', 1294: 'CE38100 남부현 국제화목09–10:15공B101호 대면원칙.1–7/9–14 정상25날짜;8/15reviewexam16examreview보류. subsurfaceexploration/labtesting은강의주제,별도실제현장아님.', 1295: 'CE13200 최혁진 국제금15–17:45공150호 대면원칙/학교승인시원격조건부.1/3–8/10–15 정상11날짜;2주실제현장견학9중간16기말보류.8주스마트건설정상명시Oct23예외,공휴일6/4미배치.', 1296: 'CE38201 황의승 국제월13–14:50공150/수13–14:50공127. 이론·전산실습모두offline명시,공휴일보강VOD미예약.1–5/7–10/12/13/15 정상23날짜;6/11중간및14전산평가wholegroups미배정held.8주정규theory/lab명시Oct21/26예외.모든선수/타과제한보존.', 1297: 'CE35300 조병휘 국제화목15–16:15공365호 명시대면 1–7/9–14 정상25날짜.15보강주실제날짜HH미확인/8·16시험held. 시공현장문제는교육주제.', 1298: 'CE20100 이광우 국제금09–11:45공150호 physical원칙 조건부원격.1–7/9–14 정상11날짜;8/15/16시험보류.타과불인정원문보존.', 1299: 'CHE35800 이창우 현packetwholeplan0 currentOperatingCorrection전체held불변.', 1300: 'CHE37200 이창우 현packetwholeplan0 currentOperatingCorrection전체held불변.', 1301: 'CHE25602 유태경 국제월수10:30–11:45공363호 대면원칙/온라인일부조건부.1–7/9–15 정상27날짜;8/16학교시험기간held,시험개별미게시추정0.', 1302: 'CHE33405 유태경 국제월16:30–21:20실124호 명시대면/실험 원문단일교실·clock.1–13 정상12날짜(주8PlasmidtheoryOct26예외,Oct5휴일제외);14/15평가설계발표16기말held.과제2020조건부옛문구보존하고2026개별계획주차만근거.', 1303: 'CHE25302 박범준 필요시비대면병행+온라인별도선택,명시physical기본부족미배정held.', 1304: 'CHE25301 박범준 실제동일교육계획이나own12–13:15clock 다른분반;physical배정미확인held.02clock전파0.', 1305: 'CHE13301 서태석 국제월수10:30–11:45공102-1호 대면원칙/출장시VOD조건부.1–7/9–15 정상27날짜;8/16시험held.화공/자유전공만수강제한보존.', 1306: 'CHE37600 강남규 현packetwholeplan0 currentOperatingCorrection전체held불변.', 1307: 'CHE33402 배재형 국제화16:30–21:20실124호 명시대면 own본문날짜current화요일일치.1–5/9/10/12/13 정상9날짜.6/7실험연구동B114명시vsnative124는독립실별후속검토,8/11/15평가설계14기말16미배정held.학교휴일기간이아닌자체날짜보존.', 1308: 'CHE23401 김우식 국제월수13:30–14:45공363호 대면원칙.1–6/8–13 정상23날짜;7실제TBA/10월24시험과주차상충,14TBA시청각15기말16평가held.8주관내흐름정상명시Oct21/26예외. 단일퀴즈전체강의대체0.', 1309: 'CHE23402 김우식 국제월수15–16:15공B102호 own분반시각.01교육본문정확같음독립sectionproof 유지,1–6/8–13 정상23날짜.7/14/15/16보류/VOD시각0.', 1310: 'CHE36400 하민영 국제월수15–16:15공363호 대면이론/전산예제,1–7/9–15 정상27날짜.8중간16기말held.공정운전교육주제가별도현장운영아님.'}
groupWeeks={1281: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1282: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1285: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1286: {0: [1, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1287: {0: [1, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1293: {0: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14]}, 1294: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1295: {0: [1, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15]}, 1296: {0: [1, 2, 3, 4, 5, 7, 8, 9, 10, 12, 13, 15], 1: [1, 2, 3, 4, 5, 7, 8, 9, 10, 12, 13, 15]}, 1297: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1298: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1301: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1302: {0: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]}, 1305: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1307: {0: [1, 2, 3, 4, 5, 9, 10, 12, 13]}, 1308: {0: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13], 1: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13]}, 1309: {0: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13], 1: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13]}, 1310: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}}
groupPlan={1281: {0: 0, 1: 0}, 1282: {0: 0, 1: 0}, 1285: {0: 0}, 1286: {0: 0, 1: 0}, 1287: {0: 0, 1: 0}, 1293: {0: 0, 1: 0}, 1294: {0: 0, 1: 0}, 1295: {0: 0}, 1296: {0: 0, 1: 0}, 1297: {0: 0, 1: 0}, 1298: {0: 0}, 1301: {0: 0, 1: 0}, 1302: {0: 0}, 1305: {0: 0, 1: 0}, 1307: {0: 0}, 1308: {0: 0, 1: 0}, 1309: {0: 0, 1: 0}, 1310: {0: 0, 1: 0}}
allowedWeekdays={};exceptDates={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
examExceptions={1293: ['2026-10-21', '2026-10-26'], 1295: ['2026-10-23'], 1296: ['2026-10-21', '2026-10-26'], 1302: ['2026-10-26'], 1308: ['2026-10-21', '2026-10-26'], 1309: ['2026-10-21', '2026-10-26']}
allowedNativeGroups={1281: [0, 1], 1282: [0, 1], 1285: [0], 1286: [0, 1], 1287: [0, 1], 1293: [0, 1], 1294: [0, 1], 1295: [0], 1296: [0, 1], 1297: [0, 1], 1298: [0], 1301: [0, 1], 1302: [0], 1305: [0, 1], 1307: [0], 1308: [0, 1], 1309: [0, 1], 1310: [0, 1]}
calendarPlan={1281: 0, 1282: 0, 1285: 0, 1286: 0, 1287: 0, 1293: 0, 1294: 0, 1295: 0, 1296: 0, 1297: 0, 1298: 0, 1301: 0, 1302: 0, 1305: 0, 1307: 0, 1308: 0, 1309: 0, 1310: 0}
assert len(HH)==18 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-1281];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet044-reviewed30'/f'khu-{campus}-2026-2.packet044-physical-groups-prepared.json'));(P/f'packet045-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside045'}

 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet045-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet045-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':3034,'baselineDates':56563,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':3034+len(selected),'totalDates':56563+count})
