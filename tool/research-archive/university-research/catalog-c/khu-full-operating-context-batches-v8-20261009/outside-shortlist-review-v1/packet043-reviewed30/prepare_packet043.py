# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet043-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={1223: [(2, 810, 885, '구한의대 B100호'), (5, 810, 885, '구한의대 B100호')], 1225: [(1, 540, 615, '구(한)205'), (3, 540, 615, '구(한)205')], 1226: [(1, 720, 795, '구한의대 B100호'), (3, 720, 795, '구한의대 B100호')], 1230: [(1, 810, 885, '외202'), (3, 810, 885, '외202')], 1236: [(2, 720, 795, '외308'), (4, 720, 795, '외308')], 1237: [(1, 540, 615, '외402'), (3, 540, 615, '외402')], 1238: [(1, 810, 885, '외204'), (3, 810, 885, '외204')], 1239: [(1, 900, 975, '외204'), (3, 900, 975, '외204')], 1240: [(5, 540, 705, '외201')], 1242: [(2, 630, 705, '외401'), (4, 630, 705, '외401')], 1243: [(1, 720, 795, '외402'), (3, 720, 795, '외402')], 1244: [(2, 900, 975, '외401'), (4, 900, 975, '외401')]}
weeks={1223: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1225: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1226: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1230: [1, 2, 3, 4, 5, 6, 9, 10, 11, 12], 1236: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11], 1237: [1, 2, 3, 5, 6, 7, 9, 11, 12, 13, 15], 1238: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1239: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1240: [1, 2, 3, 5, 10, 11], 1242: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1243: [1, 2, 4, 5, 6, 7, 8, 10, 11, 12, 13], 1244: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}
reasons={1221: 'OPEN100300 김상현 토nativeHH없음/자체원격12주후13–15대면세미나명시이나dailyHH없음.15예비보강/16실시간report는역시HH없어held.교수기계공학소속은학부열린전공캠퍼스와구분,전체원문보존.', 1222: 'GLEE401000 서인겸nativeHH없음/글로벌리더졸업논문전체교육빈계획직접확인held.법학전문대학원교수소속을본학부강좌graduate로오분류0,졸업논문지도시각생성0.', 1223: 'GLEE100300 전세영 화금13:30–14:45구한의대B100호명시대면원칙.1–7/9–15정규26일후보(9/25·10/9holiday제외).8/16시험및보강개별미배정held.민법기간/법원교육주제는운영기간/현장견학아님.학교원문휴일·출결·평가·분반00모두보존.', 1224: 'GBIZ401100 이정희0학점논문대면지도지만HH없음/개인논문전체주차내용없음.글로벌비즈니스전용/8학기이상원문제한보존held.학기전체지도시각추정0.', 1225: 'GBIZ301100 양정준 월수09–10:15구(한)205명시대면기본1–7/9–15정규27일(10/5휴일제외).카지노국내해외산업은이론교육/사례분석이지실제방문,online은부득이사전공지조건.8/16시험held.학교글로벌비즈니스전용/원문팀발표평가·교재TBA보존.', 1226: 'GBIZ101300 양정준 월수12–13:15구한의대B100호자체대면기본1–7/9–15정규27일.호텔시설안전관리교육주제≠실제현장실습.8/16시험held;학교글로벌비즈니스전용/전공기초/교재공지및전체원문보존.', 1227: 'GBIZ201700 김하늬 월수09–10:15구(한)206전체원문읽음.PPT·강사구두퀴즈·시청각자료설명과출석교실행동수칙은있으나online강의별도선택/native원문과현재physical명시배정미확인held.세계이주/노동교육주제≠actualfield,멘티미터전자퀴즈가VOD라는주장0.학교글로벌비즈니스전용보존.', 1228: 'SDM40101 정주원0학점학생설계논문/HH없음·자체전체교육계획빈내용held.01분반/학생설계교육소속과교수행정학소속분리보존,졸업논문지도시간생성0.', 1229: 'ELC10400 PeggyCho 국제월수10:30–11:45외202전체원문읽음.교재online기사영상은교육자료이나원문수업방법online별도선택/운영설명공란으로현행physical직접배정미확인held.80%발표실습·사전말하기서면제출조건보존,비디오를VOD강의로추정0.', 1230: "ELC20301 PeggyCho 국제월수13:30–14:45외202:own 'all classes will be in-person' 기본명시.1–6/9–12정규토론19날짜후보(10/5휴일제외);7/8speech평가·13/14groupdebate발표평가·15/16final발표별도운영held.Youtube/TED/online자료는토론학습자료/온라인댓글과제이며lectureVOD아님.글커우선수강제한/모든학교평가·조건부내용업로드보존.", 1231: 'ELC38000 윤재학 국제월수13:30–14:45외401nativewhole읽음/이번plan0.기존holiday오표기/operatingcorrection학교및연구whole보존.새own운영해결자료없음held,과거예약철회취소0.', 1232: 'ELC48400 김상욱 국제0학점개별논문. 필요시 실시간온라인 또는 지도교수연구실이나 ownHH없음. 전체논문단계/20페이지요건 보존held.', 1233: 'FR101200 오정숙 국제 native 화목10:30–11:45외403이나 registryplan0. 기존currentOperatingCorrection/학교 및 연구 전체 객체 그대로held. 새 자체운영증거없음.', 1234: 'FR201201 오정숙 국제 화목12–13:15외405. 문법설명/문제풀이교육내용과online방법별도선택, 대면기본/날짜별방식 배정미확인held. 8시험/15보강/16시험 보존.', 1235: 'FR430000 김민채 졸업학기요건강좌 자체 강의없음 명시. B1자격증/졸업시험또는캡스톤 충족시Pass. HH없음, 시험날짜시각생성0held.', 1236: 'KO320200 이선이 화목12–13:15외308 대면기본명시.1–7/9–11 이론·교안토론19날짜후보.12–15발표평가/8·16시험구분held.11월10일23:59과제마감은강의시각아님. 문화교육현장이라는교육주제≠학생실제field. 상황별remote가능조건보존.', 1237: 'KO120100 김종수 월수09–10:15외402 대면기본+휴일녹화명시.1–3/5–7/9/11–13/15 정상교육21날짜후보.4/10/14발표평가그룹·8/16시험held. 모든MMDD자체요일일치,10/5녹화시각생성0. 영상시청과강의복합교육자료는전체VOD아님.', 1238: 'KO210100 이선웅 월수13:30–14:45외204대면기본.1–7/9–14 정상25날짜후보.8중간/15기말/16빈주held. 공휴일콘텐츠업로드 비실시간강의는정각예약0,교재통사교육과학생질문원문보존.', 1239: 'KO210500 이선웅 월수15–16:15외204 자체1238와동일대면원칙·휴일비실시간원문확인.1–7/9–14 정상25날짜후보.8중간15기말16빈주held. 어휘게임은교육주제/교실실습이며개별field아님.', 1240: 'KO410500 성아영 금09–11:45외201 전체대면명시.1–3/5/10–11 교실이론·교안지도6날짜후보.7–9 실제언어교육원참관09–11:50은native종료11:45와상충하고장소매핑다르므로held.4영상보강/6휴강/12–15모의수업평가/16총평 별도held. field비용·교원자격이수권고/모든마감원문보존.', 1241: 'KO430100 염원희 개인논문지도/시험일정ecampus공지예정·nativeHH없음.11월초졸업시험예정이나exact날짜HH없어held. 개별면담시각·논문마감시각생성0.', 1242: 'KO320500 염원희 화목10:30–11:45외401대면원칙.1–7/9–15 일반27날짜후보.8일반교육내용있지만중간평가30%자체날짜미게시여서학교중간기간보수held,16기말. 조별활동은평가안함원문명시/문화·유산주제≠actual출장. 휴일비실시간조건보존.', 1243: 'KO320600 나상수 월수12–13:15외402 대면기본.1–2/4–8/10–13 일반21날짜후보. 자체중간시험9주이며8주문장통계정상실습배정으로10/21·26예외.3실제9/17–19코엑스개별또는단체중택참관HH미확인held;14조별개별면담/15–16평가발표held. 선이수추천/영어부분·도구API교육은접근증거나actualremote아님.', 1244: 'KO220300 김영임 화목15–16:15외401대면기본.1–7/9–14 문학이론25날짜후보.8시험15보강·과제발표16평가발표held. 작가집중읽기는특별운영집중기간이아님. 개별상담/길라잡이발표조건전체보존.', 1245: 'JP40100 손지연 졸업논문 대면지도명시이나HH없음. 개별지도교수선정/20,000자논문/학과제출조건보존held. 주차단계로HH생성0.', 1246: 'JP37900 손지연 국제 native전체읽음 registryplan0. 기존운영정정·온라인방법보류증거원객체불변held. 새상반되는자체원문없음.', 1247: 'JP11600 손지연 국제 native전체읽음 registryplan0. 기존운영정정·온라인방법보류증거원객체불변held. 영화라는제목으로VOD판정0.', 1248: 'CHI20600 배재석 월수12–13:15외308. 자체online방법선택/운영설명강의발표토론만, 현재대면직접배정미확인held. 시험대면원칙을정규lecturephysical로전파0. 학생유학생교환학생수강금지·2학년전용원문보존.', 1249: 'CHI40800 김경석 졸업논문0학점HH없음/주차교육에학술대회참관·발표포함하지만개별시각미게시held. 2027년2월졸업예정자제한보존,캡스톤주제문구로다른과목join0.', 1250: 'CHI41300 주재우 국제nativewhole plan0. 기존operatingcorrection원객체그대로held. 타학과중국학생수강금지원문보존,새자체대면증거없음.'}
groupWeeks={1223: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1225: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1226: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1230: {0: [1, 2, 3, 4, 5, 6, 9, 10, 11, 12], 1: [1, 2, 3, 4, 5, 6, 9, 10, 11, 12]}, 1236: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11]}, 1237: {0: [1, 2, 3, 5, 6, 7, 9, 11, 12, 13, 15], 1: [1, 2, 3, 5, 6, 7, 9, 11, 12, 13, 15]}, 1238: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1239: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1240: {0: [1, 2, 3, 5, 10, 11]}, 1242: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1243: {0: [1, 2, 4, 5, 6, 7, 8, 10, 11, 12, 13], 1: [1, 2, 4, 5, 6, 7, 8, 10, 11, 12, 13]}, 1244: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}}
groupPlan={1223: {0: 0, 1: 0}, 1225: {0: 0, 1: 0}, 1226: {0: 0, 1: 0}, 1230: {0: 0, 1: 0}, 1236: {0: 0, 1: 0}, 1237: {0: 0, 1: 0}, 1238: {0: 0, 1: 0}, 1239: {0: 0, 1: 0}, 1240: {0: 0}, 1242: {0: 0, 1: 0}, 1243: {0: 0, 1: 0}, 1244: {0: 0, 1: 0}}
allowedWeekdays={};exceptDates={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
examExceptions={1243:{"2026-10-21","2026-10-26"}}
allowedNativeGroups={1223: [0, 1], 1225: [0, 1], 1226: [0, 1], 1230: [0, 1], 1236: [0, 1], 1237: [0, 1], 1238: [0, 1], 1239: [0, 1], 1240: [0], 1242: [0, 1], 1243: [0, 1], 1244: [0, 1]}
calendarPlan={1223: 0, 1225: 0, 1226: 0, 1230: 0, 1236: 0, 1237: 0, 1238: 0, 1239: 0, 1240: 0, 1242: 0, 1243: 0, 1244: 0}
assert len(HH)==12 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-1221];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet042-reviewed30'/f'khu-{campus}-2026-2.packet042-physical-groups-prepared.json'));(P/f'packet043-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside043'}

 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet043-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet043-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':3008,'baselineDates':56003,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':3008+len(selected),'totalDates':56003+count})
