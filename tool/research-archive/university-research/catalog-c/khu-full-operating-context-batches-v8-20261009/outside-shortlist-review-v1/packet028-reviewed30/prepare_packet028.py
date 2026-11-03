# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet028-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={774: [(1, 900, 975, '문305'), (3, 900, 975, '문305')], 775: [(1, 630, 705, '문302'), (3, 630, 705, '문302')], 776: [(1, 810, 885, '오308'), (3, 810, 885, '오308')], 777: [(5, 720, 885, '오308')], 782: [(2, 540, 615, '오308'), (4, 540, 615, '오308')], 783: [(2, 630, 705, '오308'), (4, 630, 705, '오308')], 785: [(2, 900, 975, '오306'), (4, 900, 975, '오306')], 786: [(5, 720, 885, '오213')], 787: [(2, 990, 1065, '오422'), (4, 990, 1065, '오422')], 789: [(1, 720, 795, '오211'), (3, 720, 795, '오211'), (1, 720, 795, '오211')], 790: [(1, 810, 885, '오211'), (3, 810, 885, '오211'), (1, 810, 885, '오211')], 791: [(1, 900, 975, '오306'), (3, 900, 975, '오306')], 792: [(2, 900, 975, '오209'), (4, 900, 975, '오209')], 794: [(5, 720, 885, '오309')]}
weeks={774: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 775: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 776: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 777: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 782: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 783: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 785: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 786: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 787: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 789: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 790: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 791: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 792: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 794: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}
reasons={774: '자체박슬기fullplan가박슬기·심록모두월수15–16:15문305와whole대면원칙을직접명시.심록별도plan공란전체보존/반대근거없음.8/16시험휴일제외.', 775: '자체 월수10:30–11:45문302 Face-to-face,휴강시녹화대체조건부.15if-neededmakeup8/16시험10/5휴일제외.', 776: '자체 월수13:30–14:45오308 대면기본원칙,8시험/overview16시험휴일제외.부정행위/타과수강제한전체보존.', 777: '자체 금12–14:45오308 대면수업진행명시.교수대학원소속을본학부강좌scope와혼동0.8/16시험·학교휴일제외.', 782: '자체 화목09–10:15오308 대면원칙/어려운경우에만원격보완.8/16시험·휴일제외.9/8지정좌석·첫수업9/1자체운영·필수선수보존.', 783: '자체 화목10:30–11:45오308 대면원칙/필요시녹화보완.8/16시험·휴일제외.회계선수내용과고급회계강좌혼합0.', 785: '자체 화목15–16:15오306 대면원칙.실제시험10/22및12/10야간20:30–21:50는정규HH와분리원문보존하고예약생성0.8/15시험16보강휴일제외.', 786: '자체 금12–14:45오213 대면원칙/휴강보강만원격.8/16시험휴일제외.전공선수권고와실제운영구분보존.', 787: '자체 화목16:30–17:45오422 대면원칙/공휴일결강만비대면콘텐츠보강.8/16시험휴일제외.교재PPT/e-campus자료배포는실제온라인배정아님.', 789: '자체양교수wholeplan동일오프라인수업/각주오프라인명시.사전녹화주간학습은실제대면참석전준비자료이고HH생성0.팀티칭월12–13:15오211두교수원문중복은동일meeting1회만,수동일13:15종료.8/15시험16공란제외.', 790: '자체양교수wholeplan동일오프라인수업/각주오프라인명시.사전녹화는주간자율준비자료.팀티칭월13:30–14:45오211중복동일meeting1회·수동일HH.00분반시각차용0.8/15시험16공란제외.', 791: '자체 월수15–16:15오306 대면원칙및각정규주대면명시.학교e-campusQuiz는실제수업중평가도구이며녹화수업아님.8/16tentative시험배정제외.', 792: '자체 화목15–16:15오209 각정규주대면명시.일부평가중간2회vs기타총2회상충원문보존하고시험추가시각·날짜생성0.8/16시험제외.', 794: '자체 금12–14:45오309 대면원칙/휴일에만live가능조건부.15보강8/16시험휴일제외.영상미디어학습주제는실제원격배정아님.', 779: '자체독립논문지도프로젝트/허락필수,일20–20:05창구가실제whole개별배정인지미확인.임의수업길이생성0.', 780: '자체대면단어/프로젝트주차있으나일22–22:05등록창구가3학점프로젝트whole운영인지미확인.5분을무조건가짜라판단하거나늘리지않고보류.', 781: '자체학생자율연구·독립소통·피드백.일21–21:05창구와개별연구모임whole배정일치미확인보류.', 788: '자체캡스톤프로젝트/교수허락필수·실제운영날짜별미확인.토09–09:05창구를whole수업으로전파0.', 793: '자체Zoomlive명시하지만native금09–11:45vs안내Zoom모일때09–11:30종료상충.모임개별배정도미공표;끝시각하나선택0.', 795: '자체PPT이론토론·nativeHH있으나선택온라인열의dated대면/live/VOD배정불명.학기시험날짜정규토픽은모드확정으로전파0.', 796: '자체PPT강의토론·nativeHH있으나별도온라인선택배정미확인.다른분반모드차용0.', 797: '실제혼합운영/live/영상발표·개인Zoom면담배정미정.별도질의응답자체literal9/14·21·28,10/7,11/4·9의강의실대면부분가능성은후속좁은후보검토대상으로기록,이번whole정규예약0.', 798: '자체매주연구실orZoom개인모임구체적시간추후공지.토10–10:05창구를전체대면으로가정0.', 799: '자체이론40/실습50/현장10및5/13본사방문·4매장관찰명시,대면/live별도열배정불명.교실하나로현장방문/개별프로젝트whole시간추정0.', 771: '자체현재0학점졸업논문·지도/교수/졸업제한확인,actualwhole배정HH미공표또는등록5분창구뿐.본문원문보존/다른논문clock차용0.', 772: '자체현재0학점졸업논문·지도/교수/졸업제한확인,actualwhole배정HH미공표또는등록5분창구뿐.본문원문보존/다른논문clock차용0.', 773: '자체현재0학점졸업논문·지도/교수/졸업제한확인,actualwhole배정HH미공표또는등록5분창구뿐.본문원문보존/다른논문clock차용0.', 778: '자체현재0학점졸업논문·지도/교수/졸업제한확인,actualwhole배정HH미공표또는등록5분창구뿐.본문원문보존/다른논문clock차용0.', 784: '자체현재0학점졸업논문·지도/교수/졸업제한확인,actualwhole배정HH미공표또는등록5분창구뿐.본문원문보존/다른논문clock차용0.', 800: '자체현재0학점졸업논문·지도/교수/졸업제한확인,actualwhole배정HH미공표또는등록5분창구뿐.본문원문보존/다른논문clock차용0.'}
allowedWeekdays={};exceptDates={};examExceptions={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
allowedNativeGroups={789:[0,1],790:[0,1]}
calendarPlan={774:1}
assert len(HH)==14 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-771];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
   day=a
   while day<=b:
    if day.isoweekday()==wd and permitted(day):meetings.append({'date':day.isoformat(),'weekday':wd,'startMinute':int(m[2])*60+int(m[3]),'endMinute':int(m[4])*60+int(m[5]),'classroom':actualRoom(r,m[6].strip())})
    day+=dt.timedelta(days=1)
 for a,b,r in spans:
  for ni,(wd,st,en,room) in enumerate(HH[n]):
   if n in allowedNativeGroups and ni not in allowedNativeGroups[n]:continue
   if n in allowedWeekdays and wd not in allowedWeekdays[n]:continue
   day=a+dt.timedelta(days=(wd-a.isoweekday())%7)
   while day<=b:
    if permitted(day):independent.append((day.isoformat(),wd,st,en,actualRoom(r,room)))
    day+=dt.timedelta(days=7)
 assert len(set(independent))==len(meetings);assert set(independent)=={(r['date'],r['weekday'],r['startMinute'],r['endMinute'],r['classroom']) for r in meetings}
 selected[c['sourceId']]=meetings;count+=len(meetings)
 proof.append({'packetOrdinal':n,'sourceId':c['sourceId'],'wholePlans':plans,'nativeClock':c['sourceSchedule'],'ownCampus':plans[0]['campus'],'literalNativeHH':HH[n],'allowedPhysicalWeeksLiteral':ws,'physicalRowsLiteral':[r for a,b,r in spans],'semanticReason':reasons[n],'explicitUnscheduledDatesLiteral':sorted(exceptDates.get(n,set())),'independentDates':sorted({k[0] for k in independent}),'literalIndependentMeetings':[list(k) for k in sorted(independent)],'ownExamNormalExceptionsLiteral':sorted(examExceptions.get(n,set())),'ownHolidayNormalExceptionsLiteral':sorted(holidayExceptions.get(n,set())),'ownExplicitDatesLiteral':sorted(explicitDates.get(n,set())),'ownRoomOverridesLiteral':roomOverride.get(n,{}),'roomUnconfirmedWeekdaysLiteral':sorted(roomUnconfirmedWeekdays.get(n,set())),'allowedWeekdaysLiteral':sorted(allowedWeekdays.get(n,set())),'allowedNativeGroupsLiteral':sorted(allowedNativeGroups.get(n,set(range(len(native))))),'calendarPlanIndex':calendarPlan.get(n,0),'newDateCount':len(meetings),'previousResearchDepartmentRemarks':c['departmentRemarks'],'remoteHoursGenerated':0})
for campus in ['seoul','global']:
 old=json.load(open(P.parent/'packet027-reviewed30'/f'khu-{campus}-2026-2.packet027-physical-groups-prepared.json'));(P/f'packet028-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside028'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet028-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet028-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2794,'baselineDates':52246,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2794+len(selected),'totalDates':52246+count})
