# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet041-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={1164: [(3, 900, 1065, '청620')], 1185: [(2, 900, 1065, '청507')]}
weeks={1164: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1185: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}
reasons={1161: 'GEE1626S03 김기영/강창균 2전체계획읽음.승마3실습옵션택1/개인반별미배정및dailyHH없음.OT녹화시각없음.교수별현재분반코드확인.held.', 1162: 'GEE1626S02 홍대석/강창균 2전체계획읽음.동일집중승마/일별HH미공표·개인택1실습반은강좌분반과별개.교육주차표를weekly일정으로생성0.held.', 1163: 'GEE1609S00 박진수/강창균 2전체계획읽음.종강후12/27–29스노보드actual3일이지만dailyHH없음.9/1OT녹화시각0.일반semesterweekly생성0.held.', 1164: 'GEE1658S00 강창균 수15–17:45청620 명시강의실대면기본/보강content조건부,1–7/9–14정규13일.8/16ecampus시험·15미확정보강 제외.일부분ecampus문구원문보존하고과제제출/평가온라인은regular실시간전체로추정0.체력평가·재난/건강주제≠실제임상현장.', 1165: 'GEE1661S03 이재복/홍대석 2전체계획읽음.10/30–11/1 또는11/6–8택1집중camping개인미배정/dailyHH없음.9/16OT17start끝시각없음.held.', 1166: 'GEE1661S00 홍대석/이재복 2전체계획읽음.own동일camping실습옵션2택1/OTend없음/주간HH없음.held.', 1167: 'GEE1620S00 이재복/박진수 2전체계획읽음.수상스키9/5–7또는9/12–14택1/보충가능/오전오후택1dailyHH없음.9/1OT18startonly끝없음.다른수상스포츠18–19HH차용0.held.', 1168: 'GEE1620S02 이재복/박진우 2전체계획읽음.동일수상스키택1분반/오전오후추가선택미배정·HH미공표.실습비추후공지차이보존.held.', 1169: 'GEE1626S04 김기영/홍대석 2전체계획읽음.집중승마분반과별개3일옵션선택dailyHH없음.원격OT시각없음.held.', 1170: 'GEE1620S03 박진수/김성호 2전체계획읽음.실제수상스키개인택1두일정/오전오후선택미배정HH없음.학교원문비용차이/출결조건유지held.', 1171: 'GEE1632S00 김성호/최명규 2전체계획읽음.자체2026-2서울exact코드/교수2/9/5토·9/6일·9/7월3일모두참여/daily09–18/아라마리나요트장이 운영·유형·주차·안내일치.별도집중3일literal후보가능.OT녹화HH생성0,weekly교육주제시각전파0.날씨변동/사전교수협의조건보존실제출석주장0.', 1172: 'GEE1611S01 이윤님/홍대석 2전체계획읽음.교수소속국제표시는본강좌서울캠퍼스자체확인과구분.집중스키12/27–29dailyHH없음/9/16OTend없음held.', 1173: 'GEE1635S02 박진우/박진수 2전체계획읽음.명시집중윈드서핑10/3토개천절·10/4일·10/5월대체공휴일3일/daily09–18/서울윈드서핑훈련장36호가운영·유형·주차·안내일치.자체명시휴일수업예외3일만후보가능.녹화OT정규시각0/16주평가주제실제일자로전파0.날씨변동조건/학교제한모두보존.', 1174: 'GEE1661S02 최명규/박진수 2전체계획읽음.캠핑택1두실습일정·개인배정dailyHH없음/9/16OT17startonlyheld.', 1175: 'GEE1609S01 최웅빈/박진수 2전체계획읽음.스노보드집중12/27–29dailyHH미공표/녹화OTHH없음held.', 1176: 'GEE1632S01 박진우/최명규 2전체계획읽음.자체요트9/5·6·7daily09–18아라마리나 각분반own원문일치.3일만literal후보가능,다른분반소속/원격OT시각차용0.', 1177: 'GEE1635S03 이윤님/박진우 2전체계획읽음.서울개설/교수의국제소속구분.자체10/31·11/1·11/2daily09–18서울윈드서핑훈련장36호일치,3일집중literal후보가능.', 1178: 'GEE1635S01 김우진/박진우 2전체계획읽음.자체9/12·13·14daily09–18같은own장소명시.타분반날짜차용0,3일literal후보가능.', 1179: 'GEE1603S01 선대규 월11–12:50네오농구장:대면/비대면비율변경·필요시비실시간1–2회및수업방법online선택.각주physical직접배정없음이번좁은후보held.영상과제는강의VOD추정0.중간없음vs주차실기/대체과제상충원문유지.', 1180: 'GEE1603S02 선대규 월13–14:50ownHH확인;동일own혼합일별배정미확인held.다른분반11시차용0.', 1181: 'GEE1661S01 이동건/최명규 2전체계획읽음.캠핑택1실습/dailyHH없음/OTend없음held.', 1182: 'GEE1632S02 최웅빈/최명규 2전체계획읽음.자체11/21·22·23daily09–18아라마리나일치.각분반3일집중literal후보가능,기말weekly교육주제로extra날짜생성0.', 1183: 'GEE1632S03 최웅빈/최명규 2전체계획읽음.동일own11/21·22·23daily09–18/장소각실제원문확인3일후보가능.타분반join아님ownsource정확보존.', 1184: 'GEE1609S02 최명규/최웅빈 2전체계획읽음.스노보드12/27–29dailyHH없음/녹화OT시각없음held.', 1185: 'GED11063S00 김용철 화15–17:45청507 판서필기+실제이론강의/매스미디어자료30%이며온라인은공휴일보강조건부.1–7/9–14정규13일,8시험15/16기말제외.가상현실/우주SF교육주제≠actualremote/field.원문모두보존.', 1186: 'GED11080S00 김상균 fixedHH없음/VOD모든수업사전녹화명시.기말15주금18–20는시험별도이며현재정규live생성0.수강마감2030예시를2026실제날짜추정0.인원증원불가/출석조건/숏츠과제원문보존held.', 1187: 'GED11099S00 이현숙 금15–17:45청509 native확인되나학교수업방법온라인별도선택/physical직접배정없음.인터넷게임/영상자료교육주제자체와실제remote구분하지만이번분반방식미확인held.8발표중간vs평가0등차이원문유지.', 1188: 'GED1999S01 김선명 금12–14:45native vs 자체운영12–14:30·150분명시end충돌.주차대면명시있어도시간값임의선택0전체held.특별세션초청은field방문아님,16대면정상예외있지만HH충돌남음.', 1189: 'GEE1333S00 김진해 독립연구개인계획·수시토론nativeHH없음.교수섭외/신청/지도승인절차원문보존held,semester전체일정생성0.', 1190: 'GEE1243S01 최주철 VOD/고정HH없음.별도Zoom시험10/20·12/15화18:10–19:00정규lecture전파0.주차휴보강날짜미배정,가산점사업자/중복가산제한학교원문보존held.'}
groupWeeks={1164: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1185: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}}
groupPlan={1164: {0: 0}, 1185: {0: 0}}
allowedWeekdays={};exceptDates={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
examExceptions={}
allowedNativeGroups={1164: [0], 1185: [0]}
calendarPlan={1164: 0, 1185: 0}
assert len(HH)==2 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-1161];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet040-reviewed30'/f'khu-{campus}-2026-2.packet040-physical-groups-prepared.json'));(P/f'packet041-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside041'}

 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet041-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet041-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2989,'baselineDates':55842,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2989+len(selected),'totalDates':55842+count})
