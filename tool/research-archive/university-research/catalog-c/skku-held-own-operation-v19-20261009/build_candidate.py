import json,pathlib,copy,datetime
p=pathlib.Path(__file__).parent
read=lambda n:json.loads((p/n).read_text())
baselines={campus:read(f'baseline-skku-{campus}-2026-2.json') for campus in ['humanities','naturalScience','icampus']};candidates=copy.deepcopy(baselines);sources={r['offeringCode']:r for r in read('source-one-full-attachment-identity.json')['records']};rules=read('own-current-term-closure-evidence.json');start=datetime.date.fromisoformat(rules['term']['startDate']);end=datetime.date.fromisoformat(rules['term']['endDate']);closed=set(rules['closureRule']['schoolSpecificClosures']+rules['nationalHolidayDates']['dates'])
exclude=read('reviewed-exclusion-rules.json')
literal={'ENG2026-01':['09-04','09-11','09-18','10-23','11-06','11-20']}
full=read('eng2026-01-full-education.json');assert full['pages']==3 and full['privateLinesOmitted']==1 and '2026 년 2 학기' in full['educationFullText'] and 'ENG2026-01' in full['educationFullText'] and '정효진' in full['educationFullText'];ownTimes=__import__('re').findall(r'(\d{1,2}/\d{1,2})\s*\(offline:\s*12-\s*13:15\)',full['educationFullText']);assert ownTimes==['9/4','9/11','9/18','10/23','11/6','11/20']
proof=[]
for course in [c for dataset in candidates.values() for c in dataset['courses']]:
 key=course['courseCode']+'-'+course['section']
 if key not in sources:continue
 r=sources[key];d=r['detail'][0];assert (d['GAESUL_YEAR'],d['GAESUL_TERM'],d['HAKSU_NO'],d['BUNBAN'],d['PER_NAME'])==('2026','20',course['courseCode'],course['section'],course['professor']);assert r['sourceRow']['GYOSI_NAME']==course['sourceSchedule'];assert not course['schedules']
 online=[]
 prior=copy.deepcopy(course);dates=[];day=start
 while day<=end:
  week=(day-start).days//7+1
  if day.isoformat() not in closed and week not in exclude[key] and (key not in literal or day.strftime('%m-%d') in literal[key]):
   dates.extend({**f,'date':day.isoformat(),'deliveryMode':'inPerson'} for f in course['rawMeetingFrameForReviewOnly'] if f['weekday']==day.isoweekday() and f['startMinute']==720 and f['endMinute']==795)
  day+=datetime.timedelta(days=1)
 note='현재2026-2 해당 분반의 자체 전체16주 운영표와 학교 네이티브 수업시각·강의실에 따른 정규 대면 예약입니다. 실제 출석·시험·미확정 보강 시각은 확정하지 않았습니다. 제외 주차 '+','.join(map(str,exclude[key]))+'는 원문 시험/휴강/보강·자율학습/개별상담 또는 날짜충돌 구간입니다. 학교 공식8/31 시작의 7일 단위 주차 대응은 예약 제외 경계이며 실제 시험 날짜라는 주장이 아닙니다.'
 note+=' 사전영상·휴일 온라인 보강·별도 현장/상담/과제 등 미확정 운영조건은 원문 그대로 보존하며 대면 예약으로 생성하지 않습니다.'
 note+=' 각강좌 자체 사전영상/고정 대면구간 또는 오프라인 강좌구분을 확인했습니다. 단일1.5OFF 또는3hOFF native구간은 원문HH 그대로 사용하며 사전제작영상은 주간예약으로 생성하지 않습니다.'
 note+=' 현재2026-2 ENG2026-01 정효진 전체3페이지16개actual월일운영행 확인했습니다. 대부분12–13:15라는조건을모든주로일반화하지않습니다. 자체각날짜옆offline:12–13:15가명시된9/4·9/11·9/18·10/23·11/6·11/20 총6일만native금12–13:15room31607에연결합니다.그밖의offline하지만HH미기재·중간프로젝트·개별면담·최종제출·녹화/휴일·다른13:30native관리슬롯을예약으로추정하지않고원문전부보존합니다.원문연락처1행은제거하였고실제사전제작영상은정규예약으로생성하지않습니다.'
 course.update(schedules=dates,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':start.isoformat(),'endDate':end.isoformat()},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks'])
 course['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};course['reservationEvidenceV19']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':full,'excludedOrdinalWeeks':exclude[key],'ordinalIsDerivedExclusionNotConfirmedExamDate':True,'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':None,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'calendarRules':rules}
 changed={'schedules','scheduleStatus','unresolvedReasons','researchOnly','scheduleEvidenceKind','actualAttendanceConfirmed','commonClosureDatesApplied','partialCoverage','period','departmentRemarks'}
 for field in prior:
  if field not in changed:assert prior[field]==course[field]
 proof.append({'sourceId':course['sourceId'],'offeringCode':key,'newMeetings':len(dates),'excludedOrdinalWeeks':exclude[key],'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':None})
for campus,b in baselines.items():
 for old,new in zip(b['courses'],candidates[campus]['courses']):
  if old['courseCode']+'-'+old['section'] not in sources:assert old==new
 candidates[campus]['completionClaim']=False
 if any(x['courseCode']+'-'+x['section'] in sources for x in b['courses']):(p/f'skku-{campus}-2026-2.own-operation-v19.json').write_text(json.dumps(candidates[campus],ensure_ascii=False,indent=2)+'\n')
assert len(proof)==1
(p/'new-one-scoped-proof.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'byCourse':proof,'newCourses':1,'newMeetings':sum(a['newMeetings'] for a in proof)},ensure_ascii=False,indent=2)+'\n');print(proof)
