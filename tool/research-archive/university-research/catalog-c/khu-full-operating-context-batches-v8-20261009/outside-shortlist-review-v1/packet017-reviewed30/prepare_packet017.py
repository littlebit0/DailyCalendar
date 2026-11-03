# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet017-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={451: [(4, 600, 710, '오페라실')]}
weeks={451: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
allowedWeekdays={};exceptDates={};examExceptions={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
allowedNativeGroups={}
calendarPlan={451:0}
reasons={441: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 442: '졸업논문대체 리사이틀 프로그램 연구 자체원문이지만 절대HH 미공표.0학점 및 졸업예정자 제한 보존,논문제목만으로 제외아님.', 443: '일반강의와발표/실기여도 실제온라인강의방법 선택,전체대면/실시간 배정 명시없음.8주동영상중간9주중간일정조정 원문 보존.과제4/14·5/26과현재학기주차상충 값을 선택수정하지않음.', 444: '시청각자료 및 일반강의실습 설명과 별도로 실제온라인강의방법 선택. 자체 화15–16:50창은보존하되물리적/실시간전체배정미확정 보류.다른교수mode차용0.', 445: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 446: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 447: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 448: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 449: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 450: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 451: '자체 이 수업은 대면 수업,실기 수업 명시.목10–11:50 오페라실 정상1–7/9–15주13회(9/24학교공휴일 제외).9주플립러닝 즉흥연주/보이스앙상블은 명시대면수업 내활동으로원문보존,영상대체시각생성0.8중간16기말제외.개인10분수업이아니라전체클래스내10–15분워밍업임.', 452: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 453: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 454: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 455: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 456: '현재학부nativecode/campus와원문대학원생표현 모두그대로보존.1:1대면이나HH미공표로보류,본문단어만으로학부원객체제거0.', 457: '별도학부nativecode/전체원문직접읽음.동일대학원생표현원문보존하고개인레슨HH미공표보류.타분반정체성join0.', 458: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 459: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 460: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 461: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 462: '자체50분1:1대면 실기와비대면일지체크 구분.시작종료HH미공표로보류,50분길이만으로clock생성0.', 463: '독립현재분반전체원문읽음.50분레슨과일지체크가동일해도자체절대clock없음.', 464: '독립현재분반전체원문읽음.레슨50분기간은절대HH아님,일지과제와원문안내구분보존.', 465: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 466: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 467: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 468: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 469: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.', 470: '현재 해당 분반 전체교육/주차/운영 실제확인. 개인 성악 실기 또는 논문지도이나 자체 절대요일과 시작종료HH 미공표 보류. 다른분반 clock/곡목/시험/매주라는문구로 시각 생성0.'}
assert len(HH)==1 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-441];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet016-reviewed30'/f'khu-{campus}-2026-2.packet016-physical-groups-prepared.json'));(P/f'packet017-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside017'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet017-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet017-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2760,'baselineDates':51737,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2760+len(selected),'totalDates':51737+count})
