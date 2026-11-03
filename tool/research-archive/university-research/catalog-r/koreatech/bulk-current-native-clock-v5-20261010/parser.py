import json,pathlib,re,copy,hashlib,datetime as dt,collections
R=pathlib.Path('work/university-research/catalog-r/koreatech');P=R/'bulk-current-native-clock-v5-20261010';assert not P.exists();P.mkdir();f=pathlib.Path('assets/timetable/koreatech-unknown-2026-2.json');old=json.load(open(f));new=copy.deepcopy(old);whole=json.load(open(R/'koreatech-2026-2-public-educational-rows-v1.json'));dep=json.load(open(R/'koreatech-mecha-2026-2-educational-rows-v1.json'));calendar=json.load(open(R/'koreatech-current-source-proof-v1.json'));changes=json.load(open(R/'koreatech-current-2026-2-changes-education-v1.json'))
assert len(old['courses'])==791 and sum(bool(c['schedules'])for c in old['courses'])==54
raw={(r['nativeCourseCode'],r['nativeSection']):r for r in whole['rows']};groups=collections.defaultdict(list)
for r in dep['rows']:groups[r['nativeCourseCode'],r['nativeSection']].append(r)
closures={(r['nativeCourseCode'],r['nativeSection'])for r in changes['rows']if '폐'in str(r['changeType'])}
def parse(text):
 out=[];day=None
 if not isinstance(text,str):return out
 for piece in text.replace(' ','').split(','):
  m=re.fullmatch(r'([월화수목금])?(\d+)([AB])?(?:~(\d+)([AB])?)?',piece)
  if not m:raise ValueError('unparsed native period')
  if m[1]:day='월화수목금'.index(m[1])+1
  if day is None:raise ValueError('weekday not published')
  a=int(m[2]);b=int(m[4]or m[2]);sa=m[3]or'A';sb=m[5]or(m[3]if m[3]else'B');lo=(a-1)*2+(sa=='B');hi=(b-1)*2+(sb=='B')
  if hi<lo:raise ValueError('reversed range')
  for i in range(lo,hi+1):
   k=str(i//2+1)+('B'if i%2 else'A');q=dep['clock'].get(k)
   if not q:raise ValueError('unpublished own department clock '+k)
   minute=lambda s:int(s[:2])*60+int(s[3:]);out.append((day,minute(q['start']),minute(q['end'])))
 return out
proof=[];queue=[];archives={};selected={};positiveEligible=0;reasonCounts=collections.Counter();closed={'2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-11-02'}
for c in new['courses']:
 if c['schedules']:continue
 key=c['courseCode'],c['section'];r=raw[key];ds=groups[key];reasons=[]
 assert c['sourceSchedule']==str(r['rawSchedule'])and c['metadata']['originalEducationalFields']==r
 assert r['semester']=='2학기'and c['period']=={'startDate':'2026-08-31','endDate':'2026-12-20'}and c['campus']=='unknown'
 if key in closures:reasons.append('actual_public_native_closure')
 if not ds:reasons.append('applicable_department_clock_not_published_for_this_native_row')
 elif r['openingDepartment']!='메카트로닉스공학부':reasons.append('own_clock_department_scope_mismatch')
 if len(ds)>1 and key[0]!='MTS100':reasons.append('source_code_section_title_clock_conflict')
 if r['educationMode']or any(word in str(r['remarks'])for word in ['군이러닝','장기현장','특수','K-MOOC','온라인']):reasons.append('actual_native_special_operating_mode')
 if any('플립러닝'in str(z['remarks'])for z in ds):reasons.append('actual_flipped_weekly_allocation_unpublished')
 pieces=[]
 if not reasons:
  try:
   for z in ds:
    for period,room in [(z['theoryPeriod'],z['theoryRoom']),(z['practicalPeriod'],z['practicalRoom'])]:
     if period:pieces.extend((*x,''if room is None else str(room))for x in parse(period))
   rawSlots=parse(r['rawSchedule']);assert set(p[:3]for p in pieces)==set(rawSlots)
  except(Exception)as e:reasons.append('native_vs_department_period_alignment_unconfirmed:'+str(e))
 if reasons:
  queue.append({'sourceId':c['sourceId'],'reason':reasons,'originalWholeObject':copy.deepcopy(c),'originalWholeEducationalRow':r,'ownDepartmentRows':ds});reasonCounts.update(reasons);continue
 spans=[]
 for day,start,end,room in sorted(set(pieces)):
  if spans and spans[-1]['weekday']==day and spans[-1]['classroom']==room and spans[-1]['endMinute']==start:spans[-1]['endMinute']=end
  else:spans.append({'weekday':day,'startMinute':start,'endMinute':end,'classroom':room})
 meetings=[];day=dt.date(2026,8,31)
 while day<=dt.date(2026,12,6):
  if day.isoformat()not in closed:meetings.extend({'date':day.isoformat(),**s}for s in spans if s['weekday']==day.isoweekday())
  day+=dt.timedelta(days=1)
 assert meetings;selected[c['sourceId']]=meetings;before=copy.deepcopy(c);archives[c['sourceId']]=c['remarks'];oldReason=c['metadata']['heldReason']
 c['schedules']=meetings;c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
 note='현재 동일 메카트로닉스 강좌 코드·원본 분반·자체 교시와 정규 기간이 일치한 공개 개설 예약입니다. 강의실 미공개 그룹은 빈값으로 유지하며 다른 수업 장소를 빌리지 않습니다. 실제 출석이나 최신 전체 폐강·운영 완료 주장은 아니며 기존 개인 수업 방식은 유지합니다.'
 c['remarks']=c['remarks'].replace(' 예약 보류: '+oldReason,'')+'\n'+note
 # Preserve all native metadata. Only actual stale generated hold state is corrected; physical attendance flags remain false.
 c['metadata']['previousGeneratedHeldReason']=oldReason;c['metadata']['heldReason']='';c['metadata']['publishedOrdinaryReservationConfirmed']=True
 proof.append({'sourceId':c['sourceId'],'previousWholeObject':before,'wholeNativeRow':r,'wholeDepartmentRows':ds,'nativePeriodLiteral':r['rawSchedule'],'ownPublishedClock':dep['clock'],'ownPublishedHalfHourTuples':pieces,'expectedWholeMeetings':meetings,'ordinaryEndLiteral':'2026-12-06','campusMappingConfirmed':False,'actualAttendanceConfirmed':False,'unassignedRoomsPreserved':any(not s['classroom']for s in spans),'sourceProfessorRoleLiteral':[d['professor']for d in ds],'nativeProfessorLiteral':r['professor'],'sourceProfessorRoleNotOverridden':True})
oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']]for c in new['courses']if c['sourceId']not in selected);assert len(proof)+len(queue)==737
summary={'sourceOnly':True,'SDKExecutions':0,'productWrites':0,'completionClaim':False,'processedHeld':737,'wholeNative':791,'baselineScheduled':54,'baselineMeetings':1198,'newScheduled':len(proof),'newMeetings':sum(len(m)for m in selected.values()),'queue':len(queue),'queueReasonCounts':dict(reasonCounts)};summary['candidateScheduled']=54+summary['newScheduled'];summary['candidateMeetings']=1198+summary['newMeetings']
files=[f,R/'koreatech-2026-2-public-educational-rows-v1.json',R/'koreatech-mecha-2026-2-educational-rows-v1.json',R/'koreatech-current-source-proof-v1.json',R/'koreatech-current-2026-2-changes-education-v1.json'];shas={str(z):hashlib.sha256(z.read_bytes()).hexdigest()for z in files}
for fn,v in [('candidate.json',new),('prior-whole.json',old),('proof.json',{'summary':summary,'proofs':proof,'sourceSHA256':shas,'ownCalendar':calendar,'clockSource':{k:v for k,v in dep.items()if k!='rows'}}),('queue.json',queue),('previous-full-remarks-archive.json',archives),('summary.json',summary)]: (P/fn).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
(P/'parser.py').write_text(pathlib.Path(__file__).read_text());print(summary)
