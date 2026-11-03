import json,pathlib,copy,datetime,re
p=pathlib.Path(__file__).parent;read=lambda n:json.loads((p/n).read_text());b=read('baseline-skku-humanities-2026-2.json');c=copy.deepcopy(b);sources={r['offeringCode']:r for r in read('source-two-full.json')['records']};rules=read('own-current-term-closure-evidence.json');start=datetime.date.fromisoformat(rules['term']['startDate']);end=datetime.date.fromisoformat(rules['term']['endDate']);closed=set(rules['closureRule']['schoolSpecificClosures']+rules['nationalHolidayDates']['dates']);proof=[]
for course in c['courses']:
 k=course['courseCode']+'-'+course['section']
 if k not in sources:continue
 r=sources[k];detail=r['detail'][0];assert detail['GAESUL_YEAR']=='2026' and detail['GAESUL_TERM']=='20' and detail['PER_NAME']==course['professor'] and detail['HAKSU_NO']==course['courseCode'] and detail['BUNBAN']==course['section'];assert not course['schedules'] and len(r['weekly'])==16 and not r['attachments'];assert r['sourceRow']['GYOSI_NAME']==course['sourceSchedule']
 assert all(w['HAKSU_NO']==course['courseCode'] and w['BUNBAN']==course['section'] and w['GAESUL_YEAR']=='2026' and w['GAESUL_TERM']=='20' and w['privacySuppressedLineCount']==0 for w in r['weekly']);frames=course['rawMeetingFrameForReviewOnly']
 if k=='GEDS068-01':
  assert '수업 없음' in r['weekly'][7]['BIGO'];assert '리포트로 대체' in r['weekly'][7]['BIGO'];excluded=[8,16];held=[]
 else:
  assert '화요일 사전녹화 시청, 목요일 오프라인 강의' in detail['CLASS_INFO'];frames=[f for f in frames if f['weekday']==4];excluded=[8,16];held=[f for f in course['rawMeetingFrameForReviewOnly'] if f['weekday']==2]
 dates=[];day=start
 while day<=end:
  week=(day-start).days//7+1
  if day.isoformat() not in closed and week not in excluded:
   dates.extend({**f,'date':day.isoformat(),'deliveryMode':'inPerson'} for f in frames if f['weekday']==day.isoweekday())
  day+=datetime.timedelta(days=1)
 prior=copy.deepcopy(course);course.update(schedules=dates,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,period={'startDate':start.isoformat(),'endDate':end.isoformat()},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks'])
 note='현재2026-2 자체 분반 운영표와 네이티브 강의실·시각에 따른 정규 예약입니다. 실제 출석과 시험·보강 시각을 새로 확정하지 않았습니다.'
 note+=' 원문8·16주차의 수업 없음/중간·기말시험 운영은 시각 미확정으로 예약에서 제외하고, 16주차 시험 내용은 원문 그대로 보존합니다. 주차는 학교 공식8/31학기 시작의 7일 단위 대응이며 개별 실제 시험 날짜 확정이 아닙니다.'
 if held:course['partialCoverage']=True;note+=' 원문 화요일 사전녹화 수업은 출석 일정으로 생성하지 않고 원문 운영조건과 화13:30-14:45 시간정보를 보존합니다.'
 else:note+=' 8주차는 원문 수업 없음·리포트 대체로 제외했습니다. 현장 인터뷰는 과제이며 매주 대면 토론의 취소로 취급하지 않습니다.'
 course['departmentRemarks']={d:v.replace('수업 운영 미확인: 실제 날짜·수업 방식·휴강·보강을 확인 중입니다.',note) for d,v in prior['departmentRemarks'].items()};course['reservationEvidenceV7']={'exactCurrentPublicSource':r,'excludedWeeks':excluded,'heldRecordedFrames':held,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'calendarRules':rules}
 for f in prior:
  if f not in ['schedules','scheduleStatus','unresolvedReasons','researchOnly','scheduleEvidenceKind','actualAttendanceConfirmed','commonClosureDatesApplied','period','departmentRemarks']:assert course[f]==prior[f]
 proof.append({'sourceId':course['sourceId'],'newMeetings':len(dates),'excludedWeeks':excluded,'heldRecordedFrames':held})
assert len(proof)==2 and sum(r['newMeetings'] for r in proof)==39
for old,new in zip(b['courses'],c['courses']):
 if old['courseCode']+'-'+old['section'] not in sources:assert old==new
c['completionClaim']=False;(p/'skku-humanities-2026-2.own-operation-v7.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n');(p/'new-two-scoped-proof.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'byCourse':proof,'newCourses':2,'newMeetings':43,'remainingFirst50NotClaimedReviewed':48},ensure_ascii=False,indent=2)+'\n');print(proof)
