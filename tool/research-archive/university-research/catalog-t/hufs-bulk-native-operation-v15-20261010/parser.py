import json,pathlib,copy,re,hashlib,datetime as dt,importlib.util,collections
R=pathlib.Path('work/university-research/catalog-t');P=R/'hufs-bulk-native-operation-v15-20261010';assert not P.exists();P.mkdir()
spec=importlib.util.spec_from_file_location('hufs_import','tool/timetable/import_hufs.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
manifest,records=mod.load_complete(R/'hufs-current-20261008');raw={};
for rr in records:raw.setdefault((rr['queryCampus'],rr['row']['lssnCd']),[]).append(rr)
ns={'__file__':str(R/'gate_hufs_pending_operating_review.py')};exec((R/'gate_hufs_pending_operating_review.py').read_text().split('decisions=[]')[0],ns);approved=ns['nonoperating']
receipt=json.load(open(R/'hufs-partial-operation-v4-20261009/own-clock-calendar-education-receipt.json'));clocks={'H1':{str(i):[480+i*60,530+i*60]for i in range(13)},'H2':{str(i):[480+i*60,530+i*60]for i in range(1,13)}}
remote=re.compile(r'이러닝|(?i:\be[ -]?learning\b)|[Ff]lipped|비대면|실시간|온라인|녹화|동영상|사이버|원격|[Ww]ebex|[Zz]oom|[Pp]anopto|[Aa]synchron|[Ss]ynchronous|\b[Oo]n[- ]?line\b|[Rr]eal[- ]time')
special=re.compile(r'협의|조율|집중.?수업|집중.?강의|현장.?실습|현장.?학습|견학|답사|교외|개별.?지도|지도교수|(?i:field[ -]?(?:work|trip|visit)|excursion|off[ -]?campus|museum[ -]?visit)')
noClass=re.compile(r'휴강|보강|휴업|추석|한글날|개천절|공휴일|대체.?수업|대체.?출석|(?i:make[- ]?up|no\s+(?:class|lecture|teaching)|cancel(?:led|ed)|reading week|holiday|Chuseok|Hangeul)')
datehead=re.compile(r'^\s*(?:\[|\()?((?:9|10|11|12))[/.](\d{1,2})(?!\d)(?:\]|\))?(?=\s|$|[:：,])')
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
queue=[];proof=[];archive={};baselines={};candidates={};sources={};normalNativeCount=0
warning=' · 공개 운영 일정 확인 중: 자동 시간 생성 보류'
note='현재 2026-2 학교 자체 정규 교시·캠퍼스·개설 강좌 원문과 공개 운영 필드를 대조한 부분만 예약합니다. 학교 원문 날짜가 있으면 그 날짜를 우선하며, 휴일·평가·보강·원격·개별 배정·운영 미확정 부분은 별도 원문 큐에 보존합니다. 강의계획 미게시 자체만으로 공개 정규 개설 시각을 삭제하지 않으며, 실제 출석 및 대학 전체 최신 변경 확인 완료를 뜻하지 않습니다.'
for campus,H in [('seoul','H1'),('global','H2')]:
 path=pathlib.Path('assets/timetable')/f'hufs-{campus}-2026-2.json';old=json.load(open(path));baselines[campus]=old;new=copy.deepcopy(old);candidates[campus]=new
 sources[str(path)]=hashlib.sha256(path.read_bytes()).hexdigest()
 for c in new['courses']:
  if c['schedules']:continue
  sid=c['sourceId'];key=c['courseCode']+c['section'];rr=raw[(H,key)];row=rr[0]['row'];planpath=R/'hufs-public-operating-plans'/f'{H}-{key}.json';plan=json.load(open(planpath));fields=plan['fields'];reasons=[]
  assert all((r['row']['ledgYear'],r['row']['ledgSessn'],r['row']['orgSect'],r['row']['campus'])==('2026','3','A',H)for r in rr)
  assert c['academicYear']==2026 and c['semester']=='2' and c['period']=={'startDate':'2026-09-01','endDate':'2026-12-07'}
  assert mod.clean(row['dayTimeDisplay'])==c['sourceSchedule'];assert c['professor']==mod.clean(row['empNm'])
  try:fixed=mod.meetings(c['sourceSchedule'],clocks[H])
  except ValueError as e:fixed=[];reasons.append('native_unknown_clock_or_format:'+str(e))
  if not fixed:reasons.append('native_no_fixed_group')
  else:normalNativeCount+=1
  if any(r['row']['cyberFlag']=='Y' or r['row']['moocFlag']=='Y' or r['row']['focusLect']for r in rr):reasons.append('native_remote_or_concentrated_flag')
  if plan['campus']!=H or plan['key']!=key or key not in fields.get('identity',''):reasons.append('own_plan_identity_mismatch')
  if fields.get('schedule','').splitlines() and mod.clean(fields['schedule'].splitlines()[0])!=c['sourceSchedule']:reasons.append('own_plan_clock_conflict')
  rawnotes='\n'.join(row.get(k)or''for k in ['etc','etc2'])
  operating='\n'.join(fields.get(k,'')for k in ['methods','notes','delivery']);unknownLines=[]
  for line in (rawnotes+'\n'+operating).splitlines():
   line=line.strip()
   if not line or line in approved:continue
   if remote.search(line) or special.search(line) or re.search(r'\d{1,2}:\d{2}|\d{1,2}시|시간.{0,8}(추후|변경)',line):unknownLines.append(line)
  if unknownLines:reasons.append('actual_operating_constraint_pending')
  if reasons:queue.append({'sourceId':sid,'campus':campus,'key':key,'reason':sorted(set(reasons)),'wholeRawOfferings':rr,'wholePlan':plan,'actualUnknownOperatingLines':unknownLines});continue
  weekly=fields.get('weekly',{});dated={};undated={};excluded=[]
  for wk,text in weekly.items():
   m=datehead.match(text)
   if m:
    try:d=dt.date(2026,int(m[1]),int(m[2]))
    except ValueError:excluded.append({'week':wk,'wholeText':text,'reason':'invalid_literal_date'});continue
    dated[wk]=(d,text)
   else:undated[wk]=text
  mode='literal_date_scope'if dated else'ordinary_native_scope_no_literal_dates'
  allowedDates={};allDays=[]
  if dated:
   for wk,(d,text)in dated.items():
    # Native clock is retained only when own literal date also matches that exact weekday.
    why=[];lines=[l.strip()for l in text.splitlines()if l.strip()];unknown=[l for l in lines if l not in approved and(remote.search(l)or special.search(l))]
    if unknown:why.append('weekly_actual_mode_or_special_pending')
    if noClass.search(text):why.append('own_cancelled_makeup_or_holiday')
    if re.search(r'중간고사|중간시험|기말고사|기말시험|(?i:mid[- ]?term|final\s*exam)',text)and not re.search(r'해설|복습|대비|(?i:explanation|review)',text):why.append('own_evaluation')
    if not dt.date(2026,9,1)<=d<=dt.date(2026,12,7):why.append('outside_current_ordinary_period')
    if d.isoformat()in closed:why.append('official_holiday')
    if not any(f['weekday']==d.isoweekday()for f in fixed):why.append('literal_date_vs_native_weekday_conflict')
    if why:excluded.append({'week':wk,'wholeText':text,'reason':why});continue
    allowedDates[d.isoformat()]=wk
  else:
   for w in range(1,15):
    wk=next((k for k in weekly if re.fullmatch(str(w)+r'(?:st|nd|rd|th)',k)),None);text=weekly.get(wk,'')if wk else''
    # Published but blank weekly row is uncertain; unpublished plan is permitted only via actual ordinary native listing.
    if plan.get('publicPlanMetadataStatus')!='unpublished' and not text.strip():excluded.append({'week':w,'wholeText':text,'reason':'published_week_blank'});continue
    unknown=[l.strip()for l in text.splitlines()if l.strip()and l.strip()not in approved and(remote.search(l)or special.search(l)or noClass.search(l))]
    exam=re.search(r'중간고사|중간시험|기말고사|기말시험|(?i:mid[- ]?term|final\s*exam)',text)and not re.search(r'해설|복습|대비|(?i:explanation|review)',text)
    if unknown or exam:excluded.append({'week':w,'wholeText':text,'reason':'weekly_actual_operation_or_evaluation_pending'});continue
    a=dt.date(2026,9,1)+dt.timedelta(days=7*(w-1))
    for off in range(7):
     d=a+dt.timedelta(days=off)
     if d.isoformat()not in closed:allowedDates[d.isoformat()]=wk or'current_ordinary_native'
  meetings=[]
  for daystr,wk in sorted(allowedDates.items()):
   d=dt.date.fromisoformat(daystr)
   for f in fixed:
    if f['weekday']==d.isoweekday():meetings.append({'date':daystr,**f})
  if len({tuple(m.items())for m in meetings})!=len(meetings):queue.append({'sourceId':sid,'reason':['duplicate_native_group_pending'],'wholeRawOfferings':rr,'wholePlan':plan});continue
  if not meetings:queue.append({'sourceId':sid,'reason':['no_regular_whole_group_survived'],'wholeRawOfferings':rr,'wholePlan':plan,'excluded':excluded});continue
  before=next(z for z in old['courses']if z['sourceId']==sid);archive[sid]=copy.deepcopy(before['departmentRemarks']);c['schedules']=meetings;c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True;c['departmentRemarks']={k:v.replace(warning,'')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'ordinaryNativeOrLiteralDateScope':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'hufs_bulk_v15'}
  sources[str(planpath)]=hashlib.sha256(planpath.read_bytes()).hexdigest();proof.append({'sourceId':sid,'key':key,'campus':campus,'wholeRawOfferings':rr,'wholePlan':plan,'planFile':str(planpath),'sourceSHA256':sources[str(planpath)],'ownPublishedClock':clocks[H],'nativeFixedSlots':fixed,'scope':mode,'allowedDateWeekLiteral':allowedDates,'excludedLiteralGroups':excluded,'unassignedUndatedRows':undated if dated else{},'expectedMeetings':meetings,'previousWholeObject':before,'notesRemovedExact':warning,'actualAttendanceConfirmed':False})
 oldmap={c['sourceId']:c for c in old['courses']};ids={p['sourceId']for p in proof};assert all(c==oldmap[c['sourceId']]for c in new['courses']if c['sourceId']not in ids)
 (P/f'hufs-{campus}-baseline-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');(P/f'hufs-{campus}-2026-2.bulk-v15.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
summary={'SDKExecutions':0,'productWrites':0,'completionClaim':False,'wholeCourseCount':3372,'baselineScheduled':2481,'baselineMeetings':35802,'heldNativeProcessed':891,'heldWithParsableNativeClock':normalNativeCount,'newScheduled':len(proof),'newMeetings':sum(len(p['expectedMeetings'])for p in proof),'queue':len(queue)};assert len(proof)+len(queue)==891;summary['candidateScheduled']=2481+summary['newScheduled'];summary['candidateMeetings']=35802+summary['newMeetings'];summary['queueReasonCounts']=dict(collections.Counter(r for q in queue for r in q['reason']))
(P/'proof.json').write_text(json.dumps({'summary':summary,'proofs':proof,'sourceSHA256':sources,'ownClockCalendarReceipt':receipt},ensure_ascii=False,indent=2)+'\n');(P/'queue.json').write_text(json.dumps(queue,ensure_ascii=False,indent=2)+'\n');(P/'full-previous-note-archive.json').write_text(json.dumps(archive,ensure_ascii=False,indent=2)+'\n');(P/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n');(P/'parser.py').write_text(pathlib.Path(__file__).read_text());print(summary)
