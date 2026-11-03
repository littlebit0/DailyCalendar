# -*- coding: utf-8 -*-
import pathlib,json,copy,hashlib,re,datetime as dt,collections,importlib.util
R=pathlib.Path.cwd();W=R/'work/university-research';H=W/'catalog-h';D=W/'five-school-ajou-dongguk-hansung-seoultech-hknu-bulk-v1-20261010';D.mkdir(exist_ok=False);sources={};proof=[];queue=[];datasets=[];archive={}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):sources[str(p.relative_to(R))]={'sha256':sha(p),'bytes':p.stat().st_size};return json.loads(p.read_text())
def dump(n,x):(D/n).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
def module(p):s=importlib.util.spec_from_file_location(p.stem,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);sources[str(p.relative_to(R))]={'sha256':sha(p),'bytes':p.stat().st_size};return m
hm=module(R/'tool/timetable/import_hansung.py');stm=module(R/'tool/timetable/import_seoultech.py');km=module(R/'tool/timetable/import_hknu.py')
read(W/'catalog-c/hansung-clock-endpoint-review-v3-20261009/own-current-clock-endpoint-audit.json');read(H/'seoultech-whole-prepared-audit.json');read(W/'catalog-w/dongguk/public-export-partial-v1-audit.json')
closes={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
risk=re.compile(r'휴강|보강|수업\s*없|no\s*class|make.?up\s*class|집중\s*(수업|이수|강의)|비대면|온라인\s*(수업|강의)|원격\s*(강의|수업)|사이버강의|녹화|VOD|동영상\s*(강의|수업)|실시간|개별\s*(레슨|지도|시간)|교수.{0,8}협의|별도\s*(일정|시간|배정)|현장\s*(실습|수업|견학)|임상\s*실습|교외\s*(수업|실습)|field\s*trip|\b(?:online|remote|blended|hybrid|asynchronous)\s*(?:lecture|course|class)|\d{1,2}\s*월\s*\d{1,2}\s*일|\d{1,2}[/:]\d{1,2}',re.I)
for school in ['ajou','dongguk','hansung','seoultech','hknu']:
 for path in sorted((R/'assets/timetable').glob(school+'-*-2026-2.json')):
  old=read(path);new=copy.deepcopy(old);ds={'school':school,'prior':path.stem+'.prior-whole.json','candidate':path.stem+'.bulk-candidate.json','whole':len(old['courses']),'baselineScheduled':sum(bool(c['schedules'])for c in old['courses']),'baselineMeetings':sum(len(c['schedules'])for c in old['courses'])};dump(ds['prior'],old);nc=nm=0
  for c in new['courses']:
   if c['schedules']:continue
   reasons=[];slots=[];evidence={};start='2026-09-01';end='2026-12-07';exclude=set(closes);sid=c['sourceId'];key=c['courseCode']+'-'+c['section']
   if school=='ajou':reasons=['current native fixed time absent; untimed source preserved'];evidence={'sourceSchedule':c['sourceSchedule'],'originalDepartmentRemarks':c['departmentRemarks']};assert not c['sourceSchedule']
   elif school=='dongguk':
    md=c['metadata'];row=md['nativeEducationalRow'];reasons=[r for r in md['heldReasons']if r not in ['실제 강의실 미공개','개별 시간과 복수 강의실 대응 미확인','물리 캠퍼스 미공개']];evidence={'wholeNativeEducationalRow':row,'priorHoldReasons':md['heldReasons']}
    if row.get('강의형태')!='일반강의':reasons.append('actual native remote/mentoring delivery unknown')
    if row.get('집중이수학기기간'):reasons.append('actual native concentrated semester allocation')
    # Whole source HH group parse, including commas among weekday names. Never pair room list by order.
    groups=list(re.finditer(r'([월화수목금토일](?:\s*,\s*[월화수목금토일])*)\s*[\d.]+교시\((\d{2}):(\d{2})\)\s*~\s*[\d.]+교시\((\d{2}):(\d{2})\)',c['sourceSchedule']))
    rest=re.sub(r'([월화수목금토일](?:\s*,\s*[월화수목금토일])*)\s*[\d.]+교시\(\d{2}:\d{2}\)\s*~\s*[\d.]+교시\(\d{2}:\d{2}\)','',c['sourceSchedule'])
    if not groups or re.sub('[ ,]','',rest):reasons.append('current complete native HH syntax unconfirmed')
    for m in groups:
     a=int(m[2])*60+int(m[3]);b=int(m[4])*60+int(m[5]);assert a<b
     for day in re.findall('[월화수목금토일]',m[1]):slots.append({'weekday':'월화수목금토일'.index(day)+1,'startMinute':a,'endMinute':b,'classroom':''})
    if any('주차' in r or '기간' in r for r in reasons):pass
    exclude|={str(dt.date(2026,10,20)+dt.timedelta(days=i))for i in range(7)}
   elif school=='hansung':
    p=H/'hansung-current-operating-proofs'/(key+'.json');plan=read(p)if p.exists()else None;evidence={'currentOwnEducationalProof':plan,'sourceProofPath':str(p.relative_to(R))}
    try:slots=hm.schedules(c['sourceSchedule'])
    except ValueError as e:reasons.append(str(e))
    if not plan or plan.get('status')!='currentVerifiedIdentity' or plan.get('educationalParserVersion')!=4:reasons.append('current complete educational plan unavailable')
    else:
     if plan.get('academicYear')!=2026 or plan.get('semester')!='2' or plan['courseCode']!=c['courseCode']or plan['section']!=c['section']:reasons.append('current identity differs')
     if re.sub(r'\s','',plan['sourceSchedule'])!=re.sub(r'\s','',c['sourceSchedule']):reasons.append('current own source schedule differs')
     if plan.get('sourceOfflineFlag')!='Y' or '온라인강좌' in c['sourceSchedule']:reasons.append('mixed/online own current physical allocation unresolved')
     if not all(w['topicPublished']for w in plan['weeks']):reasons.append('current whole weekly operating context incomplete')
     if c['courseCode']in ['GEN0993','GEN1031','P010143','P010167','P017023','T030132','V020036','V070078','V076015','Y030038']:reasons.append('actual own intensive period unresolved')
     lines=plan['operatingNotes']+[t for w in plan['weeks']for t in w['operatingEvidence']]
     if any(risk.search(t)for t in lines):reasons.append('actual source operating/date context unresolved')
     if any(w.get('flipped')for w in plan['weeks']):reasons.append('actual source flipped allocation unresolved')
    start='2026-08-31';end='2026-12-06'
   elif school=='seoultech':
    p=H/'seoultech-public-plans'/(key+'.json');plan=read(p)if p.exists()else None;evidence={'wholeCurrentEducationalPlan':plan,'sourcePath':str(p.relative_to(R))}
    try:slots=stm.regular_meetings(c['sourceSchedule'])
    except ValueError as e:reasons.append(str(e))
    if not plan:reasons.append('current educational plan unpublished')
    else:
     if plan.get('SP_YMST')!='20262' or plan.get('SUBJ_CD')!=c['courseCode']:reasons.append('current semester/code identity differs')
     if plan.get('CONC_SMTS_DIV_NM') not in [None,'General course','일반강의']:reasons.append('actual semester-half/concentrated allocation unresolved')
     for k,v in plan.items():
      if isinstance(v,str)and(k.startswith(('TASK','COUS'))or k in ['LSN_OPER_MTHD','SUBJ_SMRY','RULE','NOTE','ETC'])and risk.search(v):reasons.append('actual source operating/date context unresolved: '+k)
    end='2026-12-14'
   elif school=='hknu':
    md=c['metadata'];evidence={'wholeCurrentSourceMetadata':md,'departmentRemarks':c['departmentRemarks']};slots,why=km.clocks(c['sourceSchedule'],c['sourceClassroom']);
    if why:reasons.append(why)
    text='\n'.join(c['departmentRemarks'].values())
    if c['courseName']==km.COUNSELING:reasons.append('actual individual professor counseling schedule')
    if km.FIELD.search(c['courseName']):reasons.append('actual field/individual concentrated allocation not confirmed')
    if md.get('currentFinalPublishedCancellation'):reasons.append('current actual published cancellation')
    cp=md.get('currentGeneralPublication',{});raw=cp.get('actualEducationalFields',{})
    if raw.get('원격여부')in ['Y','혼합']:reasons.append('actual current remote/mixed allocation not confirmed')
    # Current blanked unknown operation/rollback remains a real boundary, not just removal of generated wording.
    if any(t in text for t in ['실시간','집중','미확정','교수와 협의','실제 시행기간','폐강','실제 운영']):reasons.append('existing actual own operating boundary preserved')
    if not reasons:reasons.append('no new independent operating proof for existing unscheduled row')
   if not slots:reasons.append('native fixed complete clock unavailable')
   reasons=list(dict.fromkeys(reasons))
   if reasons:queue.append({'school':school,'sourceId':sid,'courseCode':c['courseCode'],'section':c['section'],'sourceSchedule':c['sourceSchedule'],'reason':reasons,'sourceEvidence':evidence});continue
   ms=[];date=dt.date.fromisoformat(start)
   while date<=dt.date.fromisoformat(end):
    if str(date)not in exclude:
     for b in slots:
      if b['weekday']==date.isoweekday():ms.append({**b,'date':str(date)})
    date+=dt.timedelta(days=1)
   assert ms;archive[sid]={'remarks':c.get('remarks'),'departmentRemarks':copy.deepcopy(c.get('departmentRemarks'))};original=next(x for x in old['courses']if x['sourceId']==sid)
   c['schedules']=ms;c['scheduleStatus']='scheduled';c['period']={'startDate':start,'endDate':end};c['bulkCurrentRegularReservationReview']={'actualAttendanceConfirmed':False,'sourceOriginalEducationPreserved':True,'blankRoomAllocationNotGuessed':True}
   if school=='dongguk':
    c['metadata']['previousGeneratedHeldReasons']=c['metadata']['heldReasons'];c['metadata']['heldReasons']=[]
    # Preserve entire school notes and remove exact generated obsolete status sentence only.
    priorReason=', '.join(evidence['priorHoldReasons']);c['remarks']=c['remarks'].replace('일정 보류: '+priorReason+'. ','')
   else:
    warnings=['수업 운영·시각 검증 중: 확인 전 자동 반복 추가 불가.','공개 수업계획에 별도 시험·보강·녹화·혼합 수업 등 운영 예외가 있어 전체 날짜와 시각을 확정할 수 없습니다.'];c['departmentRemarks']={k:__import__('functools').reduce(lambda t,w:t.replace(w,''),warnings,v)for k,v in c['departmentRemarks'].items()}
   proof.append({'school':school,'sourceId':sid,'originalWholeObject':original,'literalSlots':slots,'dateRule':{'start':start,'end':end,'excluded':sorted(exclude)},'wholeSourceEvidence':evidence,'meetings':len(ms)});nc+=1;nm+=len(ms)
  ds.update(newScheduled=nc,newMeetings=nm,candidateScheduled=ds['baselineScheduled']+nc,candidateMeetings=ds['baselineMeetings']+nm);datasets.append(ds);dump(ds['candidate'],new)
summary={s:{'whole':sum(x['whole']for x in datasets if x['school']==s),'processedHeld':sum(x['whole']-x['baselineScheduled']for x in datasets if x['school']==s),'newScheduled':sum(x['newScheduled']for x in datasets if x['school']==s),'newMeetings':sum(x['newMeetings']for x in datasets if x['school']==s),'queue':sum(q['school']==s for q in queue),'reasonCounts':dict(collections.Counter(r for q in queue if q['school']==s for r in q['reason']))}for s in ['ajou','dongguk','hansung','seoultech','hknu']};dump('proof.json',{'datasets':datasets,'newCourses':proof,'sourceManifest':sources,'SDK':False,'productChanged':False,'wholeSupportCompletion':False});dump('summary.json',summary);dump('queue.json',queue);dump('previous-full-remarks-archive.json',archive);(D/'parser.py').write_bytes(pathlib.Path(__file__).read_bytes());print(json.dumps(summary,ensure_ascii=False))
