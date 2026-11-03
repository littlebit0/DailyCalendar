from pathlib import Path
from datetime import date
import sys,json,copy,hashlib,re
P=Path(__file__).resolve().parent;sys.path.insert(0,str(Path('tool/timetable').resolve()))
from import_hansung import clean,schedules,regular_teaching_dates
B=P/'hansung-frozen-prior-pass16-1489.json';baseline=json.loads(B.read_text());candidate=copy.deepcopy(baseline)
old={c['courseCode']+'-'+c['section']:c for c in baseline['courses']}
read=json.loads((P/'selected-current-plan-read-receipt.json').read_text());keys=read['selectedActualUnreviewedKeys']
# Source-specific decisions after independently reading complete educational notes and15 actual weekly topics.
held={
 'CTS0011-7':'Final12/14 is written in week6 although the current normal calendar week6 is10/5; retain held until source position/date meaning is resolved, never silently choose the date or index.',
 'CTS0011-8':'Final12/14 is written in week6 although the current normal calendar week6 is10/5; retain held until source position/date meaning is resolved.',
 'CTS0011-A':'Final12/17 is written in week4 although the current normal calendar week4 is9/24; retain held until source position/date meaning is resolved.',
 'CTS0011-N':'Final12/17 is written in week4 although the current normal calendar week4 is9/24; retain held until source position/date meaning is resolved.',
 'GEN0845-A':'Week5 describes 대체휴일(10.5) 이후 but normal week5 falls9/28; actual source date/week placement unresolved, unchanged held.',
 'GEN0845-N':'Week5 describes 대체휴일(10.5) 이후 but normal week5 falls9/28; actual source date/week placement unresolved, unchanged held.'}
# These dates are explicit current exams with no independently published exam HH. Omission is precaution, not no-class assertion.
omitted={
 'R01B004-8':{'2026-10-19':'중간고사(2026.10.19)'},
 'R01B004-A':{'2026-10-19':'중간고사(2026.10.19)'},
 'R01B004-N':{'2026-10-19':'중간고사(2026.10.19)'},
 'CTS0019-A':{'2026-10-22':'10/22 중간고사'},
 'CTS0019-N':{'2026-10-22':'10/22 중간고사'},
 'R01C010-A':{'2026-10-20':'10/20 중간고사'}}
