import json,pathlib,copy,re,datetime as dt,hashlib,collections
R=pathlib.Path.cwd();W=R/'work/university-research';D=W/'four-school-bulk-catholic-mokpo-chosun-pknu-v1-20261010';D.mkdir(exist_ok=False)
def load(p):return json.loads(pathlib.Path(p).read_text())
def dump(n,d):(D/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
sources={};new=[];queue=[];datasets=[];archive={}
def source(p):p=pathlib.Path(p);sources[str(p.relative_to(R))]={'bytes':p.stat().st_size,'sha256':sha(p)};return load(p)
def meetings(slots,start,end,excluded,mass=False):
 out=[];date=dt.date.fromisoformat(start)
 while date<=dt.date.fromisoformat(end):
  if str(date) not in excluded:
   for b in slots:
    if b['weekday']==date.isoweekday():
     if mass and str(date)=='2026-09-09' and b['startMinute']<710 and b['endMinute']>600:continue
     out.append({**b,'date':str(date)})
  date+=dt.timedelta(days=1)
 return out
G=W/'catalog-g';M=W/'catalog-m';F=W/'catalog-f'
cukraw={(x['code'],x['section']):x for x in source(G/'cuk-current-whole-exact-section-credit-next-20261008.json')['courses']}
cukaudit={(x['code'],x['section']):x for x in source(G/'cuk-published-regular-1013-candidate-audit-20261008.json')['courses']}
for f in ['cuk-current-school-own-term-clock-confirmation-20261008.json','cuk-current-regular-timetable-rule-proof-20261008.json']:source(G/f)
clock={(x['courseCode'],x['section']):x for x in source(M/'mokpo-current-whole-time-review-unregistered.json')['courses']}
mreview={(x['courseCode'],x['section']):x for x in source(M/'mokpo-current-whole-operating-consistency-review-20261008.json')['courses']}
maudit=source(M/'mokpo-registration-candidate-audit-20261008.json');mhol=set(maudit['excludedRegularClosureDates'])
pau=source(F/'pknu-same-term-unit-v3-20261009/candidate-audit.json');pheld={x['identity']:x for x in pau['heldReviews']}
pub={x['fields']['identity']:x for x in source(F/'pknu-same-term-unit-v3-20261009/official-semester-xlsx-education.json')['rows']}
pnative={x['COURSE_NO']+'-'+x['DCLSS_NO']:x for x in source(F/'pknu-latest-rows.json')}
phol=set(source(F/'pknu-current-20261008/candidate-audit.json')['excludedHolidays'])
chsource=source(W/'catalog-c/chosun-remaining42-source-review-v6-20261009/remaining42-educational-audit.json')
for school in ['catholic','mokpo','chosun','pknu']:
 for path in sorted((R/'assets/timetable').glob(school+'-*-2026-2.json')):
  prior=source(path);candidate=copy.deepcopy(prior);ds={'school':school,'prior':path.stem+'.prior-whole.json','candidate':path.stem+'.bulk-candidate.json','whole':len(prior['courses']),'baselineScheduled':sum(bool(c.get('schedules')) for c in prior['courses']),'baselineMeetings':sum(len(c.get('schedules',[])) for c in prior['courses'])};count=0;added=0
  dump(ds['prior'],prior)
  for c in candidate['courses']:
   if c.get('schedules'):continue
   key=(c['courseCode'],c['section']);identity='-'.join(key);sid=c['sourceId'];slots=[];reasons=[];start='2026-09-01';end='2026-12-07';excluded=set();proof={}
   if school=='catholic':
    raw=cukraw[key];reason=cukaudit[key]['reason'];reasons=[reason] if reason else []
    if reason=='publishedBlankRoomModeUnresolved':
     # Exact current blank-room ensemble records; volunteer and individually-arranged courses retained.
     if raw['code'] in ['00599','01107','01109','01111','01113','03308','03311','03313','06118'] and not raw['remarks']:
      reasons=[]
      for day,a,b,room in re.findall(r'([월화수목금토일])(\d+)(?:~(\d+))?\(([^()]*)\)',raw['rawTimeAndRoom']):
       a=int(a);b=int(b or a)
       if not 1<=a<=b<=9:reasons.append('own period scope unconfirmed');break
       slots.append({'weekday':'월화수목금토일'.index(day)+1,'startMinute':(a+8)*60,'endMinute':(b+8)*60+50,'classroom':room})
      if not slots:reasons.append('native exact blocks absent')
    start='2026-08-31';end='2026-12-18';excluded={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};proof={'nativeWholeEducation':raw,'previousDisposition':cukaudit[key],'massSep9Periods2and3Excluded':True}
   elif school=='mokpo':
    cr=clock[key];rv=mreview[key];reasons=list(cr['individualBlockedReasons'])+list(rv['reasons']);plan=M/'mokpo-current-plan-operating-20261008'/(identity+'.json');doc=source(plan) if plan.exists() else None
    if rv['status']!='currentPlanClockConsistentNoSelectedException':reasons.append(rv['status'])
    if doc:
     dsout=doc['educationalDatasets']; main=dsout.get('ds_out',[])
     if len(main)!=1 or main[0].get('BIGO_TIME')!=c['sourceSchedule']:reasons.append('current own plan clock differs')
     body='\n'.join(str(w.get(k,'')) for w in dsout.get('ds_out3',[]) for k in ['BANGBEOP','BIGO'])+'\n'+'\n'.join(s for m in main for s in m.get('operatingNoteExcerpts',[]))
     if re.search(r'휴강|보강|수업\s*없|no\s*class|현장실습|임상실습|교외학습|집중\s*(수업|이수)|격주|비대면\s*(강의|수업)|온라인\s*(강의|수업)|원격\s*(수업|강의)|실시간|VOD|녹화\s*(강의|수업)|미정|추후\s*(공지|협의)|\d{1,2}\s*월\s*\d{1,2}\s*일|\d{1,2}[:：]\d{2}',body,re.I):reasons.append('actual operating allocation/date instruction remains unresolved')
     # Numeral dots in printed chapter/scale values alone do not imply an attendance date.
    else:reasons.append('current own plan unavailable')
    slots=[{k:b[k] for k in ['weekday','startMinute','endMinute']}|{'classroom':c['sourceClassroom']} for b in cr['clockReview']]
    if not slots:reasons.append('native fixed time unavailable')
    if any(b['endMinute']>1080 for b in slots) and '간호' not in ' '.join(c['departments']):reasons.append('own general undergraduate periods19plus unproven')
    excluded=mhol;proof={'clockReview':cr,'currentConsistencyReview':rv,'wholeEducationalPlanPath':str(plan.relative_to(R)),'wholeEducationalPlanSHA':sha(plan) if plan.exists() else None}
   elif school=='chosun':
    nb=c.get('sourceEducation',{}).get('nativePublicBlock',{});reasons=nb.get('heldReasons',[]) or ['individual current operating boundary preserved'];proof={'nativeEducationalOperatingSource':c.get('sourceEducation'),'existingWholeReview':str(W/'catalog-c/chosun-remaining42-source-review-v6-20261009/remaining42-educational-audit.json')}
   elif school=='pknu':
    h=pheld.get(identity);receipt=pub.get(identity);native=pnative[identity];fields=c.get('publicPlanEducation',{}).get('fields',{});reasons=list(h['holds']) if h else ['no existing own full unit review']
    # Room mapping does not veto a known current native clock. Keep all source locations, render unallocated room blank.
    reasons=[r for r in reasons if r!='current room is absent/multiple/nonstandard and per-period mapping not verified']
    clean=lambda s:re.sub(r'\s+','',s or '')
    if receipt and clean(receipt['fields']['title'])==clean(c['courseName'])==clean(fields.get('교과목명')):
     reasons=[r for r in reasons if r!='native title or current header differs from unit row']
    if not receipt:reasons.append('official unit row absent')
    else:
     unit=receipt['fields'].get('unit');own=c.get('sourceNativePeriods',[])
     if unit not in ['50','75']:reasons.append('own unit unknown')
     if not own:reasons.append('native fixed periods absent')
     if not reasons:
      unit=int(unit); room=c['sourceClassroom'] if ';' not in c['sourceClassroom'] and ',' not in c['sourceClassroom'] else ''
      if 'current room is absent/multiple/nonstandard and per-period mapping not verified' in h['holds']:room=''
      slots=[{'weekday':b['weekday'],'startMinute':480+60*b['period'] if unit==50 else 540+90*(b['period']-1),'endMinute':(480+60*b['period'] if unit==50 else 540+90*(b['period']-1))+unit,'classroom':room,'sourcePeriod':b['period'],'sourceMinuteUnit':unit} for b in own]
     proof={'officialSameSemesterUnitRow':receipt,'currentNativeEducation':native,'previousCompleteHeldReview':h,'publishedCurrentHeader':fields,'sourcePeriodUnitKept':unit}
    excluded=phol
   reasons=list(dict.fromkeys(r for r in reasons if r))
   if reasons or not slots:queue.append({'school':school,'sourceId':sid,'courseCode':key[0],'section':key[1],'reason':reasons or ['no exact ordinary slots'],'sourceSchedule':c['sourceSchedule'],'wholeSourceEvidence':proof});continue
   ms=meetings(slots,start,end,excluded,school=='catholic');assert ms
   archive[sid]={'departmentRemarks':copy.deepcopy(c.get('departmentRemarks')),'remarks':c.get('remarks')}
   c['schedules']=ms;c['scheduleStatus']='scheduled'
   # Remove only exact generated stale warning, leaving school excerpts unchanged.
   if school=='mokpo':
    warning='\n운영 검토: Additional literal operating-context reference requires individual semantic review; topic text is not automatically treated as a mode.'
    c['departmentRemarks']={d:t.replace(warning,'') for d,t in c.get('departmentRemarks',{}).items()}
   if school=='pknu':
    def note(t):
     if ' 일정 미생성: ' in t:
      begin,tail=t.split(' 일정 미생성: ',1);marker=' 현재 강의실 건물로 확인된 캠퍼스: ';t=begin+(marker+tail.split(marker,1)[1] if marker in tail else '')
     return t.replace('현재 단위 불명확한 화/목은 일정으로 치환하지 않았습니다.','같은 학기 원문 단위와 현재 교시 대응을 보존합니다. 미배정 장소는 빈 값으로 유지합니다.')
    c['remarks']=note(c.get('remarks',''));c['departmentRemarks']={d:note(t)for d,t in c.get('departmentRemarks',{}).items()}
   c['bulkCurrentRegularReservationReview']={'actualAttendanceConfirmed':False,'originalSourceFieldsPreserved':True,'classroomUnallocatedKeptBlank':any(not b['classroom'] for b in slots),'sourceOperatingConstraintsAbsentInAcceptedScope':True}
   new.append({'school':school,'sourceId':sid,'sourceAsset':str(path.relative_to(R)),'literalSlots':slots,'dateRule':{'start':start,'end':end,'excluded':sorted(excluded),'sep9MassPeriodExclusion':school=='catholic'},'meetings':len(ms),'sourceEvidence':proof});count+=1;added+=len(ms)
  ds.update(newScheduled=count,newMeetings=added,candidateScheduled=ds['baselineScheduled']+count,candidateMeetings=ds['baselineMeetings']+added);datasets.append(ds);dump(ds['candidate'],candidate)
summary={s:{'whole':sum(x['whole']for x in datasets if x['school']==s),'processedHeld':sum(x['whole']-x['baselineScheduled']for x in datasets if x['school']==s),'newScheduled':sum(x['newScheduled']for x in datasets if x['school']==s),'newMeetings':sum(x['newMeetings']for x in datasets if x['school']==s),'queue':sum(x['school']==s for x in queue),'reasonCounts':dict(collections.Counter(r for q in queue if q['school']==s for r in q['reason']))}for s in ['catholic','mokpo','chosun','pknu']}
dump('proof.json',{'datasets':datasets,'newCourses':new,'sourceManifest':sources,'SDK':False,'productChanged':False,'wholeSupportCompletion':False});dump('summary.json',summary);dump('queue.json',queue);dump('previous-full-remarks-archive.json',archive);(D/'parser.py').write_bytes(pathlib.Path(__file__).read_bytes());print(json.dumps(summary,ensure_ascii=False));print(D)
