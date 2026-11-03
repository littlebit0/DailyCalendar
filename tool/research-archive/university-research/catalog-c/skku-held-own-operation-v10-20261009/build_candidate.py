import json,pathlib,copy,datetime
p=pathlib.Path(__file__).parent
read=lambda n:json.loads((p/n).read_text())
baselines={campus:read(f'baseline-skku-{campus}-2026-2.json') for campus in ['humanities','naturalScience','icampus']};candidates=copy.deepcopy(baselines);sources={r['offeringCode']:r for r in read('source-seventeen-full-inline.json')['records']};rules=read('own-current-term-closure-evidence.json');start=datetime.date.fromisoformat(rules['term']['startDate']);end=datetime.date.fromisoformat(rules['term']['endDate']);closed=set(rules['closureRule']['schoolSpecificClosures']+rules['nationalHolidayDates']['dates'])
exclude={'GELT075-05':[8,11,12,13,14,16],'GELT075-06':[8,11,12,13,14,16],'GEDM001-07':[15,16],'GEDM001-E9':[15,16],'GEDW027-41':[16],'GEDW004-41':[16],'GEDW004-42':[16],'GEDW004-45':[16],'GEDG002-46':[16],'GEDG002-48':[16],'GEDG002-54':[16],'BUS2028-02':[8,14,16],'BUS2028-03':[8,14,16],'GBA3008-01':[8,15,16],'GEC3109-01':[8,15,16],'PHL3040-01':[8,15],'FRE2017-01':[7,8,15,16]}
literal={}
proof=[]
for course in [c for dataset in candidates.values() for c in dataset['courses']]:
 key=course['courseCode']+'-'+course['section']
 if key not in sources:continue
 r=sources[key];d=r['detail'][0];assert (d['GAESUL_YEAR'],d['GAESUL_TERM'],d['HAKSU_NO'],d['BUNBAN'],d['PER_NAME'])==('2026','20',course['courseCode'],course['section'],course['professor']);assert r['sourceRow']['GYOSI_NAME']==course['sourceSchedule'];assert len(r['weekly'])==16 and not r['attachments'] and not course['schedules'];assert all(w['GAESUL_YEAR']=='2026' and w['GAESUL_TERM']=='20' and w['HAKSU_NO']==course['courseCode'] and w['BUNBAN']==course['section'] and w['privacySuppressedLineCount']==0 for w in r['weekly']);assert [int(w['PLAN_WEEK_CNT']) for w in r['weekly']]==list(range(1,17))
 online=[]
 prior=copy.deepcopy(course);dates=[];day=start
 while day<=end:
  week=(day-start).days//7+1
  if day.isoformat() not in closed and week not in exclude[key] and (key not in literal or day.strftime('%m-%d') in literal[key]):
   dates.extend({**f,'date':day.isoformat(),'deliveryMode':'inPerson'} for f in course['rawMeetingFrameForReviewOnly'] if f['weekday']==day.isoweekday())
  day+=datetime.timedelta(days=1)
 note='현재2026-2 해당 분반의 자체 전체16주 운영표와 학교 네이티브 수업시각·강의실에 따른 정규 대면 예약입니다. 실제 출석·시험·미확정 보강 시각은 확정하지 않았습니다. 제외 주차 '+','.join(map(str,exclude[key]))+'는 원문 시험/휴강/보강·자율학습/개별상담 또는 날짜충돌 구간입니다. 학교 공식8/31 시작의 7일 단위 주차 대응은 예약 제외 경계이며 실제 시험 날짜라는 주장이 아닙니다.'
 note+=' 사전영상·휴일 온라인 보강·별도 현장/상담/과제 등 미확정 운영조건은 원문 그대로 보존하며 대면 예약으로 생성하지 않습니다.'
 if key in ['GELT075-05','GELT075-06']:note+=' 11–14주차 소그룹 면담은 본인 참여일정이 미공개이므로 전체 주차 예약을 제외합니다. 다른 학사안내 수업은 네이티브 분반별 시각을 그대로 사용합니다.'
 if key.startswith('GEDM001-') or key.startswith('GEDW0'):note+=' 자체 각 주차 온라인·오프라인 구간을 구분하여 오프라인으로 명시된 주차의 네이티브 교실구간만 예약합니다. 사전영상·별도작성과제·미확정 보강은 원문보존만 합니다. 수업자료실 참고자료는 실제 다른 장소의 수업배정으로 바꾸지 않습니다.'
 if key.startswith('BUS2028-'):note+=' 자체월요일 사전영상·수요일 토론운영에 따라 유일한 수요일 네이티브 대면구간만 예약합니다. 14주차자율활동·학생상담은 정확한 개인배정이 미확정입니다.'
 if key=='PHL3040-01':note+=' 시험은 개인보고서로 대체하고8·15주차개인면담은 미확정이므로 제외합니다.16주차는 원문정규강의이며 임의시험예약을 생성하지 않습니다.'
 if key=='FRE2017-01':note+=' 7주차시험·8주차개별결과안내·15주차개인구술시험·16주차보강은 실제개인시각미확정이라 제외합니다.'
 course.update(schedules=dates,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':start.isoformat(),'endDate':end.isoformat()},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks'])
 course['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};course['reservationEvidenceV10']={'exactCurrentPublicSource':r,'excludedOrdinalWeeks':exclude[key],'ordinalIsDerivedExclusionNotConfirmedExamDate':True,'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':None,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'calendarRules':rules}
 changed={'schedules','scheduleStatus','unresolvedReasons','researchOnly','scheduleEvidenceKind','actualAttendanceConfirmed','commonClosureDatesApplied','partialCoverage','period','departmentRemarks'}
 for field in prior:
  if field not in changed:assert prior[field]==course[field]
 proof.append({'sourceId':course['sourceId'],'offeringCode':key,'newMeetings':len(dates),'excludedOrdinalWeeks':exclude[key],'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':None})
for campus,b in baselines.items():
 for old,new in zip(b['courses'],candidates[campus]['courses']):
  if old['courseCode']+'-'+old['section'] not in sources:assert old==new
 candidates[campus]['completionClaim']=False
 if any(x['courseCode']+'-'+x['section'] in sources for x in b['courses']):(p/f'skku-{campus}-2026-2.own-operation-v10.json').write_text(json.dumps(candidates[campus],ensure_ascii=False,indent=2)+'\n')
assert len(proof)==17
(p/'new-seventeen-scoped-proof.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'byCourse':proof,'newCourses':17,'newMeetings':sum(a['newMeetings'] for a in proof)},ensure_ascii=False,indent=2)+'\n');print(proof)
