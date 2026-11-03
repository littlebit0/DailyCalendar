from pathlib import Path
import copy,json,re,hashlib,datetime,collections
P=Path(__file__).parent;V7=P.parent/'current-public-broad-followup-v7-20261009';V8=P.parent/'current-public-sejong-followup-v8-20261009'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();save=lambda n,d:(P/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
proof={'scope':'current5339 held1310 source-only audit; initialcandidate onlynoindividualremark/room-onlyholds65; remainingremarks andmedical7 separatependingreview not impossible','oldFrozenSources':{},'ownProofs':{},'selectedNativeSources':[],'heldReasonCensus':{},'candidateCounts':{},'SDKExecuted':False,'completionClaim':False}
allow={'Unresolved native time-room line','No current clock-room allocation','Current native actual room/day unallocated','No current complete actual clock-room block','No complete current native actual clock/room block'}
for campus,V,configfile,clockfile,calendarfile in [('seoul',V7,'source-captured-scope-config.json','current-2026-2-campus-clock-education.json','current-2026-2-calendar-education.json'),('sejong',V8,'source-captured-scope-config-open.json','current-own-sejong-regular-clock-education.json','current-own-sejong-calendar-education.json')]:
 base=Path('assets/timetable')/f'korea-{campus}-2026-2.json';prior=json.loads(base.read_text());save(f'prior-full-{campus}-baseline.json',prior);out=copy.deepcopy(prior)
 clk=json.loads((V/clockfile).read_text()); clock={r['period']:r for r in clk[campus] if True} if campus=='seoul' else {r['period']:r for r in clk['periods']};calendar=json.loads((V/calendarfile).read_text());save(f'reused-own-{campus}-clock-proof.json',clk);save(f'reused-own-{campus}-calendar-proof.json',calendar)
 proof['ownProofs'][campus]={str(f):sha(f) for f in [V/clockfile,V/calendarfile,V/configfile,V/'SHA256.json',base]}
 sources={}
 for conf in json.loads((V/configfile).read_text()):
  f=V/conf['file'];assert sha(f)==conf['sourceSHA256'];d=json.loads(f.read_text());assert d.get('campus',d.get('selectedCampus'))==('서울' if campus=='seoul' else '세종')
  for raw in d['rows']:sources.setdefault(raw['COUR_CD']+'-'+raw['COUR_CLS'],[]).append({'sourceFile':str(f),'sourceSHA256':sha(f),'originalWholeNativeFields':raw})
 selected=[];held=[]
 for c in out['courses']:
  if c['schedules']:continue
  raw=c.get('sourceEducationalMetadata');decision=''
  if not raw:decision='opaque source identity missing current native offering code'
  else:
   ident=raw['COUR_CD']+'-'+raw['COUR_CLS'];assert sources.get(ident);assert any(s['originalWholeNativeFields']==raw for s in sources[ident])
   parsed=[]
   for l in raw['TIME_ROOM'].splitlines():
    m=re.fullmatch(r'([월화수목금토일])\(([\d,~\-]+)\)\s*',l.strip())
    if not m:parsed=[];break
    periods=[]
    for part in m[2].split(','):
     b=[int(v) for v in re.split('[-~]',part)];periods+=list(range(b[0],b[-1]+1))
    parsed.extend(('월화수목금토일'.index(m[1])+1,n) for n in periods)
   if not parsed:decision='no complete native ownweekday numeric clock-only blocks'
   elif any(n not in clock for _,n in parsed):decision='own actual period unpublished; no calculated HH'
   elif raw['MOOC_YN']=='1' or raw.get('FLEXIBLE_SCHOOL_YN') or raw['FLEXIBLE_FR_DT'] or raw['FLEXIBLE_TO_DT']:decision='explicit MOOC or flexible operation, own actual dates unconfirmed'
   elif raw['APPLY_DEPT'].strip():decision='individual native remark requires separate operating review'
   elif set(c.get('sourceOperatingHolds',[]))-allow:decision='specific existing operating hold preserved'
   elif raw['COUR_CD'].startswith('PMED'):decision='medical operating calendar consistency pending separate review; no impossibility/generic-exclusion claim'
   else:
    unique=sorted(set(parsed));segments=[{'weekday':day,'sourcePeriod':n,'startMinute':clock[n]['startMinute'],'endMinute':clock[n]['endMinute'],'classroom':''} for day,n in unique]
    originalHolds=copy.deepcopy(c.get('sourceOperatingHolds',[]));originalSource=copy.deepcopy(c)
    ss=[];date=datetime.date.fromisoformat(calendar['semesterStart'])
    while str(date)<=calendar['ordinaryReservationEndDerived']:
     ds=str(date)
     if ds not in calendar['holidays'] and not calendar['midtermStart']<=ds<=calendar['midtermEnd']:
      for s in segments:
       if date.isoweekday()==s['weekday']:ss.append({k:v for k,v in s.items() if k!='sourcePeriod'}|{'date':ds})
     date+=datetime.timedelta(days=1)
    c['schedules']=ss;c['scheduleStatus']='scheduled';c['sourceOperatingHolds']=[];c['sourceCurrentClockSegments']=segments;c['sourceRoomUnpublished']=True;c['sourceOriginalOperatingHolds']=originalHolds;c['sourceOperatingAudit']='own published weekday/period/currentcampus/currentregularsemester, roomunpublishedblanknot schedulingblock';c['sourcePartialCoverage']=False
    # Preserve original note/holds verbatim as historical provenance; make current status explicit.
    c['remarks']=c.get('remarks','')+' 현재 재검토: 원문 요일·교시는 확정이고 강의실만 미공개여서 장소는 빈 값으로 유지한 정규 예약입니다. 위 원문 일정보류 문구는 이전 판정 기록이며 현재는 수업 시각 예약이 가능함. 원문 교수·학수번호·분반·학점·구분·캠퍼스·기간·비고·전체 교육필드는 그대로 보존. 실제출석·개별시험·보강·최신폐강확인아님. 다른강좌/요일장소차용0.'
    record={'campus':campus,'sourceId':c['sourceId'],'identity':ident,'originalFullCourseObject':originalSource,'originalNativeCaptures':sources[ident],'independentPublishedClockSegments':segments,'newReservationCount':len(ss),'rawRemarkExactlyEmpty':True,'roomUnpublished':True,'originalHolds':originalHolds}
    selected.append(record);proof['selectedNativeSources'].append(record);decision='eligible own clock; source room unpublished only'
  held.append({'sourceId':c['sourceId'],'nativeSchedule':c['sourceSchedule'],'sourceOperatingHolds':c.get('sourceOriginalOperatingHolds',c.get('sourceOperatingHolds',[])),'decision':decision,'wholeNativeFields':raw})
 ids={r['sourceId'] for r in selected};assert all(a==b for a,b in zip(prior['courses'],out['courses']) if b['sourceId'] not in ids)
 for a,b in zip(prior['courses'],out['courses']):
  if b['sourceId'] in ids:
   for k in ['sourceId','campus','academicYear','semester','courseCode','section','courseName','professor','classification','credits','departments','departmentCredits','departmentClassifications','sourceSchedule','sourceClassroom','sourceEducationalMetadata','period']:assert a.get(k)==b.get(k)
 out['researchOnly']=True;out['completionClaim']=False;out['researchRevision']='native-blank-room-own-clock-v9-source-only';save(f'korea-{campus}-2026-2.blank-room-own-clock-v9.json',out)
 proof['heldReasonCensus'][campus]={'allPreviouslyHeld':len(held),'decisions':dict(collections.Counter(r['decision'] for r in held)),'rows':held};proof['candidateCounts'][campus]={'newScheduled':len(selected),'newReservations':sum(r['newReservationCount'] for r in selected),'whole':len(out['courses']),'scheduled':sum(bool(c['schedules']) for c in out['courses']),'reservations':sum(len(c['schedules']) for c in out['courses'])}
save('whole-native1310-held-source-operating-audit.json',proof);print(proof['candidateCounts'])
