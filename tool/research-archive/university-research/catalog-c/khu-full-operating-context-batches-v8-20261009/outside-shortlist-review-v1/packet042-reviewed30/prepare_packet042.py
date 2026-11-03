# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet042-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={1191: [(2, 900, 1065, '네104')], 1192: [(2, 720, 795, '청407'), (4, 720, 795, '청407')], 1193: [(3, 720, 885, '네B201')], 1194: [(3, 900, 1065, '네B201')], 1195: [(5, 540, 705, '네105')], 1202: [(3, 720, 830, '네105')], 1203: [(4, 960, 1070, '청715')], 1205: [(3, 960, 1070, '청303')], 1218: [(2, 600, 710, '청303')]}
weeks={1191: [1, 2, 3, 4, 5, 14, 15], 1192: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1193: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1194: [1, 2, 3, 4, 5, 6, 9, 11, 12, 13, 15], 1195: [14], 1202: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1203: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1205: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1218: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]}
reasons={1191: 'GEE11007S00 박영균 화15–17:45네104: 전체원문읽음.주차6실제현장답사/9–12실제회기동벽화현장작업은HH·정확장소대응미확인held.1–5/14–15일반작품감상·드로잉·교실토론7일후보가능.7/13평가발표및8시안발표평가운영held,16기말.도시재생/대지미술교육주제를해당학생출장으로추정0.학교구GED1915중복제한보존.', 1192: 'GEE11027S00 조은아 화목12–13:15청407대면기본,1–7/9–15정규27일후보.11/19목19:30공연은별도실제현장HHstart만end미공표로추가0;같은주정규교실화목이론주제와시간이다름.교육감상영상은온라인강의아님.8/16시험held.실제학교MD예술체험/구GED1941제한·행사비용/초대·평가원문전체보존.', 1193: 'GEE11019S00 김예진 수12–14:45네B201명시대면기본/2전문가특강대면명시.비대면은상황에따른미래조건및사전공지로현재배정없음;1–7/9–15정규14일후보,8/16학교시험기간held.3동영상시청은색채교육자료.캠퍼스사진독립과제는매주강의실로전파0.학교구GED1929제한보존.', 1194: 'GEE11038S00 김예진 수15–17:45네B201명시대면기본,1–6/9/11–13/15일반이론11일후보.7/14현장전문가특강은Zoom실시간가능성이직접명시되어모드배정미확인held;10실제미술관현장장소·HH대응미확인held.5공청회워크샵은리차드세라교육사례/교실토론이지학생현장출장아님.8/16시험held,학교MD/구GED1882제한보존.', 1195: 'GEE11039S00 김흥모 금09–11:45네105대면+실시간비대면병행.14주자체대면표기자화상교실실기1일만후보.9/10스튜디오탐방실제field는현장장소/HH대응미확인held;15/16기말평가및다른주방식미배정held.영상links교육자료/미술MOMA교재로정규VOD추정0.학교구GED1956제한보존.', 1196: 'GEE11016S00 현수정 목15–17:45청205native이나own2026-2교육계획모든내용/주차날짜비어있음.원본빈plan존재와원문없이운영미확인구분held,다른뮤지컬과목시간차용0.', 1197: 'GEE1345S00 정화영 nativeHH없음/모든주차녹화VOD온라인·주당출석인정1주명시.10/13·12/8 18–18:20별도온라인시험은정규lecture생성0.교수출장Q&A불가·과제마감·오픈북인쇄물한정/구GED1724불가 등모든학교제한보존held.', 1198: 'GEE1988S00 정화영 화목09–10:15청509전체원문읽음.2/3비대면출장명시되나live/VOD구분없음.나머지이론·실습각주대면직접배정/명시대면기본미확인이고online방법별도선택.대면출석일반조건만을actualphysical전체배정으로단정0held.7중간10/13 09:30–09:50·15기말12/8시험은정규lecture전파0;16보강조건부.구GED1724/학교공결·과제제한모두보존.', 1199: "GEE1986S00 이찬우 금09–11:45청405:전체15중8대면(시험포함)/7녹화인데현재날짜대응미공표.9/25·10/9녹화날짜만확정되고나머지주교실배정은추정0held.반복'강의내용복습'을physical증거로추정0.출처난이도native하vs계획중이상모두보존/원문시험·조건부보강분리.", 1200: 'GEE1953S00 이찬우 금12–14:45청405전체원문읽음.8대면/7녹화일별배정없음,공휴일9/25·10/9녹화확정만.예제실습이physical증거아님held.교육계획난이도상/native중차이원문보존.별도보강미확정/시험실제수업전파0.', 1201: 'GEE1987S00 이찬우 금15–17:45청405전체원문읽음.운영8대면/7녹화vs진행추가설명공휴일2빼고첫주부터교실강의서로범위충돌.개별각주live/VOD배정없어시간비율어느값선택0held.폐암생존율은코딩예제≠임상현장.난이도native상/plan중차이그대로,15조건부보강/8·16평가분리.', 1202: 'ETC0515S00 김희경 수12–13:50네105:명시대면기본,건강문제시녹화는조건부현재지정날짜없음.자체MMDD와정규요일일치1–7/9–15정상14일후보,8/16시험held.영화영상이정규VOD아님,실습은교실창작/과제로남음.출석연락조건·PNP/평가원문수치차이보존.', 1203: 'ETC1514S00 안병태 목16–17:50청715명시대면기본+온라인병행가능조건;2~3주/1또는2주는비대면분량가능수치로actual주차지정아님.1–7/9–14일반12날짜후보(9/24휴일제외),8주표시험vs설명중간미실시충돌held,15기말·16보강held.가상현실/홀로그램교육주제≠실제원격강의.70%팀발표평가도정규교실토론과구분원문보존.', 1204: 'EDU3106S00 남경욱 화11–12:50청501 nativewhole읽음/이번registryplan0.기존currentOperatingCorrection과이전예약교육근거전체보존.새자체운영해결근거없음held,과거경고교정철회0.', 1205: 'EDU2107S00 박병용 수16–17:50청303대면기본명시+부득이VOD조건부.1–7/9–14정규13일후보,8/16보고서평가주차및15예비주간held.학교현장법률/신고·법원·장애학생/교육실습이교육주제/수강자공결조건이며이강좌실제field배정아님.댓글자료제출은VOD강의증거아님.교직전용/공결법률·보고서·출석및학교문구전체보존.', 1206: 'EDU3104S00 조민휘 월10–11:50청302native/자체plan존재하지만교육전체빈값.1196와전체빈교육섹션동일actual확인held.외학교/다른교수대면운영차용0.', 1207: "EDU2114S01 편지명 수18–18:50청402native+ownplanclock+1–7/9–14각주대면13주 일치.학교비고'시간표미확정'원문그대로존재하여현재최신HH확정과상충가능성별도검토pending.교육대학원교수소속은학부교직전용강좌범위와구분.8/16평가·15보강held,AI/LMS실습주제는실제현장출장아님.원문비고삭제로상충해결0.", 1208: 'EDU2109S00 성수연nativeHH없음/학교서울학부교직전용/EDU2108필수선수원문있음.자체전체교육계획빈내용실제확인held,자격검사검증시간추정0.', 1209: 'EDU2110S00 성수연nativeHH없고자체교직CPR강좌교육계획모두빈내용.다른GEE1636성순창과제목CPR같다는이유로시간join0held.서울학부교직전용비고보존.', 1210: 'EDU2113S00 성수연nativeHH없음/교육계획빈내용.EDU2112필수선수1/서울학부교직전용보존,교육자격검사기간시각추정0held.', 1211: 'EDU2111S00 성수연nativeHH없음/교육계획빈내용.EDU2110필수선수1및0학점서울학부교직전용보존.다른CPR정규교양시간차용0held.', 1212: 'EDU2108S00 성수연nativeHH없음/교직검사교육원문빈내용확인held.학교서울학부교직전용0학점원문보존,자체검사일시생성0.', 1213: 'EDU2112S00 성수연nativeHH없음/성인지1교육원문빈내용확인held.학교서울학부교직전용0학점원문보존,타학년/자격검사일시차용0.', 1214: 'EDU4101S00 성수연nativeHH없음/실시간OT9월중공지예정날짜·HH없음/봉사개인현장또는비대면지도날짜미배정.자체교육원문전체읽어학교일지제출16주를수업시간생성0held.', 1215: 'EDU4102S00 성수연nativeHH없음/own교육원문1과동일현장/비대면개인지도.OT날짜HH미게시/봉사일지후기별도조건학교문구보존held,교수공통제목join으로시각생성0.', 1216: 'EDU3105S01 성수연 목15–16:50청302native이나own교육전체빈계획확인held.학교현장실습이전이수는선수순서제한이지이강좌실제field/운영기간증거아님.교직전용2,3학년대상보존.', 1217: 'EDU3105S00 성수연 화15–16:50청302native/자체다른분반code정확및교육빈내용held.학교2,3학년/실습이전이수조건보존,동일제목분반시간join0.', 1218: 'EDU3103S00 윤정미 화10–11:50청303전체명시대면/1–14정규14일.중간미실시및시험기간수업명시원문8정상10/20개별예외.15휴강예정/조건부보강·16기말제외.교생실습학생공결조건과이강좌실제교육현장실습후기토론은구분(전체field로추정0).원문학교교직제한및평가%/본문%상충/AI윤리모두보존.', 1219: 'OPEN100100 이정희 토HH없음/whole교육계획비실시간온라인,월23:59출석마감.의료·공간주제는강연교육주제이지field,마감시각을강의로생성0held.2026-2글로벌열린전공신입생전용보존.', 1220: 'OPEN100400 이정희 토HH없음/100%원격선택녹화전공강좌.15개선택/30강좌수강원문수치차이모두보존,12/22기말보고서마감·매주화23:58포트폴리오·23:59강의완료는정규live생성0held.열린전공재학생전용학교비고보존.'}
groupWeeks={1191: {0: [1, 2, 3, 4, 5, 14, 15]}, 1192: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1193: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1194: {0: [1, 2, 3, 4, 5, 6, 9, 11, 12, 13, 15]}, 1195: {0: [14]}, 1202: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1203: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1205: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1218: {0: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]}}
groupPlan={1191: {0: 0}, 1192: {0: 0, 1: 0}, 1193: {0: 0}, 1194: {0: 0}, 1195: {0: 0}, 1202: {0: 0}, 1203: {0: 0}, 1205: {0: 0}, 1218: {0: 0}}
allowedWeekdays={};exceptDates={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
examExceptions={1218:{"2026-10-20"}}
allowedNativeGroups={1191: [0], 1192: [0, 1], 1193: [0], 1194: [0], 1195: [0], 1202: [0], 1203: [0], 1205: [0], 1218: [0]}
calendarPlan={1191: 0, 1192: 0, 1193: 0, 1194: 0, 1195: 0, 1202: 0, 1203: 0, 1205: 0, 1218: 0}
assert len(HH)==9 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-1191];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet040b-one-physical-orientation'/f'khu-{campus}-2026-2.one-physical-orientation-prepared.json'));(P/f'packet042-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside041'}

 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet042-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet042-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2999,'baselineDates':55890,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2999+len(selected),'totalDates':55890+count})
