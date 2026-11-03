import json,pathlib,copy,datetime
p=pathlib.Path(__file__).parent
read=lambda n:json.loads((p/n).read_text())
baselines={campus:read(f'baseline-skku-{campus}-2026-2.json') for campus in ['humanities','naturalScience','icampus']};candidates=copy.deepcopy(baselines);sources={r['offeringCode']:r for r in read('source-two-full-attachment-identities.json')['records']};rules=read('own-current-term-closure-evidence.json');start=datetime.date.fromisoformat(rules['term']['startDate']);end=datetime.date.fromisoformat(rules['term']['endDate']);closed=set(rules['closureRule']['schoolSpecificClosures']+rules['nationalHolidayDates']['dates'])
exclude=read('reviewed-exclusion-rules.json')
literal={'SKD3049-01':['09-04','09-11','09-18','10-02','10-23','10-30','11-06','11-13','12-11','12-18']}
fulls={k:read(n) for k,n in [('SKD3049-01','skd3049-01-full-education.json'),('SOA3001-01','soa3001-01-full-education.json')]}
proof=[]
for course in [c for dataset in candidates.values() for c in dataset['courses']]:
 key=course['courseCode']+'-'+course['section']
 if key not in sources:continue
 r=sources[key];full=fulls[key];assert full['privateLinesOmitted']==(0 if key=='SKD3049-01' else 1) and key in full['educationFullText'] and '2026' in full['educationFullText'];text=full['educationFullText'];pattern=r'(\d+)\s*주차\s*\d{1,2}/\d{1,2}' if key=='SKD3049-01' else r'(\d+)\s*주차';expectedWeeks=list(range(1,17));assert [int(x) for x in __import__('re').findall(pattern,text[text.index('수   업   내   용'):])][:len(expectedWeeks)]==expectedWeeks;d=r['detail'][0];assert d['PER_NAME'] in full['educationFullText'];assert (d['GAESUL_YEAR'],d['GAESUL_TERM'],d['HAKSU_NO'],d['BUNBAN'],d['PER_NAME'])==('2026','20',course['courseCode'],course['section'],course['professor']);assert r['sourceRow']['GYOSI_NAME']==course['sourceSchedule'];assert not course['schedules']
 online=[]
 prior=copy.deepcopy(course);dates=[];day=start
 while day<=end:
  week=(day-start).days//7+1
  if day.isoformat() not in closed and week not in exclude[key] and (key not in literal or day.strftime('%m-%d') in literal[key]):
   dates.extend({**f,'date':day.isoformat(),'deliveryMode':'inPerson' if key=='SKD3049-01' and day.isoformat()=='2026-09-04' else None} for f in course['rawMeetingFrameForReviewOnly'] if f['weekday']==day.isoweekday())
  day+=datetime.timedelta(days=1)
 note='현재2026-2 해당 분반의 자체 전체16주 운영표와 학교 네이티브 수업시각·강의실에 따른 정규 대면 예약입니다. 실제 출석·시험·미확정 보강 시각은 확정하지 않았습니다. 제외 주차 '+','.join(map(str,exclude[key]))+'는 원문 시험/휴강/보강·자율학습/개별상담 또는 날짜충돌 구간입니다. 학교 공식8/31 시작의 7일 단위 주차 대응은 예약 제외 경계이며 실제 시험 날짜라는 주장이 아닙니다.'
 note+=' 사전영상·휴일 온라인 보강·별도 현장/상담/과제 등 미확정 운영조건은 원문 그대로 보존하며 대면 예약으로 생성하지 않습니다.'
 note+=' 각강좌 자체 사전영상/고정 대면구간 또는 오프라인 강좌구분을 확인했습니다. 단일1.5OFF 또는3hOFF native구간은 원문HH 그대로 사용하며 사전제작영상은 주간예약으로 생성하지 않습니다.'
 if key=='SKD3049-01':note+=' 자체2026-2 주현아 전체2페이지16개실제월일운영표를확인했습니다.첫9/4대면수업필수참석은inPerson,나머지9일교내이론·실습계획·발표·성찰·동료컨설팅/교수피드백세미나는유형명시가없어사용자선택유형을따릅니다.9/25·10/9휴일및10/16현장탐방과11/20~12/4교육기관현장실습은native교내HH로생성하지않습니다.현장협의·공연일정에따른변경가능성을원문그대로보존합니다. 실제모둠명단·출결·실습자료조회0입니다.'
 if key=='SOA3001-01':note+=' 자체2026-2 임성민·박유진 공동교수전체4페이지16주지역연계팀프로젝트교육표를확인했습니다.직접출석·수업참여·조활동 및7중간발표·16기말발표명시로학교native목요일강의실예정예약이며대면/오프라인자체명시가없어사용자선택유형을따릅니다.4주차9/24추석휴강제외하고15dates30회의정규교육만예약합니다.프로젝트외부현장/팀별개별일정과행정제출마감시각은발명하지않습니다. 원문공동교수명은보존하고학교native단일교수필드는교체하지않습니다.'
 course.update(schedules=dates,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':start.isoformat(),'endDate':end.isoformat()},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks'])
 course['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};course['reservationEvidenceV20']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':full,'excludedOrdinalWeeks':exclude[key],'ordinalIsDerivedExclusionNotConfirmedExamDate':True,'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':None,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'calendarRules':rules}
 changed={'schedules','scheduleStatus','unresolvedReasons','researchOnly','scheduleEvidenceKind','actualAttendanceConfirmed','commonClosureDatesApplied','partialCoverage','period','departmentRemarks'}
 for field in prior:
  if field not in changed:assert prior[field]==course[field]
 proof.append({'sourceId':course['sourceId'],'offeringCode':key,'newMeetings':len(dates),'excludedOrdinalWeeks':exclude[key],'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':None})
for campus,b in baselines.items():
 for old,new in zip(b['courses'],candidates[campus]['courses']):
  if old['courseCode']+'-'+old['section'] not in sources:assert old==new
 candidates[campus]['completionClaim']=False
 if any(x['courseCode']+'-'+x['section'] in sources for x in b['courses']):(p/f'skku-{campus}-2026-2.own-operation-v20.json').write_text(json.dumps(candidates[campus],ensure_ascii=False,indent=2)+'\n')
assert len(proof)==2
(p/'new-two-scoped-proof.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'byCourse':proof,'newCourses':2,'newMeetings':sum(a['newMeetings'] for a in proof)},ensure_ascii=False,indent=2)+'\n');print(proof)
