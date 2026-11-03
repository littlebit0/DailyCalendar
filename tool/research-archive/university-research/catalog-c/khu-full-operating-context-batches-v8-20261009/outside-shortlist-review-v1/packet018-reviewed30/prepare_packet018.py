# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet018-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={493: [(5, 660, 770, '음B102')]}
weeks={493: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
allowedWeekdays={};exceptDates={};examExceptions={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
allowedNativeGroups={}
calendarPlan={493:0}
reasons={471: '자체현재분반전체원문과맞춤개인성악교육 확인. 절대요일HH없음보류, 이전같은교수분반과통합하지않음.', 472: '자체1:1성악레슨 전체주차/평가/과제실제읽음. 녹음/연습영상 제출은자료·과제이지수업대체아님. 절대HH미공표 보류.', 473: '별도현재성악분반 전체교육 자체확인,각자1:1clock미공표 보류.', 474: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 475: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 476: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 477: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 478: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 479: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 480: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 481: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 482: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 483: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 484: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 485: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 486: '자체 대면 논문지도16주 whole원문 실제확인.0학점/졸업예정자제한 유지하고 원문null date문자열도보존.절대HH없는논문지도보류.', 487: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 488: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 489: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 490: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 491: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 492: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 493: '기본대면수업 명시 및 휴일보강 필요시에만동영상강의.원문금11–12:50 음B102정상1–7/9–15주12회,9/25·10/9학교휴일8중간16기말제외. 영상보강시각생성0.', 494: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 495: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 496: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 497: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 498: '자체1:1작곡레슨 전체운영·주차/작품제출평가실제읽음.현장강의방법선택 있어도 개별주차절대요일HH미공표 보류.', 499: '현재 자체코드/교수 whole원문을 실제읽음. 교육·운영·주차 및 기본clock 공란. 현재개설metadata만으로개인작곡레슨시각생성0. 다른분반/같은교수HH차용0.', 500: '자체일주일1번30분대면과하프실236확인. HH절대시작종료요일미공표이므로30분길이/236호를clock으로추정0;유튜브참고는자료.'}
assert len(HH)==1 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-471];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet017-reviewed30'/f'khu-{campus}-2026-2.packet017-physical-groups-prepared.json'));(P/f'packet018-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside018'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet018-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet018-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2761,'baselineDates':51750,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2761+len(selected),'totalDates':51750+count})
