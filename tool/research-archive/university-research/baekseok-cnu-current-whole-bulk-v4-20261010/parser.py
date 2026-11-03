import pathlib,json,copy,hashlib,re,datetime as dt,collections
R=pathlib.Path.cwd();W=R/'work/university-research';D=W/'baekseok-cnu-current-whole-bulk-v3-20261010';D.mkdir(exist_ok=False);sources={};proof=[];queue=[];datasets=[];archive={}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):sources[str(p.relative_to(R))]={'bytes':p.stat().st_size,'sha256':sha(p)};return json.loads(p.read_text())
def dump(n,x):(D/n).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
read(W/'catalog-c/baekseok-general-clock-review-20261009/current-public-clock-audit.json')
read(W/'catalog-f/cnu-2026-2-exchange-guide-selected-education.json')
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09','2026-12-08','2026-12-09','2026-12-10','2026-12-11'}
constraint=re.compile(r'집중\s*(수업|이수|강의)|격주\s*(수업|강의|진행)|휴강|보강|수업\s*없|no\s*class|make.?up\s*class|비대면\s*(강의|수업)|온라인\s*(강의|수업)|원격\s*(강의|수업)|사이버\s*강의|녹화\s*(강의|수업)|비실시간|실시간|VOD|\b(?:online|remote|hybrid|blended|asynchronous|synchronous|recorded)\s+(?:class|lecture|course)|\b(?:class|lecture).{0,20}(?:via|using)\s*(?:zoom|teams)|개별\s*(레슨|지도|실습|수업|시간|협의)|개인별\s*(배정|협의|시간)|별도\s*(시간|일정|협의|배정)|교수.{0,8}협의|현장\s*(실습|견학|수업)|임상\s*실습|교외\s*(수업|교육|실습)|field\s*trip|요일.{0,10}(미정|추후)|수업.{0,10}(미정|추후.{0,5}(협의|공지))|\d{1,2}\s*월\s*\d{1,2}\s*일.{0,30}(수업|휴강|보강|실습)|\d{1,2}[:：]\d{2}',re.I)
for school in ['baekseok','cnu']:
 for path in sorted((R/'assets/timetable').glob(school+'-*-2026-2.json')):
  old=read(path);new=copy.deepcopy(old);ds={'school':school,'prior':path.stem+'.prior-whole.json','candidate':path.stem+'.bulk-candidate.json','whole':len(old['courses']),'baselineScheduled':sum(bool(c['schedules'])for c in old['courses']),'baselineMeetings':sum(len(c['schedules'])for c in old['courses'])};dump(ds['prior'],old);nc=0;nm=0
  for c in new['courses']:
   if c['schedules']:continue
   reasons=[];evidence={};slots=[]
   if school=='baekseok':reasons=['Own current general undergraduate absolute period HH unpublished in cached source; department-specific contract clocks cannot be transferred'];evidence={'sourceEducationalMetadata':c.get('sourceEducationalMetadata'),'nativePeriodsPreserved':c['sourceSchedule'],'generalClockAudit':'work/university-research/catalog-c/baekseok-general-clock-review-20261009/current-public-clock-audit.json'}
   else:
    se=c['sourceEducation'];fields=se['originalEducationFields'];cid=se['courseId'];slots=se['actualDisplayedClocks'];planpath=W/'catalog-f/cnu-current-education'/(cid+'.json');plan=read(planpath)if planpath.exists()else None;evidence={'wholeNativeEducationalMetadata':se,'planPath':str(planpath.relative_to(R)),'wholePlanSHA':sha(planpath)if planpath.exists()else None}
    if fields.get('CLOSE_YN')!='0' or fields.get('CNCL_LT_YN') not in [None,'0',0,'']:reasons.append('current published closure/cancellation')
    if fields.get('OBJ_CORS_CD_NM')!='학사과정' or fields.get('OPEN_YR')!='2026':reasons.append('current undergraduate identity not confirmed')
    if not slots:reasons.append('native fixed weekday clock absent')
    if fields.get('LSN_METHOD_CD_NM') in ['혼합','원격','비대면']:reasons.append('native actual mixed/remote per-date allocation unresolved')
    if not plan or not plan.get('planPresent') or not plan.get('header'):reasons.append('current own full plan unavailable')
    else:
     evidence['wholeCurrentEducationalPlan']=plan
     if plan.get('courseId')!=cid or plan.get('verifiedOn')!='2026-10-08':reasons.append('current source identity/snapshot mismatch')
     for h in plan['header']:
      if h.get('OPEN_SHTM_CD_NM')!='2학기':reasons.append('current semester differs')
      if h.get('TLSN_ANNM') and re.sub(r'\s','',h['TLSN_ANNM'])!=re.sub(r'\s','',c['sourceSchedule']):reasons.append('current own native timetable conflict')
      if h.get('LSN_OPER_UNTACT_YN') not in [None,'0',0,'']:reasons.append('current selected remote delivery')
      if h.get('LSN_MTHD_SCENE') not in [None,0,'0',''] or h.get('LSN_MTHD_FLIP')not in [None,0,'0','']:reasons.append('current field/flipped operation allocation unresolved')
      # Course methods/rules are actual operating context; summary/learning topics alone are not delivery instructions.
      for k in ['LSN_OPER_MTHD','LSN_OPER_MTHD_UNTACT','LSN_RULE','ATTEND_RULE','LSN_MTHD_ETC']:
       v=h.get(k)
       if isinstance(v,str) and constraint.search(v):reasons.append('own header actual operating/date/clock constraint: '+k)
     for w in plan['weeks']:
      if w.get('CLS_METHOD_FIELD') in [1,'1']:reasons.append('current week field teaching allocation')
      for k,v in w.items():
       if isinstance(v,str) and constraint.search(v):reasons.append('own weekly actual operating/date/clock context: '+k)
     # Individual music/clinical/field original screen is retained even if this cached plan omits allocations.
     if any(t in c['courseName'] for t in ['전공실기','현장실습','임상실습','인턴십','교육실습']):reasons.append('individual practical placement timing not confirmed by generic clock')
   reasons=list(dict.fromkeys(reasons))
   if reasons:queue.append({'school':school,'sourceId':c['sourceId'],'courseCode':c['courseCode'],'section':c['section'],'reason':reasons,'sourceSchedule':c['sourceSchedule'],'sourceEvidence':evidence});continue
   assert slots
   # Independent parse native raw displayed HH, not another university's period convention.
   literal=[]
   for b in slots:
    m=re.fullmatch(r'([월화수목금토일])(\d{2}):(\d{2})~(\d{2}):(\d{2})(?:\((.*)\))?',b['rawDisplayedClock'])
    if not m:raise ValueError((c['sourceId'],b))
    s=int(m[2])*60+int(m[3]);e=int(m[4])*60+int(m[5]);assert (b['weekday'],b['startMinute'],b['endMinute'],b['location'])==('월화수목금토일'.index(m[1])+1,s,e,m[6] or '');assert s<e
    literal.append({'weekday':b['weekday'],'startMinute':s,'endMinute':e,'classroom':m[6] or ''})
   meetings=[]
   for b in literal:
    d=dt.date(2026,9,1)
    while d<=dt.date(2026,12,18):
     if d.isoweekday()==b['weekday'] and str(d)not in closed:meetings.append({**b,'date':str(d)})
     d+=dt.timedelta(days=1)
   archive[c['sourceId']]=copy.deepcopy(c['departmentRemarks']);warning='수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.';c['departmentRemarks']={k:v.replace(warning,'')for k,v in c['departmentRemarks'].items()};c['schedules']=meetings;c['scheduleStatus']='scheduled';c['period']={'startDate':'2026-09-01','endDate':'2026-12-18'};c['currentPublicPlanEducation']={'header':plan['header'],'weeks':plan['weeks'],'sourceResponseSHA256':plan['sourceResponseSHA256'],'tokenOnlyEducationalRedaction':True};c['bulkCurrentReservationReview']={'actualAttendanceConfirmed':False,'campusUnknownPreserved':True,'originalClockAndEducationPreserved':True,'nativeModeUnchanged':True};proof.append({'school':school,'sourceId':c['sourceId'],'literalSlots':literal,'wholeSourceEvidence':evidence,'meetings':len(meetings),'originalWholeObject':next(x for x in old['courses']if x['sourceId']==c['sourceId'])});nc+=1;nm+=len(meetings)
  ds.update(newScheduled=nc,newMeetings=nm,candidateScheduled=ds['baselineScheduled']+nc,candidateMeetings=ds['baselineMeetings']+nm);datasets.append(ds);dump(ds['candidate'],new)
summary={s:{'whole':sum(x['whole']for x in datasets if x['school']==s),'processedHeld':sum(x['whole']-x['baselineScheduled']for x in datasets if x['school']==s),'newScheduled':sum(x['newScheduled']for x in datasets if x['school']==s),'newMeetings':sum(x['newMeetings']for x in datasets if x['school']==s),'queue':sum(x['school']==s for x in queue),'reasonCounts':dict(collections.Counter(r for q in queue if q['school']==s for r in q['reason']))}for s in ['baekseok','cnu']};dump('summary.json',summary);dump('proof.json',{'datasets':datasets,'newCourses':proof,'sourceManifest':sources,'SDK':False,'productChanged':False,'wholeSupportCompletion':False});dump('queue.json',queue);dump('previous-full-remarks-archive.json',archive);(D/'parser.py').write_bytes(pathlib.Path(__file__).read_bytes());print(json.dumps(summary,ensure_ascii=False))
