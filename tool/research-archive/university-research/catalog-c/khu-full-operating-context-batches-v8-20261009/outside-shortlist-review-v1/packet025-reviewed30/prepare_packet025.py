# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet025-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={702: [(2, 720, 885, '호501')], 703: [(2, 900, 1065, '호303')], 704: [(5, 720, 885, '호303')], 705: [(3, 900, 1065, '호603')], 709: [(2, 810, 885, '호602'), (4, 810, 885, '호401')], 710: [(2, 990, 1065, '호402'), (4, 990, 1065, '호402')]}
weeks={702: [1, 2, 3, 4, 5, 6, 7, 9, 10, 12, 13, 14], 703: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 704: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 705: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 709: [1, 2, 3, 4, 5, 7, 9, 10, 11, 12, 13, 14, 15], 710: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15]}
reasons={681: '김예슬 자체 현재 개인피아노 교육·전체16주와13–15주 클래스연주/16주평가 확인. 개별 절대요일 시작종료 시각 미공표 보류.', 682: '김예슬 자체 현재 개인피아노 교육·전체16주와13–15주 클래스연주/16주평가 확인. 개별 절대요일 시작종료 시각 미공표 보류.', 683: '김예슬 자체 현재 개인피아노 교육·전체16주와13–15주 클래스연주/16주평가 확인. 개별 절대요일 시작종료 시각 미공표 보류.', 684: '이선미 자체1:1실기 전체운영·주차 확인.13주 녹화자기비평은 과제이지 VOD수업대체 아님.15주평가16주피드백 보존, 개인배정HH미공표.', 685: '이선미 자체1:1실기 전체운영·주차 확인.13주 녹화자기비평은 과제이지 VOD수업대체 아님.15주평가16주피드백 보존, 개인배정HH미공표.', 686: '임기욱 개인 피아노 레퍼토리 전체원문과15주평가 확인. 개인 수업 절대HH없어 보류.', 687: '임기욱 개인 피아노 레퍼토리 전체원문과15주평가 확인. 개인 수업 절대HH없어 보류.', 688: '최지원 해당학부피아노 개별교육·현재교수·16주 원문 확인.688발표100%/689실기100% 원문 차이 보존. 절대 개인배정시각 미확인.', 689: '최지원 해당학부피아노 개별교육·현재교수·16주 원문 확인.688발표100%/689실기100% 원문 차이 보존. 절대 개인배정시각 미확인.', 690: '최소영 현재 개별피아노 레퍼토리·15주반복16주평가 전체원문 확인. 과목별 다른 교재/작품 그대로, 절대HH미공표.', 691: '최소영 현재 개별피아노 레퍼토리·15주반복16주평가 전체원문 확인. 과목별 다른 교재/작품 그대로, 절대HH미공표.', 692: '육민경 개인1:1·13주모의연주15주보강16주평가 전체확인.6921:1/693운영추가공란 원문 차이 보존. 실제 개인배정HH미확인.', 693: '육민경 개인1:1·13주모의연주15주보강16주평가 전체확인.6921:1/693운영추가공란 원문 차이 보존. 실제 개인배정HH미확인.', 694: '육민경 개인1:1·13주모의연주15주보강16주평가 전체확인.6921:1/693운영추가공란 원문 차이 보존. 실제 개인배정HH미확인.', 695: '김유빈 일주일1시간개인대면·8주연주15주평가16주리뷰 전체확인.1시간길이로 시작시각 추정하지 않음, 실제HH미공표.', 696: '김유빈 일주일1시간개인대면·8주연주15주평가16주리뷰 전체확인.1시간길이로 시작시각 추정하지 않음, 실제HH미공표.', 697: '노예나 해당개별1:1 수업16주 자체계획 전체읽음. 개별학생 시작종료HH 미공표, 같은교수 다른분반 차용 금지.', 698: '노예나 해당개별1:1 수업16주 자체계획 전체읽음. 개별학생 시작종료HH 미공표, 같은교수 다른분반 차용 금지.', 699: '노예나 해당개별1:1 수업16주 자체계획 전체읽음. 개별학생 시작종료HH 미공표, 같은교수 다른분반 차용 금지.', 700: '노예나 해당개별1:1 수업16주 자체계획 전체읽음. 개별학생 시작종료HH 미공표, 같은교수 다른분반 차용 금지.', 701: '박주영 개별 집중레슨은 교육방법이지 집중학기기간 명시 아님. 학부현재native 및 본문 학부/대학원 표현 전체보존. 개인HH미공표.', 702: '두교수 현재2026-2 자체코드·서울·화12:00–14:45호501 모두일치 및 대면기본.8주 Online Lecture live/VOD 미확정,11중간15기말16공란 제외. 확정 정상12회만 부분후보.', 703: '두교수 현재 자체서울 화15:00–17:45호303 일치·대면원칙.8중간대체과제15기말16기말/공란 제외. 정상13회만 부분후보, 과제는 시험예약으로 만들지 않음.', 704: '자체 금12:00–14:45호303 대면참여수업.8주보고서중간16주기말기간 발표 제외 및9/25·10/9휴일 제외. 정상12회 부분후보. 자료실을 원격수업으로 오해하지 않음.', 705: '자체 수15:00–17:45호603 실시간 대면강의 명시.8중간15휴보강시각미정16기말 제외 정상13회. 조건부온라인·가능현장은 확정운영으로 만들지 않음.', 706: '0학점 졸업논문/P/N/졸업예정자필수와 원문 운영·주차 전체공란 보존. HH미공표 보류.', 707: 'native 목13:30–16:15호707은 창구이나 실제매주30–60분 사전합의 개별회의. 실제개인배정HH불명으로 창구전체를 수업으로 예약하지 않음.', 708: '현재전체영어 대면 강의·2026 literal 날짜계획 읽음. 명시 tentative calendar/Week1 final calendar 게시예정의 최종우선원문미확인으로 보류. 휴강·TBD·시험·영어이수제한 전체보존.', 709: '자체서울 화13:30–14:45호602/목13:30–14:45호401 대면기본.6주No class Oct7&9와 native화목요일 상충으로 전체6주제외,8중간16기말 제외 정상25회. 교수대학원소속을 학부개설scope로 오해하지 않음.', 710: '자체 화목16:30–17:45호402 in-class 강의·토론.8중간9명시현장답사 장소시간미정16기말기간보고서 제외 정상25회. 이력서/채용토픽은 외부운영기간 아님.'}
allowedWeekdays={};exceptDates={};examExceptions={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
allowedNativeGroups={}
calendarPlan={}
assert len(HH)==6 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-681];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet018-reviewed30'/f'khu-{campus}-2026-2.packet018-physical-groups-prepared.json'));(P/f'packet025-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside025'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet025-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet025-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2762,'baselineDates':51762,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2762+len(selected),'totalDates':51762+count})
