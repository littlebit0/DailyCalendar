# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet040-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={1131: [(2, 630, 705, '청409'), (4, 630, 705, '청409')], 1132: [(5, 720, 885, '청207')], 1133: [(2, 810, 885, '청307'), (4, 810, 885, '청307')], 1135: [(2, 630, 705, '청407'), (4, 630, 705, '청407')], 1136: [(2, 810, 885, '네105'), (4, 810, 885, '네105')], 1137: [(1, 630, 705, '청308'), (3, 630, 705, '청308')], 1138: [(2, 900, 1065, '청307')], 1139: [(2, 900, 975, '청308'), (4, 900, 975, '청308')], 1141: [(2, 630, 705, '청201'), (4, 630, 705, '청201')], 1142: [(2, 810, 885, '청201'), (4, 810, 885, '청201')], 1144: [(1, 540, 615, '청715'), (3, 540, 615, '청715')], 1147: [(2, 720, 795, '청307'), (4, 720, 795, '청307')], 1148: [(2, 810, 885, '청407'), (4, 810, 885, '청407')], 1149: [(1, 810, 885, '청201'), (3, 810, 885, '청201')], 1150: [(1, 540, 615, '청308'), (3, 540, 615, '청308')], 1151: [(2, 810, 885, '청409'), (4, 810, 885, '청409')], 1152: [(3, 900, 1065, '청308')], 1157: [(1, 540, 705, '네B201/B202')], 1158: [(1, 780, 945, '네B201/B202')]}
weeks={1131: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1132: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1133: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1135: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1136: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1137: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1138: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15], 1139: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1141: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14], 1142: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15], 1144: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1147: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1148: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1149: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1150: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1151: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1152: [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14], 1157: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1158: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
reasons={1131: 'GED1314S00 이성천 화목10:30–11:45청409: 자체대면원칙, 온라인은공휴일/부득이조건부;1–7/9–14정규25날짜,8시험15보강16시험보류. 과제자료eCampus제출≠remote. 모든교육섹션실제읽음.', 1132: 'GED1337S00 신은희 금12–14:45청207:매주대면/각주대면 명시;1–7/9–14 정상13주휴일2제외11날짜.8온라인강의(중간시험없음이라도remote),15기말12/11held,16공란.템플스테이는독립1박2일과제/보고서활동이며정규대면수업을전체현장으로오해0.원문F학점조건/보고서마감 모두보존.', 1133: 'GED1648S00 이병태 화목13:30–14:45청307:대면원칙, 공휴일만원격/중간정규lecture조건미확정→8held;1–7/9–15 정상27날짜.모든원문교육섹션읽음.주제이데올로기/사회주의운동≠actualfield.', 1134: 'GED1869S00 엄혜진 native고정HH없고녹화온라인.원문전체읽음.3차례추가liveQ&A(주표는4차례)start12뿐end미공표/nonattendance;9/3OTstart18도end없음.시험은start18뿐전체end없고정규VOD에전파0.모든원문불일치/날짜/제한보존held0new.', 1135: 'GED1649S00 조은아 화목10:30–11:45청407대면기본 필요시비실시간조건부.1–7/9–15정규이론27날짜,8/16시험제외.별도클래식공연2회일정미확정=공연예약0,주별정규이론과공연장출석분리.영상은음악교재자료.', 1136: 'GED1349S00 WayneGauthier 화목13:30–14:45네105 자체face-to-face+holidayrecording만.1–7/9–14정규25날짜,8시험15/16finalprojectpresentations평가배정보류.영어트랙우선등록/정정기간전체오픈 학교문구보존,개인수강가능추정0.', 1137: 'GED1824S00 이명원 월수10:30–11:45청308:명시대면/휴업일비동기;1–7/9–14정규25날짜.8중간/과제대체,15기말,16종강보류.과제발표/토론은실제교실,작품주제≠field.', 1138: 'GED11095S00 임혜숙 화15–17:45청307:매시간대면강의·수업내팀토론명시;1–7/9–12/14–15정규13날짜.13현장예술학습과8/16시험held.시청각작품은매시간교재자료,비실시간과제제출은출석수업과분리.', 1139: 'GED1802S00 김웅기 화목15–16:15청308:대면원칙/모든정규각주이론+팀활동명시1–7/9–15정규27날짜.8/16시험,9/24휴일제외.일반공결원문비동기조건은현재정규수업delivery배정증거아님.문학주제혁명/포로생활≠actualfield.', 1140: 'GED1452S00 박승준native월수금HH없음/VOD전용:whole교육원문읽음.영상개수42+6=48vs기타43/29 실제충돌보존.현재시험10/20·12/15화18:30–19:10구체HH있지만정규VOD시간으로전파0,이번ordinary후보0.', 1141: 'GED1508S00 김희찬 화목10:30–11:45청201:강의/발표/토론+실제museum9주별도,영상매체는문화학습자료.1–7/10–14정규23날짜,8시험9실제현장15보강16시험보류.토픽인류확산/국가사회≠actualfield.', 1142: 'GED1609S00 김희찬 화목13:30–14:45청201:동일자기운영/자체각주1–7/10–15강의25날짜,8시험9박물관현장16시험제외.10–15지리/건축/문화유산교육주제를실제출장탐방으로추정0.', 1143: 'GED1435S00 정복철:외국인전용native토일HH없음,비실시간e-campus녹화.중간/기말대면시험도시각미공표.학교비고/배점설명상충30/20·10/20있어모두그대로보존.정규HH생성0held.', 1144: 'GED1665S00 신진숙 월수09–10:15청715:전체대면운영,휴강시예외contentonly;1–7/9–14정규25날짜.영화/온라인도시과제사진은교육자료/독립과제≠전체remote/field.8시험15보강16시험held.', 1145: '이미 별도039b에서 정종필 자체9/1·10/13·12/1 실시간3회를 준비한 whole object를 그대로 보존. 이 packet에서 새0, native 고정HH 생성0; 기존live3을 철회하거나 중복생성하지 않음.', 1146: 'GED1631S00 홍승태 화목10:30–11:45청307:중국전용/중국어시험자료및대면강의+online e-campus함께활용.자료실과원격배정구분하되online강의별도선택/주차별physical직접배정없음좁은후보held.학교역사주제전쟁/운동≠현장과목.', 1147: 'GED1503S00 이병태 화목12–13:15청307:자체대면원칙/공휴일조건부녹화.1–7/9–15정규27일,8중간미실시조건강의는운영미확정held,16시험held.교육주제자유/공동체실천≠현장배정.', 1148: 'GED1526S00 조은아 화목13:30–14:45청407:자체대면기본,조건부필요온라인;1–7/9–15정규27일8/16시험held.별도2공연공지미정은 공연시간을생성하지않고주차표정규이론과분리,영화/음악/축제주제≠실제현장수업.', 1149: 'GED1616S00 최서희 월수13:30–14:45청201 명시in-person/in-class.1–7/9–15 정상27일 중9/21 자체휴강 제외26일.교수의대학원출장 기간9/17–22를학부전체휴강으로전파0.9/11·9/12 optional보강/탐방은정규native요일아님,9/12end없음으로생성0.8시험·16평가 제외15정상토론.영어트랙우선원문보존.', 1150: 'GED11053S00 조복현 월수09–10:15청308 각주대면/전체대면강의명시;1–7/9–15정규27일.조건부가능궁궐탐방은현재배정없어별도생성0.8/16시험held.외국인전용/구GEE1273중복제한보존.', 1151: 'GED1998S00 조복현 화목13:30–14:45청409 전체대면/각주강의명시;1–7/9–15정규27일.8/16시험held.실크로드전쟁/항해는교육주제≠학생현장출석.외국인전용보존.', 1152: 'GED11110S00 심한별 수15–17:45청308:강의실대면기본/휴일조건부live;1–9/11–14정규13일,8자체정상강의10/21예외.10답사·15구술기말·16공란held.팀도시조사과제≠전체field;워크샵은강의실토론.', 1153: 'GEE1611S00 고인태/이재복 전체2계획읽음:12/27–29 집중스키 날짜명확/일별HH없음.9/16OTstart18만end없음.주차표교육주제를학기전체weekly로전파0.개별날짜·비용·출결제한·실습장보존held0new.', 1154: 'GEE1611S02 고인태/이재복 전체2계획읽음:1153와동일실제교육운영,own코드분반각확인.집중12/27–29일별HH없고OTend없음held.', 1155: 'GEE1619S00 이동건/고인태 자체2계획전체읽음:OT9/1화18–19네오104가운영/주차/안내일치.별도1회좁은후보가능.집중실습9/11–13청평은dailyHH없음held,학기weekly전파0.', 1156: 'GEE1611S03 이동건/고인태 전체2계획읽음:12/27–29집중스키일별HH없음/9/16OTend없음held,다른분반시각차용0.', 1157: 'GEE1636S00 성순창 월09–11:45네B201/B202 명시이론+CPR/AED교실실습;1–7/9–15정규13일minus10/5.8/16평가영상은실기평가불가조건만이며정규교실전체remote아님.과제/생명구조주제≠임상현장.실제복수교실표기전체보존선택0.', 1158: 'GEE1636S01 성순창 월13–15:45네B201/B202 자체동일교육운영;1–7/9–15정규13일.own분반HH13–15:45확인,1157HH차용0.', 1159: 'GEE1626S01 강창균/김기영 2wholeplans읽음:2박3일택1실습반강좌분반과별개,9/18–20·10/30–11/1·11/6–8 날짜만dailyHH없음.다른저자미확정공지도보존.OT원격예정HH없음held0new.', 1160: 'GEE1626S00 강창균/김기영 2wholeplans읽음:위실습3옵션과그중개인배정/일별HH미확정.월별weekly주제는현장실습의내용일뿐주간시간표생성0.원문조건모두held보존.'}
groupWeeks={1131: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1132: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1133: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1135: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1136: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1137: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1138: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15]}, 1139: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1141: {0: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14]}, 1142: {0: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15]}, 1144: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1147: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1148: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1149: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1150: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1151: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1152: {0: [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14]}, 1157: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1158: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}}
groupPlan={1131: {0: 0, 1: 0}, 1132: {0: 0}, 1133: {0: 0, 1: 0}, 1135: {0: 0, 1: 0}, 1136: {0: 0, 1: 0}, 1137: {0: 0, 1: 0}, 1138: {0: 0}, 1139: {0: 0, 1: 0}, 1141: {0: 0, 1: 0}, 1142: {0: 0, 1: 0}, 1144: {0: 0, 1: 0}, 1147: {0: 0, 1: 0}, 1148: {0: 0, 1: 0}, 1149: {0: 0, 1: 0}, 1150: {0: 0, 1: 0}, 1151: {0: 0, 1: 0}, 1152: {0: 0}, 1157: {0: 0}, 1158: {0: 0}}
allowedWeekdays={};exceptDates={1149:{"2026-09-21"}};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
examExceptions={1152:{"2026-10-21"}}
allowedNativeGroups={1131: [0, 1], 1132: [0], 1133: [0, 1], 1135: [0, 1], 1136: [0, 1], 1137: [0, 1], 1138: [0], 1139: [0, 1], 1141: [0, 1], 1142: [0, 1], 1144: [0, 1], 1147: [0, 1], 1148: [0, 1], 1149: [0, 1], 1150: [0, 1], 1151: [0, 1], 1152: [0], 1157: [0], 1158: [0]}
calendarPlan={1131: 0, 1132: 0, 1133: 0, 1135: 0, 1136: 0, 1137: 0, 1138: 0, 1139: 0, 1141: 0, 1142: 0, 1144: 0, 1147: 0, 1148: 0, 1149: 0, 1150: 0, 1151: 0, 1152: 0, 1157: 0, 1158: 0}
assert len(HH)==19 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-1131];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet039b-three-explicit-live'/f'khu-{campus}-2026-2.three-fixed-live-prepared.json'));(P/f'packet040-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside040'}

 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet040-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet040-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2970,'baselineDates':55416,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2970+len(selected),'totalDates':55416+count})