reviews=[]
for key in keys:
 c0=old[key];fp=P/'selected-current-education-plans'/f'{key}.json';p=json.loads(fp.read_text());e=p['education']
 assert e['data_year']=='2026' and e['hakgi']=='2' and e['kwamok']==c0['courseCode'] and e['bunban']==c0['section']
 assert clean(e['timeclassroom'])==c0['sourceSchedule'] and clean(e['kwamokname'])==c0['courseName']
 assert e['offlineyn']=='Y' and len(e['weeks'])==15 and all(w['topicEducationLiteral'] for w in e['weeks'])
 assert not c0['schedules'] and c0['scheduleStatus']=='unrecognized'
 r={'key':key,'sourceId':c0['sourceId'],'courseName':c0['courseName'],'professor':c0['professor'],'courseCode':c0['courseCode'],'section':c0['section'],'nativeSourceSchedule':c0['sourceSchedule'],'nativeSourceClassroom':c0['sourceClassroom'],'currentPlanSourceSchedule':e['timeclassroom'],'sourceResponseSHA256':p['sourceResponseSHA256'],'educationReceiptSHA256':hashlib.sha256(fp.read_bytes()).hexdigest(),'whole15WeeksAndFullEducationalNotesIndependentlyReviewed':True,'currentNativeIdentityExactMatch':True,'nativeFieldsUnchanged':True,'plannedMakeupDatesUsedAsRegularDates':False,'videoHoursUsedAsPhysicalClock':False,'decision':'held' if key in held else 'ordinaryReservation','decisionReason':held.get(key,'Current own published room-clock and current2026-2 identity match; complete source semester context independently reviewed. Ordinary physical portion is distinguished from untimed source video/preclass. Special final/makeup operations outside regular booking scope stay unconfirmed.')}
 if key in held:reviews.append(r);continue
 c=next(c for c in candidate['courses'] if c['sourceId']==c0['sourceId']);native=schedules(c0['sourceSchedule']);dates=regular_teaching_dates(native)
 excluded=omitted.get(key,{})
 dates=[m for m in dates if m['date'] not in excluded]
 c['schedules']=dates;c['scheduleStatus']='scheduled';c['period']={'startDate':'2026-08-31','endDate':'2026-12-06'}
 note=' 현재2026-2 정상 공개 강의계획의 전체15주 교육 문맥과 공개 시간표의 실제 강좌코드·분반·요일·교시·강의실을 개별 대조한 정규 예약입니다. 학교 공식 교시 시각표만 사용하고 영상 분량에서 대면 시각을 만들지 않았습니다. 온라인·녹화 선행학습은 시각 없는 별도 부분이며 예약은 원문에 공개된 실·교시 부분만입니다. 실제 출석이나 날짜별 운영을 모두 확인했다는 뜻이 아닙니다. 자체 학사일정의8/31개강부터12/7~19기말고사·보강 주 직전12/6까지 예약합니다.12/6을 실제 종강일로 주장하지 않습니다. 공식 공휴일과 학교10/5휴업일은 제외하며 필요한 보강·시험·교외활동의 미공개 시각을 추정하지 않았습니다. 공개 보강예정일 열을 정규 수업 날짜로 바꾸지 않았습니다.'
 if key.startswith('P010182-'):note+=' 원문은9/24추석 휴강과16주차 보강을 명시합니다.9/24와12/7이후는 이 예약에 없으며16주차 보강 시각은 미확인입니다.'
 if key=='P010187-A':note+=' 원문10/5휴일의16주차 보강은 예약하지 않았습니다.'
 if key.startswith('V021003-'):note+=' 원문15주차개별기말 준비/수업생략과16주차 마무리 강의는12/7이후 범위이며 이 후보에 생성하지 않았습니다.14주차까지 실습·프로젝트 시연은 원문 수업 활동으로 보존했습니다.'
 if key.startswith('V020007-'):note+=' 원문16주차 학생 제작 동영상 시연·평가는 예약범위 밖이며 대면 강의의 영상 전환 근거로 해석하지 않았습니다.'
 if key.startswith('V021009-'):note+=' 원문4주차추석 대체16주차 SW페스티벌 및12월초 출품의 별도 참여 시각은 미확인입니다. 팀별 개발·보고서라는 활동명만으로 다른 정규 주차를 휴강으로 단정하지 않았습니다.'
 if key.startswith('V022004-'):note+=' 원문12/12토요일 오전 합동 기말고사는 정확 시각·실 미공개이며 이번 정규 예약에는 생성하지 않았습니다.'
 if key=='P01A009-A':note+=' 원문에는 주제와 관련된 현장답사를 실시할 수 있다는 조건부 안내가 있습니다. 실제 시행 날짜·장소가 확정된 자료가 아니므로 교외 수업을 생성하지 않고 공개 실·교시를 정규 예약으로만 보존했습니다.'
 if key=='V030037-7':note+=' 원문현장강의원칙과 필요시동영상대체는 조건부 안내이며, 확정된 비동기 주차의 증거로 일반화하지 않았습니다.'
 if excluded:note+=' 개별 시험 날짜만 있고 시험 시각·실을 독립 확인하지 못한 '+', '.join(excluded)+'는 예방적으로 제외했습니다. 해당 날짜의 전체 휴강을 주장하지 않습니다.'
 # Preserve full educational restrictions/mode prerequisites, with contact/link sanitization from the source boundary.
 education_note=clean(e['gita'])
 if education_note and education_note.lower() not in {'none','없음','수업안내','수업 안내','수업 시간 안내','수업 첫 시간에 안내','추후 공지','1주차에 안내'}:
  note+=' 현재 공개 계획서 교육 운영·조건 원문: '+education_note
 for dep in c['departmentRemarks']:
  c['departmentRemarks'][dep]=c['departmentRemarks'][dep].replace('수업 운영·시각 검증 중: 확인 전 자동 반복 추가 불가.','').rstrip()+note
 c['sourceEducation']={'referenceKind':'nativeCourseCodeAndSection','currentPublicPlanMatched':True,'whole15WeeksAndFullEducationalNotesReviewed':True,'sourceResponseSHA256':p['sourceResponseSHA256'],'wholeUniversityClockScope':'own Hansung weekday timetable guide only; no Saturday or partial endpoint inference','individuallyPublishedDates':False,'actualOperatingVerified':False,'reservationScope':'current own ordinary weekly reservation, known specified exceptions excluded; actual attendance unverified','untimedOnlinePortionOriginal':bool(re.search('온라인강좌',c['sourceSchedule'])),'conditionalOutsideOrOnlineOperationNotAsserted':True,'explicitExamDatePrecautionOmissions':excluded}
 r.update({'sourceNativeMeetings':native,'ordinaryBookingStart':'2026-08-31','ordinaryBookingEnd':'2026-12-06','explicitExamDatePrecautionOmissions':excluded,'newReservationCount':len(dates)})
 reviews.append(r)
changed={r['sourceId'] for r in reviews if r['decision']=='ordinaryReservation'}
assert len(changed)==57
assert len(candidate['courses'])==1489
prior={c['sourceId']:c for c in baseline['courses']}
assert all(c==prior[c['sourceId']] for c in candidate['courses'] if c['sourceId'] not in changed)
assert all(c==prior[c['sourceId']] for c in candidate['courses'] if prior[c['sourceId']]['schedules'])
for c in candidate['courses']:
 if c['sourceId'] in changed:
  for k,v in prior[c['sourceId']].items():
   if k not in {'schedules','scheduleStatus','period','departmentRemarks','sourceEducation'}:assert c[k]==v
candidate.update({'candidateRevision':'held-public-ordinary-research-v1-20261009','researchOnly':True,'completionClaim':False})
out=P/'hansung-main-2026-2.held-ordinary-candidate-v1.json';out.write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
audit={'researchOnly':True,'SDKTestPending':True,'baselineWhole':1489,'baselineScheduled':921,'baselineReservations':13679,'baselineSHA256':hashlib.sha256(B.read_bytes()).hexdigest(),'previous921WholeObjectsDeepUnchanged':True,'native1489UnionUnchanged':True,'existingNeutralPassesNotReapproved':True,'selectedCurrent63FullEducationalPlansIndependentlyReviewed':True,'selected63':reviews,'newCourses':len(changed),'newReservations':sum(r.get('newReservationCount',0) for r in reviews),'wholeScheduled':sum(bool(c['schedules']) for c in candidate['courses']),'wholeReservations':sum(len(c['schedules']) for c in candidate['courses']),'sourceClockDiagramVisuallyReviewed':True,'stillHeld':458-len(changed),'stillUntimed':110,'candidateSHA256':hashlib.sha256(out.read_bytes()).hexdigest(),'completionClaim':False}
(P/'current-source-candidate-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print({k:audit[k] for k in ['newCourses','newReservations','wholeScheduled','wholeReservations','stillHeld','candidateSHA256']})
