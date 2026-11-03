import json,pathlib,copy,datetime
p=pathlib.Path(__file__).parent
read=lambda n:json.loads((p/n).read_text())
baselines={campus:read(f'baseline-skku-{campus}-2026-2.json') for campus in ['humanities','naturalScience','icampus']};candidates=copy.deepcopy(baselines);sources={r['offeringCode']:r for r in read('source-two-full-attachment-identities.json')['records']};rules=read('own-current-term-closure-evidence.json');start=datetime.date.fromisoformat(rules['term']['startDate']);end=datetime.date.fromisoformat(rules['term']['endDate']);closed=set(rules['closureRule']['schoolSpecificClosures']+rules['nationalHolidayDates']['dates'])
exclude=read('reviewed-exclusion-rules.json')
literal={'ART2061-01':['09-04','09-11','09-18','10-16','10-30','11-06','11-13','11-20','11-27','12-04','12-11']}
fulls={k:read(n) for k,n in [('ART2061-01','art2061-01-full-education.json'),('FTM2071-02','ftm2071-02-full-education.json')]}
proof=[]
for course in [c for dataset in candidates.values() for c in dataset['courses']]:
 key=course['courseCode']+'-'+course['section']
 if key not in sources:continue
 r=sources[key];full=fulls[key];assert full['privateLinesOmitted']==0 and key in full['educationFullText'] and '2026' in full['educationFullText'];text=full['educationFullText'];pattern=r'(\d+)주차' if key=='ART2061-01' else r'주차(\d+)';expectedWeeks=list(range(1,16)) if key=='ART2061-01' else list(range(1,17));assert [int(x) for x in __import__('re').findall(pattern,text)][:len(expectedWeeks)]==expectedWeeks;d=r['detail'][0];assert d['PER_NAME'] in full['educationFullText'];assert (d['GAESUL_YEAR'],d['GAESUL_TERM'],d['HAKSU_NO'],d['BUNBAN'],d['PER_NAME'])==('2026','20',course['courseCode'],course['section'],course['professor']);assert r['sourceRow']['GYOSI_NAME']==course['sourceSchedule'];assert not course['schedules']
 online=['2026-10-02','2026-10-09','2026-10-23'] if key=='ART2061-01' else []
 prior=copy.deepcopy(course);dates=[];day=start
 while day<=end:
  week=(day-start).days//7+1
  if day.isoformat() not in closed and week not in exclude[key] and (key not in literal or day.strftime('%m-%d') in literal[key]):
   dates.extend({**f,'date':day.isoformat(),'deliveryMode':'inPerson'} for f in course['rawMeetingFrameForReviewOnly'] if f['weekday']==day.isoweekday())
  day+=datetime.timedelta(days=1)
 note='현재2026-2 해당 분반의 자체 전체16주 운영표와 학교 네이티브 수업시각·강의실에 따른 정규 대면 예약입니다. 실제 출석·시험·미확정 보강 시각은 확정하지 않았습니다. 제외 주차 '+','.join(map(str,exclude[key]))+'는 원문 시험/휴강/보강·자율학습/개별상담 또는 날짜충돌 구간입니다. 학교 공식8/31 시작의 7일 단위 주차 대응은 예약 제외 경계이며 실제 시험 날짜라는 주장이 아닙니다.'
 note+=' 사전영상·휴일 온라인 보강·별도 현장/상담/과제 등 미확정 운영조건은 원문 그대로 보존하며 대면 예약으로 생성하지 않습니다.'
 note+=' 각강좌 자체 사전영상/고정 대면구간 또는 오프라인 강좌구분을 확인했습니다. 단일1.5OFF 또는3hOFF native구간은 원문HH 그대로 사용하며 사전제작영상은 주간예약으로 생성하지 않습니다.'
 if key=='ART2061-01':note+=' 자체2026-2 교수김지영 전체HWP의15개교육주 모두실제월일확인했습니다.10/2·10/9·10/23 자체사전제작강의와9/25추석·12/18시험을예약하지않고,나머지11일 자체강의·발표·토론을 네이티브강의실구간으로연결합니다.별도미술관자율방문과11/22과제제출을수업예약으로생성하지않습니다. 자체주차번호는추석후1주밀림을그대로보존하고학교ordinal로대체하지않습니다.'
 if key=='FTM2071-02':note+=' 자체2026-2 교수문성환 전체1페이지 강의계획서16주를확인했습니다.빔프로젝트이용강의·개별실습·과제토론실제강의실운영이며4추석휴강만제외합니다.8·15·16주차도과제토론교육이며임의시험으로제외하지않습니다.모든실습자료의외부유출금지안내는원문에보존하며실습자료는수집하지않았습니다.'
 course.update(schedules=dates,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':start.isoformat(),'endDate':end.isoformat()},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks'])
 course['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};course['reservationEvidenceV17']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':full,'excludedOrdinalWeeks':exclude[key],'ordinalIsDerivedExclusionNotConfirmedExamDate':True,'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':None,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'calendarRules':rules}
 changed={'schedules','scheduleStatus','unresolvedReasons','researchOnly','scheduleEvidenceKind','actualAttendanceConfirmed','commonClosureDatesApplied','partialCoverage','period','departmentRemarks'}
 for field in prior:
  if field not in changed:assert prior[field]==course[field]
 proof.append({'sourceId':course['sourceId'],'offeringCode':key,'newMeetings':len(dates),'excludedOrdinalWeeks':exclude[key],'recordedDatesHeld':online,'exactLiteralDates':literal.get(key), 'limitedExplicitOfflineWeeks':None})
for campus,b in baselines.items():
 for old,new in zip(b['courses'],candidates[campus]['courses']):
  if old['courseCode']+'-'+old['section'] not in sources:assert old==new
 candidates[campus]['completionClaim']=False
 if any(x['courseCode']+'-'+x['section'] in sources for x in b['courses']):(p/f'skku-{campus}-2026-2.own-operation-v17.json').write_text(json.dumps(candidates[campus],ensure_ascii=False,indent=2)+'\n')
assert len(proof)==2
(p/'new-two-scoped-proof.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'byCourse':proof,'newCourses':2,'newMeetings':sum(a['newMeetings'] for a in proof)},ensure_ascii=False,indent=2)+'\n');print(proof)
