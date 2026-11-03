import json,pathlib,copy,datetime
p=pathlib.Path(__file__).parent
read=lambda n:json.loads((p/n).read_text())
baselines={campus:read(f'baseline-skku-{campus}-2026-2.json') for campus in ['humanities','naturalScience','icampus']};candidates=copy.deepcopy(baselines);sources={r['offeringCode']:r for r in read('source-two-full-attachment-identities.json')['records']};rules=read('own-current-term-closure-evidence.json');start=datetime.date.fromisoformat(rules['term']['startDate']);end=datetime.date.fromisoformat(rules['term']['endDate']);closed=set(rules['closureRule']['schoolSpecificClosures']+rules['nationalHolidayDates']['dates'])
exclude=read('reviewed-exclusion-rules.json')
literal={'FTM2071-01':['08-31','09-07','09-14','09-21','10-12','10-26','11-02','11-09','11-16','11-23','11-30','12-07']}
fulls={k:read(n) for k,n in [('FTM2071-01','ftm2071-01-full-education.json'),('FTM2082-01','ftm2082-01-full-education.json')]}
proof=[]
for course in [c for dataset in candidates.values() for c in dataset['courses']]:
 key=course['courseCode']+'-'+course['section']
 if key not in sources:continue
 r=sources[key];full=fulls[key];assert full['privateLinesOmitted']==0 and key in full['educationFullText'] and '2026' in full['educationFullText'];text=full['educationFullText'];pattern=r'주차\s*(\d+)' if key=='FTM2071-01' else r'(\d+)\s*주차';expectedWeeks=list(range(1,17)) if key=='FTM2071-01' else list(range(1,16));assert [int(x) for x in __import__('re').findall(pattern,text[text.index('수   업   내   용'):])][:len(expectedWeeks)]==expectedWeeks;d=r['detail'][0];assert d['PER_NAME'] in full['educationFullText'];assert (d['GAESUL_YEAR'],d['GAESUL_TERM'],d['HAKSU_NO'],d['BUNBAN'],d['PER_NAME'])==('2026','20',course['courseCode'],course['section'],course['professor']);assert r['sourceRow']['GYOSI_NAME']==course['sourceSchedule'];assert not course['schedules']
 online=['2026-09-28'] if key=='FTM2071-01' else []
 prior=copy.deepcopy(course);dates=[];day=start
 while day<=end:
  week=(day-start).days//7+1
  if day.isoformat() not in closed and week not in exclude[key] and (key not in literal or day.strftime('%m-%d') in literal[key]):
   dates.extend({**f,'date':day.isoformat(),'deliveryMode':None if key=='FTM2082-01' else 'inPerson'} for f in course['rawMeetingFrameForReviewOnly'] if f['weekday']==day.isoweekday())
  day+=datetime.timedelta(days=1)
 note='현재2026-2 해당 분반의 자체 전체16주 운영표와 학교 네이티브 수업시각·강의실에 따른 정규 대면 예약입니다. 실제 출석·시험·미확정 보강 시각은 확정하지 않았습니다. 제외 주차 '+','.join(map(str,exclude[key]))+'는 원문 시험/휴강/보강·자율학습/개별상담 또는 날짜충돌 구간입니다. 학교 공식8/31 시작의 7일 단위 주차 대응은 예약 제외 경계이며 실제 시험 날짜라는 주장이 아닙니다.'
 note+=' 사전영상·휴일 온라인 보강·별도 현장/상담/과제 등 미확정 운영조건은 원문 그대로 보존하며 대면 예약으로 생성하지 않습니다.'
 note+=' 각강좌 자체 사전영상/고정 대면구간 또는 오프라인 강좌구분을 확인했습니다. 단일1.5OFF 또는3hOFF native구간은 원문HH 그대로 사용하며 사전제작영상은 주간예약으로 생성하지 않습니다.'
 if key=='FTM2071-01':note+=' 자체2026-2 원창재 전체2페이지16주 모두literal월일과노트북필수지참실습진행 확인했습니다.9/28온라인보강·10/5휴일·10/19필기시험·12/14실기시험 제외하고정규native월9–10:15/10:30–11:45room61415만예약합니다.학교ordinal을시험시각으로변환하지않고실제월일원문에따릅니다.'
 if key=='FTM2082-01':note+=' 자체2026-2 유준오 강좌는대면/오프라인자체문구가없으므로사용자선택유형을따릅니다.전체4페이지15주실습워크숍·수업내제작참여·교수크리틱·동료발표 확인했습니다.9주차explicit국립현대미술관외부수업과미기재16주차는예약제외하며현장시각발명0입니다.8중간프로젝트발표와15기말발표는교수/동료피드백교육수업으로예약합니다.원문가상공간/실시간3D는교육주제이며실시간온라인수업유형이라고오인하지않습니다.'
 course.update(schedules=dates,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':start.isoformat(),'endDate':end.isoformat()},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks'])
 course['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};course['reservationEvidenceV18']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':full,'excludedOrdinalWeeks':exclude[key],'ordinalIsDerivedExclusionNotConfirmedExamDate':True,'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':None,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'calendarRules':rules}
 changed={'schedules','scheduleStatus','unresolvedReasons','researchOnly','scheduleEvidenceKind','actualAttendanceConfirmed','commonClosureDatesApplied','partialCoverage','period','departmentRemarks'}
 for field in prior:
  if field not in changed:assert prior[field]==course[field]
 proof.append({'sourceId':course['sourceId'],'offeringCode':key,'newMeetings':len(dates),'excludedOrdinalWeeks':exclude[key],'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':None})
for campus,b in baselines.items():
 for old,new in zip(b['courses'],candidates[campus]['courses']):
  if old['courseCode']+'-'+old['section'] not in sources:assert old==new
 candidates[campus]['completionClaim']=False
 if any(x['courseCode']+'-'+x['section'] in sources for x in b['courses']):(p/f'skku-{campus}-2026-2.own-operation-v18.json').write_text(json.dumps(candidates[campus],ensure_ascii=False,indent=2)+'\n')
assert len(proof)==2
(p/'new-two-scoped-proof.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'byCourse':proof,'newCourses':2,'newMeetings':sum(a['newMeetings'] for a in proof)},ensure_ascii=False,indent=2)+'\n');print(proof)
