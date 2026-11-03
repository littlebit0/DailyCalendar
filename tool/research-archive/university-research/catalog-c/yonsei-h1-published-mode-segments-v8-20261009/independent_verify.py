import pathlib,json,hashlib,datetime as dt,collections
p=pathlib.Path(__file__).parent;load=lambda f:json.loads(f.read_text())
literal={1:['2026-09-07','2026-09-14','2026-09-21','2026-09-28','2026-10-12','2026-10-19','2026-11-02','2026-11-09','2026-11-16','2026-11-23','2026-11-30','2026-12-07'],2:['2026-09-01','2026-09-08','2026-09-15','2026-09-22','2026-09-29','2026-10-06','2026-10-13','2026-10-27','2026-11-03','2026-11-10','2026-11-17','2026-11-24','2026-12-01'],3:['2026-09-02','2026-09-09','2026-09-16','2026-09-23','2026-09-30','2026-10-07','2026-10-14','2026-10-28','2026-11-04','2026-11-11','2026-11-18','2026-11-25','2026-12-02'],4:['2026-09-03','2026-09-10','2026-09-17','2026-10-01','2026-10-08','2026-10-15','2026-10-29','2026-11-05','2026-11-12','2026-11-19','2026-11-26','2026-12-03'],5:['2026-09-04','2026-09-11','2026-09-18','2026-10-02','2026-10-16','2026-10-30','2026-11-06','2026-11-13','2026-11-20','2026-11-27','2026-12-04']}
clocks={0:(480,530),1:(540,590),2:(600,650),3:(660,710),4:(720,770),5:(780,830),6:(840,890),7:(900,950),8:(960,1010),9:(1020,1070),10:(1080,1130)}
rows=[];priorScheduled=0;priorMeetings=0;unchanged=0;newplans=0;newmodes=collections.Counter()
for basefile in sorted(p.glob('baseline-yonsei-*-2026-2.json')):
 base=load(basefile);file=p/(basefile.name.replace('baseline-','').replace('.json','.mode-segments-v8.json'));new=load(file);assert len(new['courses'])==len(base['courses']);old={c['sourceId']:c for c in base['courses']};assert len(old)==len(base['courses'])
 if base['campus'] in ['mirae','unknown']:assert file.read_bytes()==basefile.read_bytes()
 for c in new['courses']:
  b=old[c['sourceId']]
  if c==b:unchanged+=1;priorScheduled+=bool(b['schedules']);priorMeetings+=len(b['schedules']);continue
  assert not b['schedules'] and c['partialCoverage'] and c['sourceEducation']==b['sourceEducation']
  for k in b:
   if k not in ['schedules','scheduleStatus','remarks','departmentRemarks']:assert c[k]==b[k]
  assert c['priorHeldResearchRemarks']==b['remarks'] and c['priorHeldDepartmentRemarks']==b['departmentRemarks']
  assert c['sourceEducation'][0]['sysinstDivCd']=='H1' and not c['courseCode'].startswith('UCR')
  times=b['sourceSchedule'].split('/');rooms=b['sourceClassroom'].split('/');assert len(times)==len(rooms)==len(c['publishedModeSegments'])
  expected=[]
  for i,(time,room) in enumerate(zip(times,rooms)):
   seg=c['publishedModeSegments'][i];assert seg['index']==i and seg['nativeTime']==time and seg['nativeRoom']==room
   if room in ['동영상콘텐츠','동영상(중복수강불가)']:
    assert seg['operation']=='recordedVideoHeld' and not seg['timedReservationsGenerated'] and seg['overlapPermitted']==(room=='동영상콘텐츠');continue
   if any(x in time+room for x in '()') or not room or any(x in room for x in ['미정','미배정','동영상','콘텐츠']):assert seg['operation']=='unconfirmedHeld';continue
   slots=[];wd=None;valid=True
   for token in time.split(','):
    if token and token[0] in '월화수목금토':wd='월화수목금토'.index(token[0])+1;token=token[1:]
    if wd is None or not token.isdecimal() or int(token) not in clocks:valid=False;break
    slots.append((wd,int(token)))
   if not valid or not slots:assert seg['operation']=='unconfirmedHeld';continue
   mode='liveOnline' if room=='실시간온라인' else 'inPerson';assert seg['operation']==mode
   for wd,period in slots:
    assert wd in literal
    for date in literal[wd]:expected.append((date,wd,*clocks[period],room,mode,i,period))
  actual=[(s['date'],s['weekday'],s['startMinute'],s['endMinute'],s['classroom'],s['deliveryMode'],s['sourceGroupIndex'],s['sourcePeriod']) for s in c['schedules']]
  assert set(actual)==set(expected) and len(actual)==len(expected)==len(set(actual))
  assert all(dt.date.fromisoformat(s[0]).isoweekday()==s[1] for s in actual)
  newplans+=len(actual);newmodes.update(s[5] for s in actual);rows.append({'sourceId':c['sourceId'],'expectedLiteralPlans':len(expected),'nativeSourceGroupsPreserved':len(times),'exactIndependentActualFramesEqual':True})
assert len(rows)==359 and newplans==6607 and priorScheduled==2722 and priorMeetings==97066 and unchanged==4351
(p/'independent359-literal-preservation-proof.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'new359LiteralDatesAndNativeGroupsPassed':True,'allOther4351WholeObjectsEqual':True,'prior2722WholeCourses97066MeetingsUnchanged':True,'otherTwoCampusWholeBytesEqual':True,'newPartialCourses':359,'newTimedMeetings':6607,'sourceForcedMeetingModes':dict(newmodes),'totalScheduled':3081,'totalMeetings':103673,'literalDates':literal,'independentClockLiterals':clocks,'proofByCourse':rows},ensure_ascii=False,indent=2)+'\n')
print('Independent359 nativeparts/literal6607 passed; prior2722/97066 wholeequal; other4351 wholeequal; total3081/103673')
