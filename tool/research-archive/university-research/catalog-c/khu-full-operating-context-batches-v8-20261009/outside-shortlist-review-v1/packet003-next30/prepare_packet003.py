# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet003-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={21: [(1, 990, 1065, '정302'), (3, 990, 1065, '정302')], 24: [(5, 990, 1155, '정309')], 25: [(2, 1080, 1245, '정309')], 28: [(5, 630, 795, '정302')], 29: [(4, 900, 1065, '정404')], 31: [(1, 630, 705, '정304'), (3, 630, 705, '정304')], 32: [(1, 810, 885, '정304'), (3, 810, 885, '정304')], 38: [(6, 540, 705, '정303')], 39: [(2, 630, 705, '정131'), (4, 630, 705, '정131')], 40: [(2, 810, 885, '정131'), (4, 810, 885, '정131')], 41: [(2, 540, 615, '정405'), (4, 540, 615, '정405')], 45: [(1, 930, 1005, '구(한)310'), (3, 930, 1005, '구(한)310')], 49: [(1, 810, 885, '정308'), (3, 810, 885, '정308')]}
weeks={21: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13], 24: [1, 2, 3, 4, 5, 6, 7], 25: [1], 28: [1, 2, 3, 7, 9, 10, 11, 14, 15], 29: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 31: [1, 2, 3, 4, 5, 6, 7], 32: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 38: [1, 2, 3, 5, 10, 13, 15], 39: [1, 2, 3, 4, 5, 7, 9, 10, 11, 12, 13, 14, 15], 40: [1, 2, 3, 5, 7, 9, 13, 14, 15], 41: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 45: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 49: [1, 2, 4, 5, 6, 7, 9, 10, 12, 13, 14, 15]}
allowedWeekdays={};exceptDates={};examExceptions={};holidayExceptions={};explicitDates={21: {'2026-09-14', '2026-10-14', '2026-11-30', '2026-10-07', '2026-11-16', '2026-09-09', '2026-09-23', '2026-11-25', '2026-11-23', '2026-11-09', '2026-11-04', '2026-09-07', '2026-09-30', '2026-09-21', '2026-11-11', '2026-11-18', '2026-10-19', '2026-09-16', '2026-10-12', '2026-09-02', '2026-09-28'}};roomOverride={};roomUnconfirmedWeekdays={}
reasons={21: 'Own literal physical dates only; exact Oct28/Nov2/Dec2/Dec7 Zoom followup, VOD/exam/Dec14 weekday conflict held.', 22: 'Held: independent thesis seminar without published absolute HH.', 23: 'Held: explicit blended/flipped method without whole physical/live allocation.', 24: 'Own early 1–7 whole theoretical classroom course; 8–16 middle-school/campus mock-lesson location and extent unresolved.', 25: 'Own whole first orientation/theory week only; later mock-lessons at school or campus mixed extent unresolved.', 26: 'Held: graduation thesis without own HH; 8-semester eligibility not class period.', 27: 'Held: both professors explicitly physical AND independent/nonface; whole-date allocation unresolved.', 28: 'Own literal physical Fridays; Oct2/Nov27 explicit Zoom followup. Sep25 VOD, Oct9 closure, Nov20 VOD/exams held.', 29: 'Own current classroom theory/PBL; basic finance videos auxiliary, not whole replacement.15 conditional closure/makeup held.', 30: 'Held: office meeting every Wednesday at15 but own end unpublished; no credit-duration inference.', 31: 'Early weeks1–7 normal classroom theory; later actual public-diplomacy event participation/field-method allocation unresolved.8 makeup without date and16exam held.', 32: 'Explicit offline default, future emergency-only online. Inclass ASEAN student presentations+discussion cover whole HH; countries not field travel.', 33: 'Held: selected online checkbox without physical/live allocation; week7 home-study mode unresolved.', 34: 'Held: current native MonWed versus own plan basic Mon-only clock discrepancy; neither temporal source silently chosen.', 35: 'Held: thesis without own HH.', 36: 'Held: independent research without own HH.', 37: 'Held: empty current plan and no own HH.', 38: 'Own weekly explicit physical Saturdays; Oct3 closure has no own normal override. Whole Zoom weeks separate followup. Assessment weekday conflict not repaired.', 39: 'Physical default; source6 literal Chuseok contradicts own calendar so entire week6 held. Future-only remote not actual allocation.', 40: 'Physical normal whole weeks only;4/10/11 VOD mixed extent,6 Chuseok conflict,12 reading-day mixed presentations held. ODA topics not actual travel.', 41: 'Own physical normal default; explicit nonface is makeup method only, unspecified makeup dates not generated. Auxiliary online materials not allocated class.', 42: 'Held: empty graduation plan without own HH.', 43: 'Held: selected online checkbox without explicit whole physical/live mode override.', 44: 'Held: independent course empty plan/no own HH.', 45: 'Explicit current whole physical overrides checkbox; raw nested classroom string preserved. Future special/makeup nonface not actual regular replacement.', 46: 'Held: independent capstone without own HH.', 47: 'Held: independent capstone without own HH.', 48: 'Held: selected online checkbox with no explicit whole physical/live allocation;15 makeup date/time unknown.', 49: 'Own physical default whole groups;3 actual untyped online and11 private interviews/hybrid excluded.14/15 inclass team presentations normal.', 50: 'Held: empty graduation plan without own HH.'}
assert len(HH)==13 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-21];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/('packet002b-four-explicit-live' if campus=='seoul' else 'packet002-next10')/(f'khu-{campus}-2026-2.four-fixed-live-prepared.json' if campus=='seoul' else f'khu-{campus}-2026-2.packet002-physical-groups-prepared.json')));(P/f'packet003-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside003'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet003-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet003-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2613,'baselineDates':49428,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2613+len(selected),'totalDates':49428+count})
