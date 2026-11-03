# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet046-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={1311: [(3, 990, 1280, '실123호')], 1312: [(2, 990, 1280, '실126호')], 1313: [(5, 540, 705, '공B102호')], 1314: [(5, 810, 975, '공B102호')], 1315: [(2, 900, 975, '공B105호'), (4, 900, 975, '공B105호')], 1317: [(1, 900, 975, '공B101호'), (3, 900, 975, '공B101호')], 1318: [(2, 900, 1155, '품평실C'), (5, 900, 1155, '품평실C')], 1319: [(5, 900, 1065, '공142-1호')], 1320: [(2, 900, 1155, '품평실D'), (5, 900, 1155, '품평실D')], 1321: [(1, 900, 975, '시청각실(강당)'), (3, 900, 975, '시청각실(강당)')], 1322: [(5, 900, 1155, '시청각실(강당)')], 1324: [(5, 900, 1155, '공369호')], 1325: [(5, 900, 1155, '공371호')], 1326: [(2, 900, 1155, '품평실E'), (5, 900, 1155, '품평실E')], 1327: [(1, 630, 705, '공367호'), (3, 630, 705, '공367호')], 1328: [(2, 900, 975, '공148호'), (4, 900, 975, '공148호')], 1331: [(2, 630, 705, '공148호'), (4, 630, 705, '공148호')], 1332: [(2, 720, 795, '공148호'), (4, 720, 795, '공148호')], 1334: [(5, 540, 650, '공263호'), (5, 720, 830, '공263호')], 1335: [(5, 840, 950, '공263호'), (5, 540, 650, '공176호')], 1336: [(2, 810, 885, '공263호'), (4, 810, 885, '공263호')], 1338: [(1, 540, 615, '공B105호'), (3, 540, 615, '공B105호')], 1340: [(2, 540, 615, '공B105호'), (4, 540, 615, '공B105호')]}
weeks={1311: [1, 2, 3, 4, 5, 6, 7, 9, 10, 12, 13], 1312: [1, 2, 3, 4, 5, 6, 7, 9, 10, 12, 13], 1313: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 1314: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1315: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1317: [15], 1318: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 1319: [1, 2, 3, 5, 7, 8, 9, 10, 11, 14], 1320: [3, 4, 8, 10, 12, 13, 14, 15], 1321: [1, 2, 3, 4, 8, 10, 12, 13, 14, 15], 1322: [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14], 1324: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1325: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1326: [3, 4, 8, 10, 12, 13, 14], 1327: [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14], 1328: [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15], 1331: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 15], 1332: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15], 1334: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1335: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 1336: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15], 1338: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1340: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
groupWeeks={1311: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 12, 13]}, 1312: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 12, 13]}, 1313: {0: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]}, 1314: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1315: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1317: {0: [15], 1: [15]}, 1318: {0: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]}, 1319: {0: [1, 2, 3, 5, 7, 8, 9, 10, 11, 14]}, 1320: {0: [3, 4, 8, 10, 12, 13, 14, 15], 1: [3, 4, 8, 10, 12, 13, 14, 15]}, 1321: {0: [1, 2, 3, 4, 8, 10, 12, 13, 14, 15], 1: [1, 2, 3, 4, 8, 10, 12, 13, 14, 15]}, 1322: {0: [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14]}, 1324: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1325: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1326: {0: [3, 4, 8, 10, 12, 13, 14], 1: [3, 4, 8, 10, 12, 13, 14]}, 1327: {0: [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14]}, 1328: {0: [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15]}, 1331: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 15]}, 1332: {0: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15]}, 1334: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1335: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15]}, 1336: {0: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15]}, 1338: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1340: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}}
groupPlan={1311: {0: 0}, 1312: {0: 0}, 1313: {0: 0}, 1314: {0: 0}, 1315: {0: 0, 1: 0}, 1317: {0: 0, 1: 0}, 1318: {0: 0, 1: 0}, 1319: {0: 0}, 1320: {0: 0, 1: 0}, 1321: {0: 0, 1: 0}, 1322: {0: 0}, 1324: {0: 0}, 1325: {0: 0}, 1326: {0: 0, 1: 0}, 1327: {0: 0, 1: 0}, 1328: {0: 0, 1: 0}, 1331: {0: 0, 1: 0}, 1332: {0: 0, 1: 0}, 1334: {0: 0, 1: 0}, 1335: {0: 0, 1: 1}, 1336: {0: 0, 1: 0}, 1338: {0: 0, 1: 0}, 1340: {0: 0, 1: 0}}
examExceptions={1313: ['2026-10-23'], 1318: ['2026-10-20', '2026-10-23'], 1319: ['2026-10-23'], 1320: ['2026-10-20', '2026-10-23'], 1321: ['2026-10-21', '2026-10-26'], 1322: ['2026-10-23'], 1326: ['2026-10-20', '2026-10-23'], 1327: ['2026-10-21', '2026-10-26'], 1328: ['2026-10-20', '2026-10-22'], 1332: ['2026-10-20', '2026-10-22'], 1335: ['2026-10-23'], 1336: ['2026-10-20', '2026-10-22']}
reasons={1311: 'CHE33403 김태경 국제수16:30–21:20실123호 대면이론·실습·설계 명시,1–7/9/10/12/13 정상11dates.8설계점검·11/15평가발표·14시험·16미배정 보류. 교수/분반원문첨부명현재2026수요일 보존,다른분반실험실전파0.', 1312: 'CHE33404 김태경 국제화16:30–21:20실126호 자체대면·ownclock동일교수교육주차대조,1–7/9/10/12/13 정상11dates.8/11/14/15/16평가보류.03실123시간표전파0/첨부화요일명보존.', 1313: 'CHE25303 조숭원 국제금09–11:45공B102 대면원칙·공휴일출장시VOD조건부.1–15정상13dates(8주자체정상thermoOct23예외),16기말보류.박범준분반held조건전파0.', 1314: 'CHE25603 조숭원 국제금13:30–16:15공B102 대면원칙·출장시VOD조건부.1–7/9–15 정상12dates,8/16학교시험기간미게시held;단순교육내용지속행을확정시험기간예외로무분별해석0.', 1315: 'CHE25601 조숭원 국제화목15–16:15공B105 own분반HH·대면기본,1–7/9–15 정상27dates,8/16학교시험held.03과같은교육본문이지만자체codeclock독립.', 1316: 'CHE35601 이범석 현재운영대면및VOD병행vs추가진행실시간대면/VOD시사전공지.교시별실제physical미배정여부추가검토후후보판단pending,임의whole물리선택0.', 1317: 'CHE23403 이범석 실제주차온라인/오프라인혼합은요일별배분불명held.15주과제문제풀이오프라인전체group명시만월수Dec9/14공B10115–16:15부분2dates후보.7/11과제풀이는방식미명시held,시험0VODHH0.', 1318: 'AR51203 문세영 명시대면 화금15–19:15품평실C own설계studio교육,1–15정상30dates(8주기본설계확정Oct20/23실제정상예외),16평가held.개인과제리뷰는정규whole실기방법이고개별미배정운영아님;설계7선수필수보존.', 1319: 'AR47200 이은석 자체프로젝터교수강의·현장10%구분,online선택0.금15–17:45공142-1 1–3/5/7–11/14 정상10dates(8주Wood수업Oct23예외).4연휴독서6실제현장학습12/13/15graded발표16시험보류.교육건축가사례를실제답사로오인0.', 1320: 'AR51204 김도한 국제화금15–19:15품평실D,실습설계품평실명시.3/4/8/10/12–15 actualdesignpractice15날짜 후보(주8Oct20/23normal예외).1/2/5이론발표대면또는Zoom미배정,6주추석상충,7컨설턴트9중간11현장16제출보류.03분반전파0.', 1321: 'AR25300 김관수 국제월수15–16:15시청각실(강당) FaceToFace명시.1–4/8/10/12–15 정규20날짜후보(8주실제분석팀수업Oct21/26예외).5NoClass6발표7field9/11gradedpresentation16시험held.필드사례건축물교육주제≠현장방문운영.', 1322: 'AR11401 민세홍 국제금15–19:15시청각실(강당) online선택0/학교정규실기·이론ownmethods/native wholeclock.1–3/5/7–14 정규12날짜후보(8주도면표현수업Oct23예외).4휴강6actualfield15최종PT16제출평가held.과제크리틱/데스크리뷰정규교육과최종평가분리.', 1323: 'AR50100 김동일 현재교육계획clock·운영·주차본문전체빈값 실제강좌native토요일뿐이라운영미확인held.제목만으로영구배제0.', 1324: 'AR11403 최경철 국제금15–19:15공369 online선택0/자체기술실기80+교수clock일치,1–7/9–14정규11날짜후보;8actual현장15최종PT16FinalPresentationheld,공휴일4/6배치0.01field주차전파0.', 1325: 'AR11404 송민경 국제금15–19:15공371 명시대면 own실기,1–7/9–14정규11dates,8actualfield15최종PT16평가held.03동일주차지만별도교수/clock/room완전보존.', 1326: 'AR51205 오상훈 국제화금15–19:15품평실E actual설계실습품평실,3/4/8/10/12–14 정상13dates(8주actual도면보완Oct20/23예외).1/2/5theory발표대면또는Zoomunknown6추석상충7시청각실컨설턴트9중간11현장15/16최종성과평가held.ownteacher·room독립.', 1327: 'IE21500 진창호 국제월수10:30–11:45공367 대면원칙 own두학과alias/선수/첫수업필수조건보존.1–8/10–14 정상25dates(8주performanceanalyticsOct21/26예외),9중간15/16기말held.', 1328: 'IE30900 반상우 국제화목15–16:15공148명시대면,1–8/10–15 정상27dates(8주사용자조사Oct20/22예외),9중간16기말held.이론인간사용성평가주제가실제시험인것으로배제0.', 1329: 'IE40000 엄주명 실제수업없으며종합설계Pass시자동Pass5개원문영역명시,토18–18:50예약0held;논문제목만추정0.', 1330: 'IE20800 전현우 현packetwholeplan0 priorcurrentOperatingCorrection그대로held,두학과원문alias이수구분보존.', 1331: 'IE32800 최현홍 국제화목10:30–11:45공148 defaultrealtimeoffline반복명시.1–7/9–13/15 정상25dates;14presentation8/16시험held.자료최종판첫주공유및조건부대체운영보존,수강허용추정0.', 1332: 'IE21200 최현홍 국제화목12–13:15공148 defaultrealtimeoffline학교여러영역명시.1–6/8–15 정상27dates(8주databaseactualOct20/22예외);7중간16기말held.온라인교재환경사례≠실제비대면운영.', 1333: 'MSE27300 최석원 대면+일부온라인 actual병행미배정각주physicalwindowunknownheld.공과대전체수강가능/출석80%원문보존,임의온라인요일선택0.', 1334: 'MSE27401 강성준 국제금09–10:50/12–13:50공263호 두독립wholegroup·대면기본 이론/실험.1–7/9–15 정상24meetings(12dates두블록보존);8/16시험held.신소재학과전용원문보존/중간빈시간연결0.', 1335: 'MSE27402 강성준/이홍섭 국제금14–15:50공263(강)/09–10:50공176(이) 서로own교수plan필요.강1–7/9–15정상12,이1–6/8–15정상12(이주8MIMOct23예외),총24meetings같은날교수별group보존.각자다른7/8시험은다른교수에전파0/16시험held.', 1336: 'MSE27200 강성준 국제화목13:30–14:45공263대면기본,1–6/8–15 정상27dates(8주quantumtheoryOct20/22예외),7중간16기말held.', 1337: 'MSE36200 이제욱 현packetwholeplan0 currentOperatingCorrection그대로held.', 1338: 'MSE44200 박윤석 국제월수09–10:15공B105 명시대면 여러영역.1–7/9–15 정상27dates8/16시험held. Biomedical sensing교육주제≠별도임상배정.', 1339: 'MSE25100 박윤석 현packetwholeplan0 currentOperatingCorrection전체보존held.', 1340: 'MSE27500 이빈 국제화목09–10:15공B105 명시대면기본·불가피시촬영영상대체조건부.1–7/9–15 정상27dates8/16시험held.자체촬영2026콘텐츠문구보존/VOD시각0.'}
allowedWeekdays={}
exceptDates={}
holidayExceptions={}
explicitDates={}
roomOverride={}
roomUnconfirmedWeekdays={}
allowedNativeGroups={1311: [0], 1312: [0], 1313: [0], 1314: [0], 1315: [0, 1], 1317: [0, 1], 1318: [0, 1], 1319: [0], 1320: [0, 1], 1321: [0, 1], 1322: [0], 1324: [0], 1325: [0], 1326: [0, 1], 1327: [0, 1], 1328: [0, 1], 1331: [0, 1], 1332: [0, 1], 1334: [0, 1], 1335: [0, 1], 1336: [0, 1], 1338: [0, 1], 1340: [0, 1]}
calendarPlan={1311: 0, 1312: 0, 1313: 0, 1314: 0, 1315: 0, 1317: 0, 1318: 0, 1319: 0, 1320: 0, 1321: 0, 1322: 0, 1324: 0, 1325: 0, 1326: 0, 1327: 0, 1328: 0, 1331: 0, 1332: 0, 1334: 0, 1335: 1, 1336: 0, 1338: 0, 1340: 0}
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-1311];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet045b-one-explicit-live'/f'khu-{campus}-2026-2.one-fixed-live-prepared.json'));(P/f'packet046-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside046'}

 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet046-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet046-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':3052,'baselineDates':56948,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':3052+len(selected),'totalDates':56948+count})
