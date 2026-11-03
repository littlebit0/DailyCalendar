# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet034-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={951: [(1, 900, 1065, '미500,501'), (2, 540, 705, '미500,501')], 952: [(2, 900, 1065, '미500,501'), (4, 720, 885, '미500,501')], 953: [(2, 900, 1065, '미400'), (5, 540, 705, '미400')], 954: [(4, 780, 890, '미600'), (2, 840, 950, '미600')], 957: [(4, 600, 710, '미400'), (2, 600, 710, '미400')], 958: [(1, 780, 945, '미502,미209'), (2, 600, 765, '미502')], 959: [(2, 600, 765, '미402'), (1, 900, 1065, '미402')], 960: [(4, 600, 765, '미208'), (3, 660, 825, '미504')], 961: [(2, 900, 1065, '미504'), (3, 600, 765, '미208')], 963: [(2, 660, 825, '미404,406'), (4, 600, 765, '미404,406')], 964: [(2, 660, 825, '미403,405'), (5, 600, 765, '미403,405,106목공실')], 965: [(1, 900, 1065, '미401'), (2, 600, 765, '미401')], 966: [(1, 780, 945, '미503'), (2, 600, 765, '미503')], 968: [(4, 900, 1065, '미102,103'), (3, 900, 1065, '미102,103')], 970: [(2, 600, 765, '미200'), (4, 660, 825, '미200')], 971: [(2, 600, 765, '미206,208'), (1, 720, 885, '미300')], 973: [(1, 780, 945, '무204')], 977: [(3, 540, 705, '무205')], 979: [(1, 660, 770, '무501'), (1, 780, 890, '무501'), (3, 660, 770, '무B201')], 980: [(4, 780, 890, '무502'), (2, 900, 1010, '무502')]}
weeks={951: [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 15], 952: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 953: [1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14], 954: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 957: [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 14], 958: [1, 9, 15], 959: [1, 2, 3, 4, 5, 6, 7, 9, 12, 13], 960: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 961: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 963: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 964: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14], 965: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14], 966: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 968: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11], 970: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 971: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 973: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 977: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 979: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 980: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
reasons={951: '김은영 자체 화요일 명시대면만1–6/9–13/15;구인성 월요일 모드미확인은보류.7/14시험과8공통시험기간제외.', 952: '두담당명시대면을자체요일로구분.화1–6/9–14,목1–7/9–13/15;개별면담은정규실기중지도.화15보강실제배정미공표·목14실기평가held.', 953: '서기환 자체화요일실기시범/대면불가시에만Zoom조건;1–5/9–14.6평가7교외15최종평가held.금요일김준기별도운영보류.', 954: '나웅채 자체화요일명시대면1–7/9–14;목요일이수빈mode미확인held·화15평가held.', 955: '졸업제작개인작업및설치교내외범위공존,현재담당자별대면group미확인.교수다른요일대면전파0.', 956: '문이원100%대면이나한수업4교시진행조건과native2시간45분의현재적용불명;이호억야외/전시·별도운영.두group보류·시각선택0.', 957: '유희선 자체목요일대면1–6/9–12/14만.7/13/15평가8야외·공통시험held.다른화요일지도모드추정0.', 958: '노은주모든대면이나그룹1/2교대·야외별도.자체화1/9/15전체수업만.허수영월교실502/209유형매핑은후속검토held로원문보존.', 959: '임다인자체화대면1–7/9/12/13;10/14그룹크리틱이중간기말평가임을원문이명시하므로held.8전시시작10AM끝없음11현장15과제전별도배정held.이세준월모드추정0.', 960: '두담당자체대면및목/수HH각1–7/9–15정규.영상편집·프로젝션은교육주제이며VOD수업아님.', 961: '신민아화1–7/9–15,노송희수1–7/9–14명시대면.보조영상/Notion자료는원격배정아님.수15최종평가16보강held.', 962: '졸업논문은작품제작/전시평가대체,5분native월slot전체매주실제운영미확인held.', 963: '자체교수요일별대면.화1–5/7/10–14,목1–3/5–7/9–14.화6추석표기2026요일로수정0,9중간15Dec11vs화native날짜상충held·목15세미평가held.', 964: '황수연자체화대면및수업시간내전체작업1–7/10–14,8/9분임중간평가15보강16기말held.금김동희목공/CNC실기실수업근거별도보존·대면범위현재검토held.', 965: '신정균자체월대면1–7/10–14,9외부전시15최종평가held.김효림화모드미확인/10휴강/13–14최종평가보존held.', 966: '각담당명시대면자체요일.월1–4/6–7/9/11–14,화1–6/9–13.개별중간/최종크리틱·오픈스튜디오교외·휴일·시험held.', 967: '실기/영화/개별지도교육주제만으로현재대면/live범위확정불가;두담당모드미확인held.', 968: '김기라자체목대면1–7/9–11강의워크샵만.12최종발표13전시14결과발표15종합평가held.한승구수졸업전시구체설치기간별도/모드미확인held.', 969: '두담당실기/개인면담/현장학습·창작주제만현재대면/live미확인;타미술대면차용0.', 970: '이석준자체목명시대면1–7/9–14,15연구발표평가held.양상근화가마실기교육주제만으로운영방식추정0.', 971: '두담당명시대면·자체화컴퓨터실/월실기실.화9중간평가held,월정규1–7/9–15(공통시험기간제외).모델에티켓·안전·타대수강불허전체보존.', 972: '졸업논문native5분slot교육전체공란실제매주수업미확인held.', 973: '대면기본/부득이할때만원격가능조건은현재배정아님.자체월1–7/9–14정규,15수업없음/필요시보강held.한의학내용을의료실습기간으로추정0.', 974: '참여형터칭/실기수업근거있으나명시대면/live모드미확인,교수다른수업차용0.신체상태대체활동/동의제약보존held.', 975: '이론토론·팀활동·선택현장연계원문,대면/live모드미확인.15보강실제HH/날짜불명held.', 976: '대면기본이나9/8휴강·9/15첫수업화요일vsnative금요일current날짜상충.사례현장방문과현재group모드/날짜불명held·올해요일로교정0.', 977: '자체수09–11:45대면명시1–7/9–15.공연역사·영상자료는수업주제,실제교외운영배정아님.', 978: '졸업논문HH미공표/전체교육공란held.', 979: '성은경자체수명시실기대면1–7/9–15만.홍승희/박주현월2group시범실기근거와장구준비원문보존하나모드확정후속held;월15보강배정불명.', 980: '한솔자체목전면대면1–7/9–15·4주명시휴강.화장동아동작교육/영상시청은주제이며현재대면운영확정후속held.시험1–3명개별배정은전체slot생성0.'}
groupWeeks={951: {1: [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 15]}, 952: {0: [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 15]}, 953: {0: [1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14]}, 954: {1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 957: {0: [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 14]}, 958: {1: [1, 9, 15]}, 959: {0: [1, 2, 3, 4, 5, 6, 7, 9, 12, 13]}, 960: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 961: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 963: {0: [1, 2, 3, 4, 5, 7, 10, 11, 12, 13, 14], 1: [1, 2, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 964: {0: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14]}, 965: {0: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14]}, 966: {0: [1, 2, 3, 4, 6, 7, 9, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13]}, 968: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11]}, 970: {1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 971: {0: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 973: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 977: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 979: {2: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 980: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}}
groupPlan={951: {1: 0}, 952: {0: 0, 1: 1}, 953: {0: 0}, 954: {1: 1}, 957: {0: 1}, 958: {1: 1}, 959: {0: 1}, 960: {0: 0, 1: 1}, 961: {0: 1, 1: 0}, 963: {0: 0, 1: 1}, 964: {0: 1}, 965: {0: 1}, 966: {0: 1, 1: 0}, 968: {0: 1}, 970: {1: 1}, 971: {0: 1, 1: 0}, 973: {0: 0}, 977: {0: 0}, 979: {2: 2}, 980: {0: 0}}
allowedWeekdays={};exceptDates={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={};examExceptions={};allowedNativeGroups={951: [1], 952: [0, 1], 953: [0], 954: [1], 957: [0], 958: [1], 959: [0], 960: [0, 1], 961: [0, 1], 963: [0, 1], 964: [0], 965: [0], 966: [0, 1], 968: [0], 970: [1], 971: [0, 1], 973: [0], 977: [0], 979: [2], 980: [0]};calendarPlan={951: 0, 952: 0, 953: 0, 954: 1, 957: 1, 958: 1, 959: 1, 960: 0, 961: 1, 963: 0, 964: 1, 965: 1, 966: 1, 968: 1, 970: 1, 971: 1, 973: 0, 977: 0, 979: 2, 980: 0}
assert len(HH)==20 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-951];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet033-reviewed30'/f'khu-{campus}-2026-2.packet033-physical-groups-prepared.json'));(P/f'packet034-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside034'}

 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet034-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet034-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2871,'baselineDates':53769,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2871+len(selected),'totalDates':53769+count})
