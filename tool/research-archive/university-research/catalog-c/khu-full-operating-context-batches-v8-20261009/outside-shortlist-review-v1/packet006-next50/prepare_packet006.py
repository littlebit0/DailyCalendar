# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet006-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={111: [(4, 540, 590, '첨단강의실'), (4, 600, 710, '')], 112: [(4, 540, 590, '첨단강의실'), (4, 600, 710, '')], 113: [(4, 540, 590, '첨단강의실'), (4, 600, 710, '')], 114: [(3, 840, 950, '제1의학관 cbt실'), (3, 720, 830, '첨단강의실')], 115: [(3, 840, 950, '제1의학관 cbt실'), (3, 720, 830, '첨단강의실')], 121: [(2, 960, 1070, ''), (2, 900, 950, '4강의실')], 123: [(5, 780, 890, '첨단강의실')], 132: [(5, 780, 890, '4강의실'), (5, 900, 1010, '')], 133: [(5, 780, 890, '4강의실'), (5, 900, 1010, '')], 134: [(5, 960, 1070, '첨단강의실')], 137: [(2, 810, 860, '첨단강의실'), (2, 870, 990, '')]}
weeks={111: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13], 112: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 113: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 114: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 115: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 121: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 123: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 132: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 133: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 134: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 137: [1, 2, 4, 5, 6, 7, 9, 10, 11, 12, 13]}
allowedWeekdays={};exceptDates={};examExceptions={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
allowedNativeGroups={114:{1},115:{1},121:{1}}
calendarPlan={112:1,114:1,115:1,121:1}
reasons={111: 'Own bothcomplete currentplans physical lecture+project, secondexplicitone onlineproject evaluation1time notwhole allocated;14/15 projectupload/evaluation held. Othernormal whole groups only, grade/prereq full preserved.', 112: 'Own complete coordinator currentphysicaltheory/project with two exactseparateHH, other emptyteacher retained; videoassignment notVOD replacement.8/16examheld.', 113: 'Own complete coordinator currentphysicaltheory/project with two exactseparateHH, other emptyteacher retained; videoassignment notVOD replacement.8/16examheld.', 114: 'Separate own theoryWednesday12–13:50 only. Coding lab14–15:50 held for unspecified foursectionrotation, September3/10weekdayconflict; possibleearlyfinishnotactualclock.', 115: 'Separate own theoryWednesday12–13:50 only. Coding lab14–15:50 held for unspecified foursectionrotation, September3/10weekdayconflict; possibleearlyfinishnotactualclock.', 116: 'Held: actualdefinite physical+asynchronousresearchmix, no ownHH; no neuroscience surgerytopicclock invention.', 117: 'Held: actualresearch/experiment fullplan but no ownHH.', 118: 'Held: actualresearch/experiment fullplan but no ownHH.', 119: 'Held: physicalresearch declared but ownHH absent; patientclinicaltopics notactualplacementclock.', 120: 'Held: physicaltheory declared but ownHH absent; no same-title sectionclock borrowed.', 121: 'Own fullphysical teacher theory15–15:50 only; otherteacher lab16–17:50 emptyplan, allocationheld. Whole original sourcepreserved.', 122: 'Held: explicitlyvarying individualexperiments/projects no ownHH; no semesterweeklyguess.', 123: 'Own complete physicaltheory fullcoordinator sameexactHHforall7teachers, remaining6emptyplans retained; patientinterview theorynotclinicalassignment.8/16examheld.', 124: 'Held: explicitlyoneweek chosenbypriorconsultation, unknownweek/HH; weeklytopiclist not actual16weekoperations.', 125: 'Held: actualindividualresearch/experiments but ownHHunpublished.', 126: 'Held: mentoringphysicalmeeting fullplan but ownHH absent, no calendarborrow.', 127: 'Held: actualphysicaltheory/lab but ownHH unpublished.', 128: 'Held: ownphysicalsmallgroupSPSS practice but noHH; clinicalapplicationtopic notactualclinicalplacement.', 129: 'Held: explicit2day intensiveafterfinals-beforegrades uncertainactualdates/am-pm HHnotpublished; no week16 normalguess.', 130: 'Held: actualresearchallocatedphysical/video/report weekly but noHH; noVODfixedclock.', 131: 'Held: actualwritingcourse/physicaldeclared but noHH; teamreportdeadlinesnotclassclock.', 132: 'Own complete fullcurrentphysicallecture/lab exacttwoFridayHH withblankroom, medicalphysics topicnotclinicalrotation.4closure8/16examsheld.', 133: 'Own complete fullcurrentphysicallecture/lab exacttwoFridayHH, otheremptyteacherretained; blankroomnotblock.4closure8/16examsheld.', 134: 'Own explicitphysicalcareerintro/participatorytheory, clinicalexperience title actual indirectcareerdiscussion not hospitalrotation. ExactFri16–17:50,15/16emptyheld;8regularclass conservative examperiodheld.', 135: 'Held: independentresearchphysicaldeclared but noHH.', 136: 'Held: actualresearch/firstphysicalorientation but noHH.', 137: 'Own complete coordinator regularanatomytheory/practice sameexacttwoTueHH.3Chuseokconflict and14/15animallabunallocatedheld, no othersectiondurationborrow.', 138: 'Held: actualphysicalresearchlab but noHH.', 139: 'Held: actualphysicalresearch andnonfacepaperwork, evenorientationnoHH.', 140: 'Held: actualcell/animalexperiments but noHH;2025topictextretained withoutusingasactual2026clock.'}
assert len(HH)==11 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-111];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet005-next30'/f'khu-{campus}-2026-2.packet005-physical-groups-prepared.json'));(P/f'packet006-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside004'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet006-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet006-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2655,'baselineDates':50192,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2655+len(selected),'totalDates':50192+count})
