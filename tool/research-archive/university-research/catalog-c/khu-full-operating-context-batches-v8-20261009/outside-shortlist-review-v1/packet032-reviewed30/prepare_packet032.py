# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet032-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={891: [(1, 900, 975, '스B210-2'), (3, 900, 975, '스B210-2')], 896: [(2, 990, 1100, '스111(세미나실)'), (4, 990, 1100, '스111(세미나실)')], 904: [(2, 630, 705, '스B210-2'), (4, 630, 705, '스B210-2')], 905: [(2, 810, 920, '스124')], 906: [(2, 930, 1040, '스124')]}
weeks={891: [1, 2, 3, 4, 6, 7, 9, 14, 15], 896: [1, 2, 3, 4, 6, 7, 15], 904: [1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14], 905: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 906: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
reasons={891: '자체 대면 원칙 및 월수15–16:15, 온라인5/10/11주 요일·live/VOD배정 불명 wholeheld, FAST12/13 실제 방식 미확인 held. 9/2·12/14 명시휴강 제외; 열린연구실 선택Q&A는 출석수업으로 생성하지 않음.', 892: '졸업논문 개별 지도, 요일 시작/종료HH 없음.', 893: '독립현장인터뷰·연구는 명시대면이지만 HH미공표.', 894: '독립도시현장연구, 명시대면이나 HH미공표.', 895: '학기전활동·1/2주 집중이동·시간변경신청 예정·팀별면담·독일온라인 및 유동전체운영. 현재배정된개인날짜/시각미확인.', 896: '자체 대면 원칙과 화목16:30–18:20 중 정규1–4/6/7/15주만. 확률90% 독일공동5주·8주준비·10–14개별과제·10/29–30답사HH미공표는 예약하지 않음.', 897: '교수법·모의수업·전문가주제만으로 실제대면/live배정확정 불가, 원문모드날짜미확인.', 898: '8/12주비동기명시, 다른주차모의수업·전문가주제만으로대면전체추정0.', 904: 'Remote Sensing은교육주제이며 자체 in-person lectures and labs 기본명시.4주온라인혼합·12프로젝트준비·15Studyweek·8/16시험held.정규확정나머지wholegroup만.', 905: '박승준 명시대면 및 김연정 실시간대면·일부플립러닝 current own화13:30–15:20 일치, normal1–7/9–15주만.교수별약물주제순서차이와실제운영시간충돌구분.', 906: '현분반01 자체두교수대면/실시간대면 화15:30–17:20, 정규1–7/9–15주만, 다른분반시각차용0.', 907: '병원임상·차수별2주·1일9시간 운영, 개인실습차수 실제기간 미공표.16주주제표를학기전체실습으로추정0.', 908: '성인임상실습 본교과목1주간과 병원배정, 실제학생별1주기간미공표.첫째날/둘째날학습을주간반복으로만들지않음.', 909: '종합임상실습1–5일내용/배정병동·스케줄사후OT, HH미공표.', 910: '정신임상현장·시뮬레이션·추후ZoomOT배정, 일반강의실slot과현장전체개인기간 미확인.', 911: '정신의학과1주+복지센터1주현장운영, 실제차수기간없고ZoomOT추후공지.', 912: '보건소/방문간호현장배정 및 임상평가, 교내일반slot과실습지운영연결·개별기간미확인.', 913: '임상현장·가정방문실습, 현장지도배정시기미확인.대변오타를대면으로자의교정0.', 914: '대변수업위주 원문과온라인강의별도선택/방식상황변경, 실제대면/live배정현재불명.오타교정으로과거held철회0.', 915: '현재원문01동일 대변수업위주/온라인강의 및방식미정, 원문오타선택교정0.', 916: '대면위주이나온라인강의별도선택 및현장학습10% 운영, 해당주차의비대면/현장그룹배정명시없이전체대면으로단정0.8주발표·10주중간고사구분보존.', 917: '운영추가설명공란 및온라인강의별도선택/현장10%, 다른분반대면문구차용0;주차별배정미확인.', 918: '여성임상실습3주·교내외혼합·실습1주전스케줄공지, 개인차수날짜및해당groupHH배정미공표.', 919: '현재헤더2026-2이지만교육원문2021과제마감/COVID비대면→대면변경조건이대면추가설명과공존.운영상충미해결이므로기존held유지/과제날짜를2026으로변환0.', 920: '현재분반02도2021과제/COVID비대면조건·대면추가설명공존, current운영우선근거미확인held유지.', 899: '독립연구 개별1:1면담 실제있으나 시작·종료HH미공표.연구주제를weeklyclock으로생성0.', 900: '독립연구 개별1:1면담 실제있으나 시작·종료HH미공표.연구주제를weeklyclock으로생성0.', 901: '독립연구 개별1:1면담 실제있으나 시작·종료HH미공표.연구주제를weeklyclock으로생성0.', 902: '독립연구 개별1:1면담 실제있으나 시작·종료HH미공표.연구주제를weeklyclock으로생성0.', 903: '독립연구 개별1:1면담 실제있으나 시작·종료HH미공표.연구주제를weeklyclock으로생성0.'}
allowedWeekdays={};exceptDates={891:{'2026-09-02','2026-12-14'}};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={};examExceptions={};allowedNativeGroups={};calendarPlan={};groupWeeks={}
assert len(HH)==5 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-891];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet031-reviewed30'/f'khu-{campus}-2026-2.packet031-physical-groups-prepared.json'));(P/f'packet032-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside032'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet032-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet032-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2850,'baselineDates':53495,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2850+len(selected),'totalDates':53495+count})
