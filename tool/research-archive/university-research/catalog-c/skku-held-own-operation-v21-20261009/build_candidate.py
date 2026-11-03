import json,pathlib,copy,datetime
p=pathlib.Path(__file__).parent
read=lambda n:json.loads((p/n).read_text())
baselines={campus:read(f'baseline-skku-{campus}-2026-2.json') for campus in ['humanities','naturalScience','icampus']};candidates=copy.deepcopy(baselines);sources={r['offeringCode']:r for r in read('source-two-full-attachment-identities.json')['records']};rules=read('own-current-term-closure-evidence.json');start=datetime.date.fromisoformat(rules['term']['startDate']);end=datetime.date.fromisoformat(rules['term']['endDate']);closed=set(rules['closureRule']['schoolSpecificClosures']+rules['nationalHolidayDates']['dates'])
exclude=read('reviewed-exclusion-rules.json')
literal={'ADD2003-41':['09-02','09-09','09-16','09-23','09-30','10-07','10-14','10-21','10-28','11-04','11-11','11-18','11-25','12-02','12-09','12-16'],'COS2020-01':['09-01','09-08','09-10','09-15','09-17','09-29','10-01','10-13','10-15','10-27','10-29','11-24','11-26','12-01','12-03','12-08','12-10']}
fulls={k:read(n) for k,n in [('ADD2003-41','add2003-41-full-education.json'),('COS2020-01','cos2020-01-full-education.json')]}
proof=[]
for course in [c for dataset in candidates.values() for c in dataset['courses']]:
 key=course['courseCode']+'-'+course['section']
 if key not in sources:continue
 r=sources[key];full=fulls[key];assert full['privateLinesOmitted']==0 and key in full['educationFullText'] and '2026' in full['educationFullText'];text=full['educationFullText'];pattern=r'(\d+)\s*주차';expectedWeeks=list(range(1,17));assert [int(x) for x in __import__('re').findall(pattern,text[text.index('수   업   내   용'):])][:len(expectedWeeks)]==expectedWeeks;d=r['detail'][0];assert d['PER_NAME'] in full['educationFullText'];assert (d['GAESUL_YEAR'],d['GAESUL_TERM'],d['HAKSU_NO'],d['BUNBAN'],d['PER_NAME'])==('2026','20',course['courseCode'],course['section'],course['professor']);assert r['sourceRow']['GYOSI_NAME']==course['sourceSchedule'];assert not course['schedules']
 online=[]
 prior=copy.deepcopy(course);dates=[];day=start
 while day<=end:
  week=(day-start).days//7+1
  if day.isoformat() not in closed and week not in exclude[key] and (key not in literal or day.strftime('%m-%d') in literal[key]):
   dates.extend({**f,'date':day.isoformat(),'deliveryMode':'inPerson'} for f in course['rawMeetingFrameForReviewOnly'] if f['weekday']==day.isoweekday())
  day+=datetime.timedelta(days=1)
 note='현재2026-2 해당 분반의 자체 전체16주 운영표와 학교 네이티브 수업시각·강의실에 따른 정규 대면 예약입니다. 실제 출석·시험·미확정 보강 시각은 확정하지 않았습니다. 제외 주차 '+','.join(map(str,exclude[key]))+'는 원문 시험/휴강/보강·자율학습/개별상담 또는 날짜충돌 구간입니다. 학교 공식8/31 시작의 7일 단위 주차 대응은 예약 제외 경계이며 실제 시험 날짜라는 주장이 아닙니다.'
 note+=' 사전영상·휴일 온라인 보강·별도 현장/상담/과제 등 미확정 운영조건은 원문 그대로 보존하며 대면 예약으로 생성하지 않습니다.'
 note+=' 각강좌 자체 사전영상/고정 대면구간 또는 오프라인 강좌구분을 확인했습니다. 단일1.5OFF 또는3hOFF native구간은 원문HH 그대로 사용하며 사전제작영상은 주간예약으로 생성하지 않습니다.'
 if key=='ADD2003-41':note+=' 자체2026-2 이중호 전체HWP16실제수요일월일교육계획을확인했습니다.학교native오프라인분류와9/2~12/16 actual16일공동강의·분반실습·스튜디오·전시/리뷰를각4개native75분HHroom22525로연결합니다.8·16주차도전시/리뷰교육이므로시험으로임의제외하지않습니다.개론의현장답사일반설명은보존하지만별도현장일정/HH로확대하지않습니다.'
 if key=='COS2020-01':note+=' 자체2026-2 김병목전체HWP16온오프운영표와첫주9/1(화)하루만대면실제운영을확인했습니다.그actual첫주요일·날짜와학교8/31학기시작이동일주차를지정하며그기준으로후속정규1~16주를따릅니다.오프라인1·2·3·5·7·9·13·14·15주차만native화15–16:15/목16:30–17:45room31606에연결하고첫9/3목요일은제외합니다.온라인4·6·10·11·12·16과8중간고사및과제미확정마감은예약생성0입니다.동일학교학기기준에의한주차대응은예정교육일정이며실제출석/변경안내나시험날짜확정이아닙니다.'
 course.update(schedules=dates,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':start.isoformat(),'endDate':end.isoformat()},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks'])
 course['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};course['reservationEvidenceV21']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':full,'excludedOrdinalWeeks':exclude[key],'ordinalIsDerivedExclusionNotConfirmedExamDate':True,'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':None,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'calendarRules':rules}
 changed={'schedules','scheduleStatus','unresolvedReasons','researchOnly','scheduleEvidenceKind','actualAttendanceConfirmed','commonClosureDatesApplied','partialCoverage','period','departmentRemarks'}
 for field in prior:
  if field not in changed:assert prior[field]==course[field]
 proof.append({'sourceId':course['sourceId'],'offeringCode':key,'newMeetings':len(dates),'excludedOrdinalWeeks':exclude[key],'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':None})
for campus,b in baselines.items():
 for old,new in zip(b['courses'],candidates[campus]['courses']):
  if old['courseCode']+'-'+old['section'] not in sources:assert old==new
 candidates[campus]['completionClaim']=False
 if any(x['courseCode']+'-'+x['section'] in sources for x in b['courses']):(p/f'skku-{campus}-2026-2.own-operation-v21.json').write_text(json.dumps(candidates[campus],ensure_ascii=False,indent=2)+'\n')
assert len(proof)==2
(p/'new-two-scoped-proof.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'byCourse':proof,'newCourses':2,'newMeetings':sum(a['newMeetings'] for a in proof)},ensure_ascii=False,indent=2)+'\n');print(proof)
