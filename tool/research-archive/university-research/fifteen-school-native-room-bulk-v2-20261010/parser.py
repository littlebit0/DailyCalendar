# -*- coding: utf-8 -*-
import pathlib,json,copy,hashlib,re,datetime as dt,collections,importlib.util
R=pathlib.Path.cwd();W=R/'work/university-research';D=W/'fifteen-school-native-room-bulk-v2-20261010';D.mkdir(exist_ok=False);sources={};datasets=[];proof=[];queue=[];archive={}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):sources[str(p.relative_to(R))]={'sha256':sha(p),'bytes':p.stat().st_size};return json.loads(p.read_text())
def dump(n,x):(D/n).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
terms=read(R/'assets/timetable/term-periods.json');jterm=next(t for x in terms['additionalUniversities']if x['university']=='jnu'for t in x['terms']if t['year']==2026 and t['semester']=='2');sclock=read(W/'catalog-c/scnu-current-20261008/native-clock-proof.json');read(W/'catalog-c/scnu-current-20261008/candidate-audit.json');read(W/'catalog-r/hanbat/hanbat-current-2026-2-native-education-rows-v1.json')
spec=importlib.util.spec_from_file_location('jn',R/'tool/timetable/import_jnu.py');jn=importlib.util.module_from_spec(spec);spec.loader.exec_module(jn);sources['tool/timetable/import_jnu.py']={'sha256':sha(R/'tool/timetable/import_jnu.py'),'bytes':(R/'tool/timetable/import_jnu.py').stat().st_size}
closes={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};scAllowed={'room notation needs meeting-specific interpretation','published classroom absent/unconfirmed; room notation needs meeting-specific interpretation'}
week={i:((i+8)*60,(i+8)*60+50)for i in range(1,10)};week.update({10:(1120,1170),11:(1175,1225),12:(1230,1280),13:(1290,1340)});sat={i:((i+8)*60,(i+8)*60+50)for i in range(1,6)};sat.update({6:(840,890),7:(895,945),8:(950,1000),9:(1005,1055),10:(1060,1110),11:(1115,1165),12:(1170,1220),13:(1225,1275)})
schools=['snu','jnue','scnu','swu','sejong','mju','pnu','dku','cau','jnu','hanbat','postech','inha','donga','yongin']
for school in schools:
 for path in sorted((R/'assets/timetable').glob(school+'-*-2026-2.json')):
  old=read(path);new=copy.deepcopy(old);ds={'school':school,'prior':path.stem+'.prior-whole.json','candidate':path.stem+'.bulk-candidate.json','whole':len(old['courses']),'baselineScheduled':sum(bool(c['schedules'])for c in old['courses']),'baselineMeetings':sum(len(c['schedules'])for c in old['courses'])};dump(ds['prior'],old);nc=nm=0
  for c in new['courses']:
   if c['schedules']:continue
   sid=c['sourceId'];reason=[];slots=[];evidence={};start='2026-09-01';end='2026-12-07';ex=set(closes);notes='\n'.join([str(c.get('remarks','')),*c.get('departmentRemarks',{}).values()])
   if school=='scnu':
    oldreason=c['remarks'].split(' 일정 미생성: ')[-1];evidence={'nativePeriodBlocks':c['nativePeriodBlocks'],'wholePublicEducationalRows':c['publicEducationRows'],'sourceReason':oldreason,'clockSource':'work/university-research/catalog-c/scnu-current-20261008/native-clock-proof.json'}
    if oldreason not in scAllowed:reason.append(oldreason)
    else:
     for b in c['nativePeriodBlocks']:
      a,e=sclock['clocks'][str(b['nativePeriod'])];assert(a,e)==(b['startMinute'],b['endMinute']);slots.append({'weekday':b['weekday'],'startMinute':a,'endMinute':e,'classroom':''})
    ex|={str(dt.date(2026,10,19)+dt.timedelta(days=i))for i in range(5)}
   elif school=='hanbat':
    md=c['metadata'];r=md['originalEducationalFields'];evidence={'originalWholeEducationalFields':r,'previousHeldReason':md['heldReason']}
    if md['heldReason']not in ['개별 강의실 미확인','원본 교시와 강의실 대응 미확인']:reason.append(md['heldReason'])
    if r['operatingStatus']!='개설':reason.append('actual published closed')
    compact=re.sub(r'\s','',str(r['rawSchedule']or''));tokens=list(re.finditer('([월화수목금토일])([^월화수목금토일]+)',compact))
    if not tokens or ''.join(m[0]for m in tokens)!=compact:reason.append('whole native syntax unresolved')
    for m in tokens:
     d='월화수목금토일'.index(m[1])+1;parts=m[2].strip(',').split(',')
     if d==7 or not all(x.isdigit()and 1<=int(x)<=13 for x in parts):reason.append('unpublished own period/fraction/day');continue
     for x in parts:a,b=(sat if d==6 else week)[int(x)];slots.append({'weekday':d,'startMinute':a,'endMinute':b,'classroom':''})
    end='2026-12-14'
   elif school=='jnu':
    # Retain same-school own module restrictions (Tue/Thu9,MWF13 unposted); room order is not a clock gate.
    slots,status=jn.meetings(c['sourceSchedule'],'');evidence={'nativeSourceSchedule':c['sourceSchedule'],'originalRawRoom':c['sourceClassroom'],'nativeRawDepartmentRestrictions':c['departmentRemarks'],'sameUniversityCurrentTerm':jterm,'ownModuleSource':old.get('timeModuleSourceUrl'),'ownSaturdaySource':old.get('saturdayModuleSourceUrl'),'clockParserPath':'tool/timetable/import_jnu.py'}
    if status!='scheduled':reason.append('own weekday module/period/native syntax not fully published')
    if re.search(r'비대면|원격|온라인|MOOC|현장실습|임상실습|교수.{0,6}협의|집중\s*(수업|이수)|개인별|개별\s*(배정|협의|실습)',notes+' '+c['courseName'],re.I):reason.append('actual remote/individual/concentrated allocation unresolved')
    # Existing datasets retain undated ordinary weekly plans; explicit course period guards calendar expansion.
    start=jterm['start'];end=jterm['end']
   else:
    if school in ['snu','sejong','dku']:reason=['current native fixed HH/weekday absent'];assert not c['sourceSchedule']
    elif school=='jnue':reason=['own published period window does not confirm actual instruction endpoint/date allocation'];evidence={'wholeNativeDocumentCells':c.get('publicEducationCells'),'nativeStudyClass':c.get('nativeStudyClass'),'sourceRemarks':c.get('remarks')}
    elif school=='swu':reason=['native untimed, nonstandard notation or source-specific concentrated/individual operation unresolved'];evidence={'sourceRemarks':c.get('remarks'),'sourceNativeTime':c['sourceSchedule']}
    elif school=='mju':reason=['current own exact lecture HH or individual/night course operation not established'];evidence={'wholeNativeEducation':c.get('sourceEducation'),'sourceRemarks':c.get('remarks'),'departmentRemarks':c.get('departmentRemarks')}
    elif school=='pnu':reason=['native source marks untimed/asynchronous delivery; posted reference periods not actual synchronous meetings'];evidence={'nativeSourceTime':c['sourceSchedule'],'departmentRemarks':c['departmentRemarks']}
    elif school=='cau':reason=['native scheduled weekday/HH absent or explicitly untimed seminar source'];evidence={'nativeSourceSchedule':c['sourceSchedule'],'departmentRemarks':c['departmentRemarks']}
    elif school=='postech':reason=[c['metadata']['decisionReason']];evidence={'wholeSourceEducationalMetadata':c['metadata']}
    elif school=='inha':reason=['native untimed web/session/individually assigned delivery preserved'];evidence={'nativeSourceSchedule':c['sourceSchedule'],'departmentRemarks':c['departmentRemarks']}
    elif school=='donga':reason=['existing source-specific external/remote/operation/50-75clock allocation boundary'];evidence={'sourceRemarks':c.get('remarks'),'sourceEducation':c.get('sourceEducation'),'nativeCampus':c.get('nativeCampus')}
    elif school=='yongin':reason=['native fixed clock unpublished or source per-course allocation unresolved'];evidence={'nativeSourceSchedule':c['sourceSchedule'],'departmentRemarks':c['departmentRemarks']}
   if not slots:reason.append('no complete own current regular clock')
   reason=list(dict.fromkeys(reason))
   if reason:queue.append({'school':school,'sourceId':sid,'courseCode':c['courseCode'],'section':c['section'],'sourceSchedule':c['sourceSchedule'],'reason':reason,'sourceEvidence':evidence});continue
   # Detect actual overlap, including duplicate blocks; do not silently accept different intervals.
   if any(a['weekday']==b['weekday']and max(a['startMinute'],b['startMinute'])<min(a['endMinute'],b['endMinute'])for i,a in enumerate(slots)for b in slots[i+1:]):queue.append({'school':school,'sourceId':sid,'reason':['native whole blocks overlap; allocation requires individual source proof'],'sourceEvidence':evidence});continue
   ms=[]
   if school=='jnu':ms=slots
   else:
    date=dt.date.fromisoformat(start)
    while date<=dt.date.fromisoformat(end):
     if str(date)not in ex:
      for b in slots:
       if b['weekday']==date.isoweekday():ms.append({**b,'date':str(date)})
     date+=dt.timedelta(days=1)
   assert ms;original=next(x for x in old['courses']if x['sourceId']==sid);archive[sid]={'remarks':c.get('remarks'),'departmentRemarks':copy.deepcopy(c.get('departmentRemarks')),'metadata':copy.deepcopy(c.get('metadata'))};c['schedules']=ms;c['scheduleStatus']='scheduled';c['period']={'startDate':start,'endDate':end}
   if school=='scnu':c['remarks']=c['remarks'].replace(' 일정 미생성: '+evidence['sourceReason'],'')
   if school=='hanbat':c['remarks']=c['remarks'].replace(' 예약 보류: '+evidence['previousHeldReason'],'');c['metadata']['previousGeneratedHeldReason']=c['metadata']['heldReason'];c['metadata']['heldReason']=''
   c['bulkCurrentReservationReview']={'actualAttendanceConfirmed':False,'sourceAllLocationsPreserved':True,'unknownRoomKeptBlank':True,'dateGenerationKind':'sourceOwnSemesterBoundedWeeklyPlan'if school=='jnu'else'ownBoundedRegularDates'}
   proof.append({'school':school,'sourceId':sid,'originalWholeObject':original,'literalSlots':slots,'dateRule':{'start':start,'end':end,'excluded':sorted(ex),'rawWeeklySource':school=='jnu'},'wholeSourceEvidence':evidence,'meetings':len(ms)});nc+=1;nm+=len(ms)
  ds.update(newScheduled=nc,newMeetings=nm,candidateScheduled=ds['baselineScheduled']+nc,candidateMeetings=ds['baselineMeetings']+nm);datasets.append(ds);dump(ds['candidate'],new)
summary={s:{'whole':sum(x['whole']for x in datasets if x['school']==s),'processedHeld':sum(x['whole']-x['baselineScheduled']for x in datasets if x['school']==s),'newScheduled':sum(x['newScheduled']for x in datasets if x['school']==s),'newMeetings':sum(x['newMeetings']for x in datasets if x['school']==s),'queue':sum(q['school']==s for q in queue),'reasonCounts':dict(collections.Counter(r for q in queue if q['school']==s for r in q['reason']))}for s in schools};dump('proof.json',{'datasets':datasets,'newCourses':proof,'sourceManifest':sources,'SDK':False,'productChanged':False,'wholeSupportCompletion':False});dump('summary.json',summary);dump('queue.json',queue);dump('previous-full-remarks-archive.json',archive);(D/'parser.py').write_bytes(pathlib.Path(__file__).read_bytes());print(json.dumps({s:{k:v for k,v in x.items()if k!='reasonCounts'}for s,x in summary.items()},ensure_ascii=False))
