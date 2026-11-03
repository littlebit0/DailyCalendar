# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet004-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={56: [(2, 630, 705, '정402'), (4, 630, 705, '정402')], 57: [(2, 900, 975, '정402'), (4, 900, 975, '정402')], 58: [(3, 720, 885, '정406')], 59: [(1, 900, 975, '정305'), (3, 900, 975, '정305')], 60: [(2, 630, 705, '정404'), (4, 630, 705, '정404')], 61: [(2, 810, 885, '정404'), (4, 810, 885, '정404')], 64: [(5, 540, 705, '정304')], 65: [(5, 720, 885, '정304')], 68: [(5, 810, 975, '정310')], 70: [(2, 630, 705, '정401'), (4, 630, 705, '정401')], 72: [(5, 900, 1065, '정402')], 73: [(2, 900, 975, '생507'), (4, 900, 975, '생507')], 77: [(3, 540, 770, '생501')], 80: [(1, 810, 885, '생501'), (3, 810, 885, '생501')]}
weeks={56: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 57: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 58: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 59: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 60: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 61: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15], 64: [1, 2, 5, 9, 10, 11, 13, 16], 65: [1, 2, 3, 5, 9, 10, 11, 12, 15, 16], 68: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 70: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 13, 14, 15], 72: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 73: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 15], 77: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 15], 80: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}
allowedWeekdays={80:{1}};exceptDates={};examExceptions={64:{'2026-12-18'},65:{'2026-12-18'}};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
reasons={51: 'Held: own online checkbox, no explicit whole physical/live allocation. News production is assignment/prerequisite not field-operation proof.', 52: 'Held: weekly team meetings without own absolute HH;24/7 PC requirement not course clock.', 53: 'Held: empty plan/no HH;8-semester graduation eligibility not class period.', 54: 'Held: physical default with definite resolution-specific Zoom topics not allocated; Sept15 guest16–17:45 covers only guest portion, no whole15–17:45 allocation; Dec8 screening actual library place could require own room proof.', 55: 'Held: explicit whole physical with preclass contents but own grading attendance specifically GoogleClassroom lecture-listening/Webex, actual allocation conflict unresolved. Source not silently repaired.', 56: 'Physical default all current weeks, preclass movie viewing auxiliary; future-needed remote not actual replacement.8/16exam held.', 57: 'Physical default all current weeks. Project script preparation and media topics not actual private operating dates; future-needed remote only.8mid16examperiod conservatively held.', 58: 'Physical default with possible future special/team online; actual expert5/13 not a field allocation, team mentoring part of normal class;8/16exam held.', 59: 'Explicit physical default/future-needed special/makeup online only. Actual quizzes/discussion whole normal class; outside brand campaigns are assignments not actual field schedule.8/16exam held.', 60: 'Physical default/future-only remote; SPSS practice whole class not clinical.8mid15final16empty held.', 61: 'Physical default/future-only remote; client campaigns are assignments not whole external operations.9mid16finalheld;8 regular crisis-management own dated course normal exam-period override needs independent exact date proof.', 62: 'Held: definite asynchronous mix not merely future conditional, whole-date allocation unpublished.', 63: 'Held: definite asynchronous mix not merely future conditional, whole-date allocation unpublished.', 64: 'Physical ordinary printed-MMDD groups; Oct9 Zoom OR recording alternative held; speech assessment and16actualwrapup/makeup separate explicit date/HHexceptions review required; video uploads are assignments not class VOD.', 65: 'Physical ordinary printed-MMDD groups; Oct9holiday no normal override;7/8/13/14assessment-only held;16wrapup/makeup own exact date needs scoped exception proof.', 66: 'Held: own one-to-one physical plan without absolute HH.', 67: 'Held: one-to-one physical/nonface mixed plan without absolute HH.', 68: 'Physical current whole class; network/AI lab normal classroom and possible future internship/2027 roadmap not current internship allocation.15ownfinal held;16own normal feedback may scoped calendar exam exception.', 69: 'Held: actual online selected without whole physical/live allocation; films media topics not class mode proof.', 70: 'Physical own primarily in-person with exactly1 asynchronous week;12 Online maps that single statedasyncweek, remaining regular whole groups physical.8/16examheld; weekday-before-exam review exactshort exception potential but HH unknown outsidecurrentnative.', 71: 'Own whole Zoom course explicitly declared in source class guidance; separate fixed-live followup only, not physical. Generic readings/topics not travel or video class.', 72: 'Own explicit inclass physical activities with separate preclass videos/online assignments; QUEST alone not mode.8mid15final16unspecifiedmakeup held.', 73: 'Own physical theory/inclass practice; actual14 field trip held; other printed normal whole groups independent.8/16mixedassessment held.', 74: 'Held: individual thesis physical OR online; own HH unpublished. Livinglab prerequisite not current class operation.', 75: 'Held: physical/native full230-minute allocation disagrees with own90-minute lecture+individual120-minute practice, primarily e-campus recording; no full native slot booked.', 76: 'Held: graduation thesis/capstone without own HH; old2015 deadline not current2026 period.', 77: 'Own inclass lecture/practice; actual12–14 institution visit held, source2weeks versus3visitweeks conflict restricted tovisit groups. Other whole campus classes independent.8/16examheld.', 78: 'Held: actualfield practicum40hour total andvariable8–10weeks/possibleholidayextension but no ownHH; nosemesterfullweeklyguess.', 79: 'Held: actual childcare practice occurred mainly vacations, later registration/docsubmission, no ownHH. Currentweeklyrows not literalattendance.', 80: 'Own explicit grading Monday physical attendance supports wholeMonday only. Wednesday PRR submission plus generic live-guidance not physical extent; heldWednesdays,8/16assessmentheld. Parent-method topics not actual fieldplacement.'}
assert len(HH)==14 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-51];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
 assert native and not re.sub(r'[\s,]','',slot.sub('',c['sourceSchedule']))
 assert [('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()) for m in native]==HH[n] or False,(n,c['sourceSchedule'],HH[n])
 if False:
  native=native[1:]
  assert [('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()) for m in native]==HH[n]
 for plan,z in zip(plans,x['plans']):
  assert plan['campus']=={'seoul':'서울','global':'국제'}[c['campus']];assert plan['header']==['2026학년도 2학기 강의계획서'] and plan['lectureCode']==c['sourceEducationalVariants'][0]['lecture_cd']
  assert plan['queriedProfessorName'] in [v['teach_na'] for v in c['sourceEducationalVariants']]
  basic=next(s['rows'] for s in plan['educationalSections'] if s['section']=='기본정보');assert [r[1] for r in basic if r[0]=='학수번호']==[plan['lectureCode']]
  normal=re.sub(r'\s+','',next(r[1] for r in basic if r[0]=='강의시간강의실'))
  for m in native:assert m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5] in normal and re.sub(r'\s+','',m[6]) in normal,(n,normal)
  shas[z['file']]=hashlib.sha256(pathlib.Path(z['file']).read_bytes()).hexdigest()
 rows=next(s['rows'] for s in plans[0]['educationalSections'] if s['section']=='주별강의내용');own={int(r[0][:-1]):r for r in rows if r and re.fullmatch(r'\d+주',r[0])};spans=[]
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
 for m in native:
  if n in allowedWeekdays and ('월화수목금토일'.index(m[1])+1) not in allowedWeekdays[n]:continue
  wd='월화수목금토일'.index(m[1])+1
  for a,b,r in spans:
   day=a
   while day<=b:
    if day.isoweekday()==wd and permitted(day):meetings.append({'date':day.isoformat(),'weekday':wd,'startMinute':int(m[2])*60+int(m[3]),'endMinute':int(m[4])*60+int(m[5]),'classroom':actualRoom(r,m[6].strip())})
    day+=dt.timedelta(days=1)
 for a,b,r in spans:
  for wd,st,en,room in HH[n]:
   if n in allowedWeekdays and wd not in allowedWeekdays[n]:continue
   day=a+dt.timedelta(days=(wd-a.isoweekday())%7)
   while day<=b:
    if permitted(day):independent.append((day.isoformat(),wd,st,en,actualRoom(r,room)))
    day+=dt.timedelta(days=7)
 assert len(set(independent))==len(meetings);assert set(independent)=={(r['date'],r['weekday'],r['startMinute'],r['endMinute'],r['classroom']) for r in meetings}
 selected[c['sourceId']]=meetings;count+=len(meetings)
 proof.append({'packetOrdinal':n,'sourceId':c['sourceId'],'wholePlans':plans,'nativeClock':c['sourceSchedule'],'ownCampus':plans[0]['campus'],'literalNativeHH':HH[n],'allowedPhysicalWeeksLiteral':ws,'physicalRowsLiteral':[r for a,b,r in spans],'semanticReason':reasons[n],'explicitUnscheduledDatesLiteral':sorted(exceptDates.get(n,set())),'independentDates':sorted({k[0] for k in independent}),'literalIndependentMeetings':[list(k) for k in sorted(independent)],'ownExamNormalExceptionsLiteral':sorted(examExceptions.get(n,set())),'ownHolidayNormalExceptionsLiteral':sorted(holidayExceptions.get(n,set())),'ownExplicitDatesLiteral':sorted(explicitDates.get(n,set())),'ownRoomOverridesLiteral':roomOverride.get(n,{}),'roomUnconfirmedWeekdaysLiteral':sorted(roomUnconfirmedWeekdays.get(n,set())),'allowedWeekdaysLiteral':sorted(allowedWeekdays.get(n,set())),'newDateCount':len(meetings),'previousResearchDepartmentRemarks':c['departmentRemarks'],'remoteHoursGenerated':0})
for campus in ['seoul','global']:
 old=json.load(open(P.parent/('packet003b-twelve-explicit-live' if campus=='seoul' else 'packet003-next30')/(f'khu-{campus}-2026-2.twelve-fixed-live-prepared.json' if campus=='seoul' else f'khu-{campus}-2026-2.packet003-physical-groups-prepared.json')));(P/f'packet004-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside004'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet004-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet004-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2626,'baselineDates':49654,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2626+len(selected),'totalDates':49654+count})
