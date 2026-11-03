import json,pathlib,hashlib,copy,re,datetime,collections
P=pathlib.Path('work/university-research/resume-20261011/khu')
base=pathlib.Path('work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1')
registry=base/'whole1917-original-registry.json'
xs=json.loads(registry.read_text())
inputs=json.loads(pathlib.Path('work/university-research/resume-batch-20261010/source-inputs.json').read_text())
current={};sourceCounts=[]
for item in inputs:
 if not item['target'].startswith('assets/timetable/khu-'):continue
 src=json.loads(pathlib.Path(item['source']).read_text());asset=pathlib.Path(item['target']);dst=json.loads(asset.read_text());sm={c['sourceId']:c for c in src['courses']};tm={c['sourceId']:c for c in dst['courses']};current.update(tm)
 sourceCounts.append({'asset':str(asset),'assetSHA256':hashlib.sha256(asset.read_bytes()).hexdigest(),'source':item['source'],'sourceSHA256':hashlib.sha256(pathlib.Path(item['source']).read_bytes()).hexdigest(),'sourceCourseCount':len(sm),'assetCourseCount':len(tm),'sourceScheduledMissingInAsset':[sid for sid,c in sm.items() if c.get('schedules') and not tm.get(sid,{}).get('schedules')],'heldWithClock':sum(not c.get('schedules') and bool(re.search(r'\d{2}:\d{2}',c['sourceSchedule'])) for c in tm.values()),'heldWithoutClock':sum(not c.get('schedules') and not re.search(r'\d{2}:\d{2}',c['sourceSchedule']) for c in tm.values())})
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
rows=[]
for ordinal,start,end,room in [(34,990,1065,'정301'),(1643,540,615,'공146호')]:
 x=xs[ordinal-1];source=x['plans'][0];plan=source['originalWholeEducationPlan'];cur=current[x['originalWholeObject']['sourceId']];sec={s['section']:s['rows'] for s in plan['educationalSections']};meetings=[];allowed=[];excluded=[]
 for row in sec['주별강의내용']:
  if not re.fullmatch(r'\d+주',row[0]):continue
  week=int(row[0][:-1]);m=re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',row[1]);a=datetime.date(2026,int(m[1]),int(m[2]));b=datetime.date(2026,int(m[3]),int(m[4]));day=a+datetime.timedelta(days=(1-a.isoweekday())%7)
  if week in [8,16]:excluded.append({'week':week,'row':row,'reason':'Own explicitly labelled midterm/final exam week'});continue
  if day.isoformat() in closed:excluded.append({'week':week,'row':row,'date':day.isoformat(),'reason':'Own calendar public holiday; no substitute class inferred'});continue
  meetings.append({'date':day.isoformat(),'weekday':1,'startMinute':start,'endMinute':end,'classroom':room});allowed.append({'week':week,'row':row,'matchedDate':day.isoformat()})
 proposed=copy.deepcopy(cur);proposed['schedules']=meetings;proposed['scheduleStatus']='scheduled';proposed['sourcePartialCoverage']=True
 proposed['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'resume20261011_partial_teacher_clock_only','unmatchedNativeWeekdaysHeld':[3]}
 rows.append({'ordinal':ordinal,'sourceId':cur['sourceId'],'asset':f"assets/timetable/khu-{cur['campus']}-2026-2.json",'originalWholeObject':cur,'proposedWholeObject':proposed,'sourceFile':source['file'],'sourceSHA256':hashlib.sha256(pathlib.Path(source['file']).read_bytes()).hexdigest(),'wholeEducationPlan':plan,'matchedOwnClock':next(r[1] for r in sec['기본정보'] if r[0]=='강의시간강의실'),'wholeOperationRows':sec['수업운영방식'],'wholeMethodRows':sec['수업유형 및 방법'],'allowedLiteralRows':allowed,'excludedLiteralRows':excluded,'unmatchedNativeClockHeld':'Wednesday group absent from named professor plan; placeholder .. allocation remains unknown','mode':'physical_user_preference_preserved','newMeetings':len(meetings),'approvalScope':'Source candidate only; parent integration/review required. Not an entire course/university completion claim.'})
(P/'partial-clock-candidates.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
receipt={'scope':'Existing KHU acquired sources only; no network/source rerequest, product/shared writes, SDK/test/build or validation execution','registry':str(registry),'registrySHA256':hashlib.sha256(registry.read_bytes()).hexdigest(),'sourceInputComparisons':sourceCounts,'projectionLostScheduledRows':0,'candidateCourses':len(rows),'candidateDatedMeetings':sum(x['newMeetings'] for x in rows),'wholeCourseRestored':False,'excludedKnownOnlineBLUncertainty':'Existing online/BL/recorded ambiguities were not re-investigated. Selected candidates have own explicit physical basis and own professor Monday clocks.','heldExample':{'sourceId':'khu/2026/2/global/SM32900','reason':'Native classroom205 versus AT-center practice and alternating theory/practice weekday unassigned; no guessed meeting location or weekday'},'completionClaim':False,'productChanged':False}
(P/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'candidateCourses':len(rows),'candidateMeetings':sum(x['newMeetings'] for x in rows),'sourceCounts':sourceCounts},ensure_ascii=False))
