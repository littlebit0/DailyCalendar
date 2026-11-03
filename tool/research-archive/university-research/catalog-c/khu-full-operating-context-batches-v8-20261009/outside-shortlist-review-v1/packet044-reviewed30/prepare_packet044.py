# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet044-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={1256: [(1, 810, 885, '외304'), (3, 810, 885, '외304')], 1257: [(1, 900, 975, '외307(전산실)'), (3, 900, 975, '외307(전산실)')], 1259: [(1, 630, 705, '외407'), (3, 630, 705, '외407')], 1260: [(1, 720, 795, '외407'), (3, 720, 795, '외407')], 1262: [(1, 630, 705, '외403'), (3, 630, 705, '외403')], 1263: [(2, 630, 705, '외402'), (4, 630, 705, '외402')], 1264: [(2, 810, 885, '외402'), (4, 810, 885, '외402')], 1265: [(5, 540, 705, '외402')], 1266: [(1, 900, 975, '외404'), (3, 900, 975, '외404')], 1268: [(2, 720, 795, '외401'), (4, 720, 795, '외401')], 1272: [(1, 810, 885, '공369호'), (3, 810, 885, '공369호')], 1273: [(2, 810, 885, '공369호'), (4, 810, 885, '공369호')], 1278: [(2, 630, 705, '공149호'), (4, 630, 705, '공149호')], 1279: [(2, 540, 615, '공B103호'), (4, 540, 615, '공B103호')]}
weeks={1256: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1257: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1259: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1260: [1, 2, 3, 4, 5, 6, 7, 9, 10, 12, 13, 14, 15], 1262: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1263: [1, 2, 4, 6, 9, 10, 12, 14], 1264: [1, 2, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1265: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1266: [15], 1268: [2, 3, 4], 1272: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1273: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1278: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1279: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}
reasons={1251: 'CHI32100 박찬욱 국제월수12–13:15외412 전체원문읽음. 노트북지참이론·실습 및online방법별도선택이나 명시physical기본/날짜별live-VOD 배정미확인held. API·개인정보예시·클라우드가학교운영접근근거아님.3학년이상/중국학생금지·기기제한보존.', 1252: 'CHI31000 박찬욱 국제화목13:30–14:45외403 전체원문읽음.텍스트읽기와질문·대답교육내용/online별도방법선택,physical직접배정미확인held. 중국학생귀화자포함수강제한/선이수적합조건보존.', 1253: 'CHI10600 민관동 nativewhole registryplan0. 기존currentOperatingCorrection전체객체불변held. 중국학생금지/1학년전용보존,새대면근거없음.', 1254: 'CHI21200 노상균 nativewhole registryplan0. 기존currentOperatingCorrection전체객체불변held. 외321공자아카데미괄호원문/2학년우선·유학생금지보존.', 1255: 'CHI40100 노상균 nativewhole registryplan0. 기존currentOperatingCorrection전체객체불변held. 과거학기시험예외원문보존,제자백가주제로physical추정0.', 1256: 'RU330300 최행규 국제월수13:30–14:45외304 대면기본/휴일녹화명시.1–7/9–15정규27날짜후보.2유튜브가족인터뷰교육자료는VOD강의아님;시사실시간이슈라는주제는live강의증명아님.8/16시험held,개별과제번역·발표조건보존.', 1257: 'RU130200 최행규 국제월수15–16:15외307(전산실). 강의실대면원칙및휴일녹화명시.1–7/9–15정규27날짜후보.팀발표교재활용·종교문화·러시아문화주제는별도현장운영아님.8/16시험held,source괄호room그대로보존.', 1258: 'RU440000 안지영 졸업논문0학점/HH없음·전체교육빈계획직접확인held. 기본교육빈값과native실제개설정보분리,타논문시각차용0.', 1259: 'RU110401 안지영 국제월수10:30–11:45외407 공휴일휴보강외전면대면명시.1–7/9–15 일반27날짜후보.01분반홀수학번/1학년제한보존,8/16시험held. 학습문법격변화는운영기간아님.', 1260: 'RU320300 안지영 국제월수12–13:15외407 공휴일보강외전면대면명시.1–7/9–10 두group정규17일+자체11/18·11/25·12/2·12/9 수요일교수수업4일 총21후보.11/11·16 및11/23·30·12/7피어평가발표,12/14기말은별도held. 날짜본문과요일정확일치,역사·체르노빌제목은field아님. 발표/비대면상충없는그룹만분리.', 1261: 'ESP43700 황수현0학점졸업논문 필수등록하지만수업없음명시. 날짜HH없음held. 졸업학기필수신청/이수요건과수업예약구분원문보존.', 1262: 'ESP35200 황수현 국제월수10:30–11:45외403 대면원칙명시.1–7/9–15 일반27날짜후보. 문학자료카페온라인/감염시대체가능조건과actual원격배정구분.8/16시험held. 무단녹취금지·사전출력자료지참/모든원문보존.', 1263: 'ESP32600 김찬기 국제화목10:30–11:45외402 대면기본/특별상황Zoom또는VOD조건부.1·2·4·6·9·10·12·14 영화자료감상/주제강의15날짜후보.3·5·7·11·13·15발표평가및8·16시험held. 영화재생분량으로lecture HH변경0. 현장교육활용은교육목표이지actualfield.', 1264: 'ESP10200 김찬기 국제화목13:30–14:45외402 대면기본명시.1·2·4–7·9–15 일반25날짜후보예정.3주추석9/21원문과currentcalendar상충표기를정정/선택하지않고해당주held;8·16시험held. 조건부Zoom링크는실제live배정증거아님. 재수강다른교수권고/선이수대상보존.', 1265: 'ESP34500 김선욱 국제금09–11:45외402대면강의명시.1–7/9–15 일반12날짜후보(9/25·10/9제외).스페인현장학습기회있으면실시라는미래조건은현재확정field아님.8중간/16기말held.기사2024년은교육자료연도이지강좌개설연도아님.', 1266: 'ESP20400 정원석 국제월수15–16:15외404대면원칙이나1–14주본문MMDD가현재week/native요일과상충(9/1·9/6·9/8등). 해당상충그룹held,날짜정정·맞는날짜선택0.15주총복습자체기간12/8–14와ownnative만상충없어12/9·14두날짜좁은후보.8/16시험held. 선행학습·문법시제주제를운영시각으로오해0.', 1267: 'ELC40000 이명호0학점논문교육전체빈plan/HH없음확인held. 영미문화학부whole존재와빈plan내용구분,개인논문일시생성0.', 1268: 'ELC41100 이명호 국제화목12–13:15외401. 자체초반대면주제발굴/팀구성명시+2/3/4주개별날짜9/8·10·15·17·22 일치5일후보.1주9/2본문과native화목상충held.5–9개인과제/10–12온라인진행·중간발표/13–16평가발표·구체방식학생대화확정조건은원문보존held. 전체mixed를일괄대면전파0.', 1269: 'ENV49400 오종민 월10–12:45공352호 매주연구미팅원문있으나online방법별도선택/개별현장견학병행으로exactphysical·live배정미확인held. 본교정규HH를각개별field에전파0,사전신청서제출자제한보존.', 1270: 'ENV49401 오종민 월13–15:45공352호00과서로다른owncode-clock확인.온라인선택/수계현장학습개별병행으로현재physical직접배정미확인held. 주제모니터링은확정field시각아님,00분반HH차용0/사전서류제한보존.', 1271: 'ENV38602 유창규 국제수16:30–21:20공102-1호native/기본clock. 학교비고실험강의실공340호 및주차실험원문존재/공102-1이론과실험340의실제시각배분미확인held. 두장소를임의선택·다른요일차용0. 실험안전이수증·대면또는online보고서제출은lecture방식과구분,주8정상실험/14시험원문보존.', 1272: 'ENV33900 민부기 국제월수13:30–14:45공369호대면원칙.1–7/9–15 일반27날짜후보. 폐수처리장설계·습지교육주제≠actualfield.8혼합중간시험/16기말held. 부분영어강좌/장애지원/과제원문보존.', 1273: 'ENV27900 민부기 국제화목13:30–14:45공369호대면원칙.1–7/9–15 일반27날짜후보. 화학상분리·수증기압주제는actualremote/field아님.8혼합중간시험16기말held. 필요시VOD조건부를실제지정강의로생성0.', 1274: 'ENV48700 윤정호 토16:30–17:20native지만연구실별현장조사/실험/분석·논문조지도개별운영전체. 전체토요일50분고정출석매핑미확인held. 방빈값자체이유아님;졸업필수/발표요건보존.', 1275: 'AE35401 홍원기 화목13:30–14:45 자체날짜9월–10월이론후팀프로젝트/중간기말없음. Youtube평가완료후게시교육영상은actualVOD아님. 그러나online방법별도선택/확정physical직접배정미확인·교실multiple배분미확인held. 15명이상분반조정예정/학교전체조건보존.', 1276: 'AE35402 홍원기 화목15–16:15 자체02분반clock확인. 01동일교육전체실제동일필드확인하지만자체분반HH다름보존. physical배정미확인/일별복수교실배분미확인held,다른분반HH와room차용0.', 1277: 'AE27201 김곤 월16:30–19:15공149호 대면운영vs유형혼합직접표기/추가설명2025년가을과current2026-2 header상충. 날짜별실제physical배정확정미확인held. 음향field는교육분야이지현장출장,다른AE373방식차용0.', 1278: 'AE37300 김곤 화목10:30–11:45공149호 현재대면명시·보완영상은교실학습자료.1–7/9–14 일반25날짜후보.8혼합시험/15현장조사과제발표·16졸업시험held. 공휴일외대면직접명시,급배수·전기공학주제는actualfield아님.', 1279: 'AE23100 이준복 화목09–10:15공B103호 자체primarily in person 명시.1–7/9–14 일반25날짜후보.8중간/15·16기말held. 건설계약및CPMproject scheduling교육주제≠실제운영기간. 영어교재한국어강의·출석70%/기기사용시험제한원문보존.', 1280: 'AE43300 임지영 목16:30–19:15공B103호 전체원문읽음. 대면및비대면혼합실제명시하지만날짜별live/VOD/physical 미배정held. 건설현장사례/차량하중/물류센터·BIM는교육주제이지학생actual현장배정이아님.8·16시험/15평가발표별도보존.'}
groupWeeks={1256: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1257: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1259: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1260: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 12, 13, 14, 15]}, 1262: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1263: {0: [1, 2, 4, 6, 9, 10, 12, 14], 1: [1, 2, 4, 6, 9, 10, 12, 14]}, 1264: {0: [1, 2, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1265: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1266: {0: [15], 1: [15]}, 1268: {0: [2, 3, 4], 1: [2, 3, 4]}, 1272: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1273: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1278: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1279: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}}
groupPlan={1256: {0: 0, 1: 0}, 1257: {0: 0, 1: 0}, 1259: {0: 0, 1: 0}, 1260: {0: 0, 1: 0}, 1262: {0: 0, 1: 0}, 1263: {0: 0, 1: 0}, 1264: {0: 0, 1: 0}, 1265: {0: 0}, 1266: {0: 0, 1: 0}, 1268: {0: 0, 1: 0}, 1272: {0: 0, 1: 0}, 1273: {0: 0, 1: 0}, 1278: {0: 0, 1: 0}, 1279: {0: 0, 1: 0}}
allowedWeekdays={};exceptDates={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
examExceptions={}
allowedNativeGroups={1256: [0, 1], 1257: [0, 1], 1259: [0, 1], 1260: [0, 1], 1262: [0, 1], 1263: [0, 1], 1264: [0, 1], 1265: [0], 1266: [0, 1], 1268: [0, 1], 1272: [0, 1], 1273: [0, 1], 1278: [0, 1], 1279: [0, 1]}
calendarPlan={1256: 0, 1257: 0, 1259: 0, 1260: 0, 1262: 0, 1263: 0, 1264: 0, 1265: 0, 1266: 0, 1268: 0, 1272: 0, 1273: 0, 1278: 0, 1279: 0}
assert len(HH)==14 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-1251];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet043-reviewed30'/f'khu-{campus}-2026-2.packet043-physical-groups-prepared.json'));(P/f'packet044-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside044'}

 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet044-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet044-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':3020,'baselineDates':56271,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':3020+len(selected),'totalDates':56271+count})
