import json,pathlib,copy,datetime
p=pathlib.Path(__file__).parent
read=lambda n:json.loads((p/n).read_text())
baselines={campus:read(f'baseline-skku-{campus}-2026-2.json') for campus in ['humanities','naturalScience','icampus']};candidates=copy.deepcopy(baselines);sources={r['offeringCode']:r for r in read('source-fifteen-full-inline.json')['records']};rules=read('own-current-term-closure-evidence.json');start=datetime.date.fromisoformat(rules['term']['startDate']);end=datetime.date.fromisoformat(rules['term']['endDate']);closed=set(rules['closureRule']['schoolSpecificClosures']+rules['nationalHolidayDates']['dates'])
exclude={'BUS2006-07':[8,15,16],'BUS2014-01':[8,15,16],'ECO3032-01':[5,8,16],'DKL2009-01':[8,10,16],'PSY3040-01':[8,15,16],'PHL2007-01':[8,16],'FRE2003-01':[8,15,16],'HAN2004-01':[8,16],'HAN2021-01':[8,16],'SWF3060-01':[16],'CON4016-01':[],'CNT2003-01':[4,16],'COS3098-01':[],'DKL3054-01':[],'IAI3015-41':[]}
literal={'COS3098-01':['09-01','09-03','09-08','09-10','09-15','09-17','09-22','09-29','10-01','10-13','10-15','10-20','10-22','10-27','10-29','11-03','11-05','11-10','11-12','11-17','11-19','11-24','11-26','12-01','12-08','12-10','12-15','12-17'],'DKL3054-01':['08-31','09-07','09-14','09-21','10-12','10-19','11-09','11-16','11-23','11-30','12-07']}
proof=[]
for course in [c for dataset in candidates.values() for c in dataset['courses']]:
 key=course['courseCode']+'-'+course['section']
 if key not in sources:continue
 r=sources[key];d=r['detail'][0];assert (d['GAESUL_YEAR'],d['GAESUL_TERM'],d['HAKSU_NO'],d['BUNBAN'],d['PER_NAME'])==('2026','20',course['courseCode'],course['section'],course['professor']);assert r['sourceRow']['GYOSI_NAME']==course['sourceSchedule'];assert len(r['weekly'])==16 and not r['attachments'] and not course['schedules'];assert all(w['GAESUL_YEAR']=='2026' and w['GAESUL_TERM']=='20' and w['HAKSU_NO']==course['courseCode'] and w['BUNBAN']==course['section'] and w['privacySuppressedLineCount']==0 for w in r['weekly']);assert [int(w['PLAN_WEEK_CNT']) for w in r['weekly']]==list(range(1,17))
 online=[]
 prior=copy.deepcopy(course);dates=[];day=start
 while day<=end:
  week=(day-start).days//7+1
  if day.isoformat() not in closed and week not in exclude[key] and (key not in literal or day.strftime('%m-%d') in literal[key]) and (key!='CON4016-01' or week in [7,9]) and (key!='IAI3015-41' or week==1):
   dates.extend({**f,'date':day.isoformat(),'deliveryMode':'inPerson'} for f in course['rawMeetingFrameForReviewOnly'] if f['weekday']==day.isoweekday())
  day+=datetime.timedelta(days=1)
 note='현재2026-2 해당 분반의 자체 전체16주 운영표와 학교 네이티브 수업시각·강의실에 따른 정규 대면 예약입니다. 실제 출석·시험·미확정 보강 시각은 확정하지 않았습니다. 제외 주차 '+','.join(map(str,exclude[key]))+'는 원문 시험/휴강/보강·자율학습/개별상담 또는 날짜충돌 구간입니다. 학교 공식8/31 시작의 7일 단위 주차 대응은 예약 제외 경계이며 실제 시험 날짜라는 주장이 아닙니다.'
 note+=' 사전영상·휴일 온라인 보강·별도 현장/상담/과제 등 미확정 운영조건은 원문 그대로 보존하며 대면 예약으로 생성하지 않습니다.'
 if key=='COS3098-01':note+=' 원문에 날짜가 직접 명시된28일만 예약합니다. 10/6·10/8·12/3 온라인과9/24추석을 제외합니다. 16주차12/15·12/17은 원문 정규강의/발표이지 새 시험시각이 아닙니다.'
 if key=='DKL3054-01':note+=' 원문에 날짜와 월요일 대면이 명시된11일만 예약합니다. 11/07 금요일 표기는 실제토요일이며 네이티브월요일과도 충돌하여 해당행을 보류했습니다. 10/26중간시험과12/14온라인 기말시험은 생성하지 않습니다.'
 if key=='CON4016-01':note+=' 원문Offline가 직접표시된7·9주차만 예약합니다. 나머지 프로젝트/녹화/온라인/실시간은 실제배정 미확정이므로 그대로 보류합니다.'
 if key=='IAI3015-41':note+=' 원문1주차 대면 오리엔테이션만 예약합니다. 발표4회·출결4회와 오리엔테이션의 포함관계가 미확정이므로 다른 주차는 예약하지 않습니다.'
 if key=='SWF3060-01':note+=' 자체화요일10:30–11:45 실시간대면 기본계획과 일치합니다. 특정주차 비중변경은 별도공지 예정이라는 원문주의를 유지하며 실제출석/향후변경완료를 주장하지 않습니다.'
 course.update(schedules=dates,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':start.isoformat(),'endDate':end.isoformat()},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks'])
 course['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};course['reservationEvidenceV9']={'exactCurrentPublicSource':r,'excludedOrdinalWeeks':exclude[key],'ordinalIsDerivedExclusionNotConfirmedExamDate':True,'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':[7,9] if key=='CON4016-01' else [1] if key=='IAI3015-41' else None,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'calendarRules':rules}
 changed={'schedules','scheduleStatus','unresolvedReasons','researchOnly','scheduleEvidenceKind','actualAttendanceConfirmed','commonClosureDatesApplied','partialCoverage','period','departmentRemarks'}
 for field in prior:
  if field not in changed:assert prior[field]==course[field]
 proof.append({'sourceId':course['sourceId'],'offeringCode':key,'newMeetings':len(dates),'excludedOrdinalWeeks':exclude[key],'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':[7,9] if key=='CON4016-01' else [1] if key=='IAI3015-41' else None})
for campus,b in baselines.items():
 for old,new in zip(b['courses'],candidates[campus]['courses']):
  if old['courseCode']+'-'+old['section'] not in sources:assert old==new
 candidates[campus]['completionClaim']=False
 if any(x['courseCode']+'-'+x['section'] in sources for x in b['courses']):(p/f'skku-{campus}-2026-2.own-operation-v9.json').write_text(json.dumps(candidates[campus],ensure_ascii=False,indent=2)+'\n')
assert len(proof)==15
(p/'new-fifteen-scoped-proof.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'byCourse':proof,'newCourses':15,'newMeetings':sum(a['newMeetings'] for a in proof)},ensure_ascii=False,indent=2)+'\n');print(proof)
