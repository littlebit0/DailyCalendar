import json,pathlib,copy,datetime
p=pathlib.Path(__file__).parent
read=lambda n:json.loads((p/n).read_text())
b=read('baseline-skku-humanities-2026-2.json');c=copy.deepcopy(b);sources={r['offeringCode']:r for r in read('source-ten-full-inline.json')['records']};rules=read('own-current-term-closure-evidence.json');start=datetime.date.fromisoformat(rules['term']['startDate']);end=datetime.date.fromisoformat(rules['term']['endDate']);closed=set(rules['closureRule']['schoolSpecificClosures']+rules['nationalHolidayDates']['dates'])
exclude={'GEDG002-04':[8,16],'GEDG002-05':[8,14,16],'GEDG002-10':[8,14,16],'GEDG029-03':[5,16],'GEDW018-08':[4,16],'GEDW019-03':[6,16],'GEDW008-04':[8,15,16],'GEDW014-06':[8,15,16],'GEDW014-08':[8,15,16],'GEDN017-01':[8,15]}
proof=[]
for course in c['courses']:
 key=course['courseCode']+'-'+course['section']
 if key not in sources:continue
 r=sources[key];d=r['detail'][0];assert (d['GAESUL_YEAR'],d['GAESUL_TERM'],d['HAKSU_NO'],d['BUNBAN'],d['PER_NAME'])==('2026','20',course['courseCode'],course['section'],course['professor']);assert r['sourceRow']['GYOSI_NAME']==course['sourceSchedule'];assert len(r['weekly'])==16 and not r['attachments'] and not course['schedules'];assert all(w['GAESUL_YEAR']=='2026' and w['GAESUL_TERM']=='20' and w['HAKSU_NO']==course['courseCode'] and w['BUNBAN']==course['section'] and w['privacySuppressedLineCount']==0 for w in r['weekly']);assert [int(w['PLAN_WEEK_CNT']) for w in r['weekly']]==list(range(1,17))
 if key.startswith('GEDG002-') and key!='GEDG002-04':assert '9/2' in r['weekly'][0]['BIGO'] and '9/23' in r['weekly'][3]['BIGO'];online=['2026-09-02','2026-09-23']
 else:online=[]
 if key=='GEDN017-01':assert '2nd hour' in d['CLASS_INFO'] and 'off-line class' in d['CLASS_INFO'];assert len(course['rawMeetingFrameForReviewOnly'])==1
 prior=copy.deepcopy(course);dates=[];day=start
 while day<=end:
  week=(day-start).days//7+1
  if day.isoformat() not in closed and day.isoformat() not in online and week not in exclude[key]:
   dates.extend({**f,'date':day.isoformat(),'deliveryMode':'inPerson'} for f in course['rawMeetingFrameForReviewOnly'] if f['weekday']==day.isoweekday())
  day+=datetime.timedelta(days=1)
 note='현재2026-2 해당 분반의 자체 전체16주 운영표와 학교 네이티브 수업시각·강의실에 따른 정규 대면 예약입니다. 실제 출석·시험·미확정 보강 시각은 확정하지 않았습니다. 제외 주차 '+','.join(map(str,exclude[key]))+'는 원문 시험/휴강/보강·자율학습/개별상담 또는 날짜충돌 구간입니다. 학교 공식8/31 시작의 7일 단위 주차 대응은 예약 제외 경계이며 실제 시험 날짜라는 주장이 아닙니다.'
 if online:note+=' 원문9/2·9/23 온라인 수업과14주차National Holiday 날짜모순 구간을 대면 예약에서 제외하고 원문 그대로 보존합니다.'
 if key=='GEDW019-03':note+=' 원문6주차 추석·하이브리드 추후보강의 실제 학사력 불일치는 수정하지 않고 그 주 전체를 미확정으로 보존합니다.'
 if key=='GEDN017-01':note+=' 원문1교시 온라인 사전영상은 출석 일정으로 생성하지 않으며 원문2교시 교실토론에 대응하는 유일한 네이티브 목10:30–11:45 대면구간만 예약합니다.'
 course.update(schedules=dates,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':start.isoformat(),'endDate':end.isoformat()},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks'])
 course['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};course['reservationEvidenceV8']={'exactCurrentPublicSource':r,'excludedOrdinalWeeks':exclude[key],'ordinalIsDerivedExclusionNotConfirmedExamDate':True,'recordedDatesHeld':online,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'calendarRules':rules}
 changed={'schedules','scheduleStatus','unresolvedReasons','researchOnly','scheduleEvidenceKind','actualAttendanceConfirmed','commonClosureDatesApplied','partialCoverage','period','departmentRemarks'}
 for field in prior:
  if field not in changed:assert prior[field]==course[field]
 proof.append({'sourceId':course['sourceId'],'offeringCode':key,'newMeetings':len(dates),'excludedOrdinalWeeks':exclude[key],'recordedDatesHeld':online})
for old,new in zip(b['courses'],c['courses']):
 if old['courseCode']+'-'+old['section'] not in sources:assert old==new
assert len(proof)==10;c['completionClaim']=False
(p/'skku-humanities-2026-2.own-operation-v8.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
(p/'new-ten-scoped-proof.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'byCourse':proof,'newCourses':10,'newMeetings':sum(a['newMeetings'] for a in proof),'originalAttachedFullTableVerificationNotClaimed':True},ensure_ascii=False,indent=2)+'\n');print(proof)
