# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet027-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={741: [(6, 960, 1125, '호303')], 742: [(1, 630, 705, '호303'), (3, 630, 705, '호303')], 743: [(3, 720, 885, '호501')], 744: [(5, 540, 705, '호302')], 745: [(4, 810, 975, '호703')], 748: [(2, 720, 795, '문308'), (4, 720, 795, '문308')], 749: [(2, 900, 975, '문308'), (4, 900, 975, '문308')], 750: [(2, 540, 615, '문308'), (4, 540, 615, '문308')], 766: [(1, 810, 885, '문401'), (3, 810, 885, '문401')]}
weeks={741: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 742: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 743: [1, 2, 3, 4, 5, 6], 744: [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], 745: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 748: [1, 2, 3, 4, 5, 7, 9, 10, 13, 14, 15], 749: [1, 2, 3, 4, 5, 6, 7, 9, 10, 13, 14, 15], 750: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 766: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
reasons={741: '자체 토16–18:45호303 대면이론·사례토론 기본,공휴일에만원격대체조건부.8/16시험·학교휴일제외.외부전문가특강별도HH 생성0;전공·학년제한보존.', 742: '자체 월수10:30–11:45호303 대면중심/외부행사시원격조건부.15실제시험16공란8시험제외.10/5휴일제외.', 743: '자체 수12–14:45호501 기본대면의1–6주만.7날씨에따라야외,9–14개인발표대면/영상병행의실제배정불명,15보강미정8/16시험보류.자료영상시청을실제원격수업으로전파0.', 744: '자체 금09–11:45호302 명시Offline class/토론.4추석6박물관현장제외.8Signs and Signifying Practice 강의10/23,16Project Presentations12/18 자체정규예외.과제마감23:59를HH로생성0.', 745: '자체 목13:30–16:15호703 대면/행사휴일만원격대체조건부.4추석8/16시험제외.전체학년·수강제한보존.', 748: '자체 화목12–13:15문308 대면원칙.6본문10/7화·10/9목은2026요일상충으로전체제외.11주기간과본문11/17·19원격날짜상충11/12모두제외.8/16시험·학교휴일제외.', 749: '자체 화목15–16:15문308 대면원칙.11주기간과본문11/17·19원격날짜상충11/12모두제외.8/16시험·학교휴일제외.', 750: '자체 화목09–10:15문308 대면원칙/휴일원격조건부.8시험/원격review15시험/원격review16공란제외.이전국어학강독수강제한·AI안내보존.', 751: '자체독립심화교수/토native범위만확인;교육운영주차공란이라실제배정미확인보류.', 752: '자체1:1feedback/독립프로젝트,공개토요일창구가개인전체배정과동일근거없음보류.', 753: '기존currentOperatingCorrection의캐시386655bf6edd584c144a 전체교육20섹션추가읽음.운영공란/추가설명점/별도온라인선택의날짜별배정미확인,기존정정보존.', 754: '자체교수학생협의대면or원격독립연구,날짜별개인배정미확인보류.', 756: '자체독립연구/정기지도교수모임의개별HH미배정,토native창구를전체모임으로추정0.', 757: '자체0학점졸업논문교수·교육·집필주차확인,자체절대HH없음보류.', 758: '자체독립연구/해외박물관·유적현장답사실제배정기간/HH미확인보류.참고자료raw문자보존.', 759: '자체김승래월요일plan과native월수공동교수요일범위불일치.온라인비대면실습vs대면orVOD+주1회대면 상충.요일·모드선택금지보류.', 760: '자체한진성월요일plan과native월수공동교수별배정불명.10월박물관/11월초중답사실제협의기간미정,학기전체대면창구로추정0.', 761: '자체홍은경화요일plan과native화목공동교수별배정불명.현장학습배정날짜미확인,목요일타교수clock차용0.', 762: '자체졸업철학0학점교수·코드·집필내용확인,주차/HH공란보류.', 763: '자체독립철학대면+Zoom병행/남은주차공란.명시Zoom을VOD라하지않고날짜별실시간배정미확인보류.', 764: '자체독립철학정기모임+개인학습,안내화요일교수만남vsnative토요일불일치.토요일매주실제모임으로추정0.', 765: '자체독립철학2정기모임+학생독립학습,화요일교수만남vsnative토12–14:45불일치.분반자체배정확정불가보류.', 766: '자체 월수13:30–14:45문401 All classes in-person,휴일만recorded.8/16시험·10/5휴일제외.영어강의/두퀴즈/문화영상은자료보존.', 767: '자체개인독립창업프로젝트/도서웹DB업데이트활동.운영설명은산출물전략이고금요일whole동기수업배정명시없음보류.', 768: '자체졸업논문0학점/개별지도·학과제출,HH미공표.제출일을수업시각생성0.', 769: '자체졸업논문통번역0학점/개별지도·제출,HH미공표.다른분반clock차용0.', 770: '자체운영방식공란과별도선택온라인강의만으로dated대면/live/VOD배정미확인.대면토론교재방법만으로배정추정0.', 746: '현재졸업필수0학점·교수미정·clock정만확인.공개wholeplan0이므로실제교육원문읽은수로세지않음;전체졸업/편제제한보존.', 747: '현재졸업필수0학점·교수미정·clock정만확인.공개wholeplan0이므로실제교육원문읽은수로세지않음;전체졸업/편제제한보존.', 755: '현재졸업필수0학점·교수미정·clock정만확인.공개wholeplan0이므로실제교육원문읽은수로세지않음;전체졸업/편제제한보존.'}
allowedWeekdays={};exceptDates={};examExceptions={744:{'2026-10-23','2026-12-18'}};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
allowedNativeGroups={}
calendarPlan={}
assert len(HH)==9 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-741];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet026-reviewed30'/f'khu-{campus}-2026-2.packet026-physical-groups-prepared.json'));(P/f'packet027-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside027'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet027-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet027-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2785,'baselineDates':52080,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2785+len(selected),'totalDates':52080+count})
