# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet031-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={863: [(1, 900, 1010, '스B211'), (1, 630, 705, '스B110(계단)'), (3, 630, 705, '스B110(계단)')], 865: [(5, 900, 1010, '스B120'), (2, 900, 975, '스B114(계단)'), (4, 900, 975, '스B114(계단)'), (5, 900, 1010, '스B120'), (2, 900, 975, '스B114(계단)'), (4, 900, 975, '스B114(계단)')], 867: [(5, 540, 705, '스B114(계단)'), (2, 540, 650, '스B245')], 868: [(2, 810, 885, '스B104'), (4, 810, 885, '스B104')], 870: [(4, 540, 650, '스B211'), (1, 630, 705, '스B110(계단)'), (3, 630, 705, '스B110(계단)')], 876: [(2, 900, 975, '스B112'), (4, 900, 975, '스B112')], 890: [(1, 630, 705, '스B210-2'), (3, 630, 705, '스B210-2')]}
weeks={863: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 865: [11, 12, 13, 14, 15], 867: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 868: [1, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 870: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], 876: [1, 2, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 890: [1, 2, 3, 4, 6, 7, 9, 12, 15]}
reasons={861: '個별두연구실6주배정·필수목16:30컬로퀴엄참석이있으나종료HH미공표/개별연구요일시각미배정.시작시각만으로끝시각생성0.', 862: '자체출석평가가이론비실시간강의명시이며프로그래밍프로젝트주제만으로월수실시간/대면HH확정0.날짜별배정없는운영전체held.', 863: '정민석이론/실험모두대면과양지은실험대면은자체현재분반01모든HH/주차일치.월lab15–16:50월수theory10:30–11:45 정규주만;물리학과외수강제한보존.', 864: '실제외부행사·장비현장활동이주차변동/미확정타임라인으로사후공지예정.주제만으로정규전체현장날짜·위치고정하지않으며별도대면normalallocation검증pending.', 865: '김은영lab자체대면원칙 금15–16:50스B120의11–15주발생관찰/전기영동/분석만.생태실외배정1–10주·박영석전반기비대면·한창석혼합theoryheld.중복원문6전체보존/동일labgroup1개만.', 866: '실제이론동영상또는현장강의와마이크로티칭프로세스는있지만현재주차별고정대면/live/녹화모드배정미공표.중등수학교육주제나20분micro설명으로운영HH생성0.', 867: '정의헌자체세미나실험대면인화09–10:50스B245만.원창연theory명시대면모드공란held.8주이론시험과labRLC세미나를구분하여10/20화lab만정규예외.', 868: '기존correction현재공개wholeplan명시대면수업으로온라인열만blankethold교정.4주Sep9ThursdayHolyday와2026요일/기간상충은원문보존하며2/4주모두held.전산실B123병행원문과스B104배정미확정은각room을선택하지않고classroom빈값;학교원문둘다유지.', 870: '현분반00정민석theory명시대면정규1–7/9–15,Walkerlab대면1–8/10–16 교수별그룹적용.8labElectrochemistry10/22·16CourseReview12/17만자체정규예외,다른그룹시험기간전파0.', 873: '기본온라인진행·프로젝트실험필요시대면이라는실제혼합운영,일요일HH에실시간배정미확인held.공란room만으로배제한것아님.', 874: '추가설명주1회이상대면실험협의와수업안내기본온라인/필요시대면의실제배정상충.토15–17:50에어느모드가적용되는지불명held.', 876: '기존currentOperatingCorrection 공개wholeplan추가설명대면수업으로온라인열만보류교정.자체추석주4/시험8/16제외 화목15–16:15스B112 정상현재계획만,원문이수제한/동일과목명보존.', 877: '실제현재강의계획교육/운영/주차대부분공란.원강희수21–23:50만으로개별캡스톤모드배정추정0.', 878: '원강희화21–23:50고정표기있으나원문운영및교육내용공란.다른분반시간/모드/room차용0.', 889: '실제4주드론현장자료취득·공간정보PBL 프로젝트운영전체확인.선택온라인열없음만으로mode나현장위치/고정HH운영확정0.실내/현장공간배정currentown근거pending.', 890: '자체대면진행원칙에도5/10/11주온라인항목요일·live/VOD미특정wholeweekheld.13/14FAST방법미확인held.정규남은1–4/6/7/9/12/15만,명시9/2·12/9휴강제외.이수/영어자료원문보존.', 869: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.', 871: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.', 872: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.', 875: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.', 879: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.', 880: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.', 881: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.', 882: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.', 883: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.', 884: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.', 885: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.', 886: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.', 887: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.', 888: '자체졸업논문/독립연구전체교육/운영확인,요일절대시작/종료HH미공표.매일/매주연구문구만으로clock생성0.'}
allowedWeekdays={};exceptDates={890:{'2026-09-02','2026-12-09'}};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={868:{2,4}}
examExceptions={867:{'2026-10-20'},870:{'2026-10-22','2026-12-17'}}
allowedNativeGroups={865: [0], 867: [1]}
calendarPlan={865: 0, 867: 1}
groupWeeks={870: {0: [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 2: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}}
assert len(HH)==7 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-861];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet030b-own-group-specific-normal'/f'khu-{campus}-2026-2.packet030b-physical-groups-prepared.json'));(P/f'packet031-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside031'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet031-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet031-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2843,'baselineDates':53328,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2843+len(selected),'totalDates':53328+count})
