# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet035-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={981: [(3, 780, 890, '무B202'), (1, 900, 1010, '무501')], 983: [(2, 660, 770, '무B202'), (4, 900, 1010, '무501'), (3, 900, 1010, '무501')], 985: [(2, 540, 650, '무501'), (3, 780, 890, '무501')], 986: [(1, 660, 770, '무502'), (2, 660, 770, '무502')], 988: [(4, 900, 1010, '무B201'), (4, 660, 770, '무B201'), (5, 660, 770, '무B201')], 989: [(1, 780, 890, '무B202'), (1, 540, 650, '무B201')], 990: [(2, 540, 650, '무B201'), (5, 780, 890, '무B202')], 993: [(1, 780, 890, '무B201'), (4, 780, 890, '무B202'), (5, 660, 770, '무B202')], 994: [(2, 780, 890, '무B201'), (5, 780, 890, '무B201')]}
weeks={981: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 983: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 985: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 986: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 988: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 989: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 990: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 993: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 994: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
reasons={981: '두담당각own대면·HH·주별1–7/9–14만.월15보강및수15기말평가held;학년/이수구분제약그대로보존.', 982: '반복실기/시범/복장제약은교육방법이나담당자별현재대면/live실제운영명시미확인.두group보류;다른수업대면차용0.', 983: '강미선화명시대면1–7/9/11–14,박소현목전면대면1–7/9–14.화10원문휴강·목15보강·시험held.수김시원실기교육모드미확인,카메라/외부공유금지전체보존.', 984: '정향숙대면이나개요120분vsnative110분·주6Oct9Fri표기vsownWed상충.박철순실기방법만모드미확인.임의HH/요일교정0·두groupheld.', 985: '백상하자체수100%대면1–7/9–14·수업내작품시연/크리틱은별도공연출석아님.수15보강actualHH불명held.정향숙화개요120vsnative110분상충held.', 986: '두담당명시대면ownHH.전수현월1–6/9/11–14,7중간고사·10May5원문휴강·15빈·시험held.권미정화1–7/9–15자체창작실습;다른담당휴강전파0.', 987: '대면명시이나졸업논문HH없음.공연/리서치/결과자료일정을weeklyclock생성0.', 988: '세담당각자대면own목15/목11/금11 HH 및1–7/9–15만.금4Sep25휴강6Oct9공통휴일·16actual종강/평가·보강배정held.개별피드백은수업내지도.', 989: '류진욱월09전시간대면1–7/9–15,유가원월13대면중점1–7/9–13.유14원문공휴일휴강·15보강held,장소변경가능조건원문보존·actual배정변경추정0.', 990: '유가원화대면1–7/9–13(14원문휴강15보강held),심재호금자체수업유형명시대면1–7/9–15.교육창작주제를개별출석이나공연기간으로추정0.', 991: '발레실기및바/센터/포인트훈련은교육내용.두담당대면/live명시미확인held.월15보강actual배정불명보존.', 992: '졸업논문HH없음·현재교육계획기본정보외공란.예약추정0.', 993: '김지영월대면1–7/9–14,이승현금대면1–7/9–14.두15보강actual날짜/HH미정held.유난희목운영방식바/센터/포인트만대면미확인held.', 994: '김지영화대면1–7/9–15,이승현금대면1–7/9–14.금15보강및공통휴일시험held.학년별테크닉·준비과제전체보존.', 995: '현재학점교류native전체읽음.강의계획캐시0/HH미공표;fullplan읽음으로계수0.학번별교양인정제약보존·사이버과목명만으로시각생성0.', 996: '현재학점교류native전체읽음.강의계획캐시0/HH미공표;fullplan읽음으로계수0.학번별교양인정제약보존·사이버과목명만으로시각생성0.', 997: '현재학점교류native전체읽음.강의계획캐시0/HH미공표;fullplan읽음으로계수0.학번별교양인정제약보존·사이버과목명만으로시각생성0.', 998: '현재학점교류native전체읽음.강의계획캐시0/HH미공표;fullplan읽음으로계수0.학번별교양인정제약보존·사이버과목명만으로시각생성0.', 999: '현재학점교류native전체읽음.강의계획캐시0/HH미공표;fullplan읽음으로계수0.학번별교양인정제약보존·사이버과목명만으로시각생성0.', 1000: '현재학점교류native전체읽음.강의계획캐시0/HH미공표;fullplan읽음으로계수0.학번별교양인정제약보존·사이버과목명만으로시각생성0.', 1001: '현재학점교류native전체읽음.강의계획캐시0/HH미공표;fullplan읽음으로계수0.학번별교양인정제약보존·사이버과목명만으로시각생성0.', 1002: '현재학점교류native전체읽음.강의계획캐시0/HH미공표;fullplan읽음으로계수0.학번별교양인정제약보존·사이버과목명만으로시각생성0.', 1003: '현재학점교류native전체읽음.강의계획캐시0/HH미공표;fullplan읽음으로계수0.학번별교양인정제약보존·사이버과목명만으로시각생성0.', 1004: '현재학점교류native전체읽음.강의계획캐시0/HH미공표;fullplan읽음으로계수0.학번별교양인정제약보존·사이버과목명만으로시각생성0.', 1005: '현재학점교류native전체읽음.강의계획캐시0/HH미공표;fullplan읽음으로계수0.학번별교양인정제약보존·사이버과목명만으로시각생성0.', 1006: '해외학점교류생전용현재native및기본정보를포함한전체공란교육계획읽음.ownHH없으므로held·교수소속이대학원이라는이유로수강대상추정0.', 1007: '해외학점교류생전용현재native및기본정보를포함한전체공란교육계획읽음.ownHH없으므로held·교수소속이대학원이라는이유로수강대상추정0.', 1008: '해외학점교류생전용현재native및기본정보를포함한전체공란교육계획읽음.ownHH없으므로held·교수소속이대학원이라는이유로수강대상추정0.', 1009: '해외학점교류생전용현재native및기본정보를포함한전체공란교육계획읽음.ownHH없으므로held·교수소속이대학원이라는이유로수강대상추정0.', 1010: '해외학점교류생전용현재native및기본정보를포함한전체공란교육계획읽음.ownHH없으므로held·교수소속이대학원이라는이유로수강대상추정0.'}
groupWeeks={981: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 983: {0: [1, 2, 3, 4, 5, 6, 7, 9, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 985: {1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 986: {0: [1, 2, 3, 4, 5, 6, 9, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 988: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 2: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 989: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 990: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 993: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 2: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 994: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}}
groupPlan={981: {0: 1, 1: 0}, 983: {0: 2, 1: 0}, 985: {1: 1}, 986: {0: 0, 1: 1}, 988: {0: 0, 1: 1, 2: 2}, 989: {0: 1, 1: 0}, 990: {0: 0, 1: 1}, 993: {0: 1, 2: 2}, 994: {0: 0, 1: 1}}
allowedWeekdays={};exceptDates={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={};examExceptions={};allowedNativeGroups={981: [0, 1], 983: [0, 1], 985: [1], 986: [0, 1], 988: [0, 1, 2], 989: [0, 1], 990: [0, 1], 993: [0, 2], 994: [0, 1]};calendarPlan={981: 1, 983: 2, 985: 1, 986: 0, 988: 0, 989: 1, 990: 0, 993: 1, 994: 0}
assert len(HH)==9 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-981];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet034-reviewed30'/f'khu-{campus}-2026-2.packet034-physical-groups-prepared.json'));(P/f'packet035-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside035'}

 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet035-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet035-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2891,'baselineDates':54074,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2891+len(selected),'totalDates':54074+count})
