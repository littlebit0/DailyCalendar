from pathlib import Path
import copy,json,re,hashlib,datetime,collections
P=Path(__file__).parent;V9=P.parent/'blank-room-own-clock-audit-v9-20261009';V7=P.parent/'current-public-broad-followup-v7-20261009';V8=P.parent/'current-public-sejong-followup-v8-20261009'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();save=lambda n,d:(P/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
eligible={'seoul':{'KLLE218-00','LIBT201-00','CHEM214-01','CHEM214-02','CHEM214-04','BUSS166-01','BUSS166-02','BUSS166-03','BUSS166-04','BUSS166-05','BUSS166-06','MATH166-01','IFLS812-00','IFLS814-00','SPGE225-00','SPGE261-00','SPGE262-00','SPGE263-01','UNIV402-01','UNIV506-00','LIET152-01'}|{f'UNIV021-{n:02d}' for n in range(1,16)},'sejong':{'GSKS006-'+x for x in ['05','09','11','12','13','14','43','44','46','72','73','74','75','76','82','83','84','85','86','92','93','94','95','96','97','98','C2','C3','C4','C5','C6','E3','E4','E5','S2','S3','S4','S5','T3','T4','T5','U2','U3']}}
rooms={'KLLE218-00':'교육관 507호','SPGE225-00':'SK미래관 김양현홀','SPGE261-00':'아주홀','SPGE262-00':'아주홀','SPGE263-01':'한국일보홀','UNIV402-01':'녹지운동장 트랙','UNIV506-00':'PBL219(SK미래관)'}
proof={'scope':'79 individually reviewed remarkful own-clock native rows, chained full5339/4094/124874v9 preserving targets/grade/restrictions without claiming personaleligibility','oldFrozenSources':{},'ownProofs':{},'selectedNativeSources':[],'heldReasonCensus':{},'candidateCounts':{},'SDKExecuted':False,'completionClaim':False}
allow={'Unresolved native time-room line','No current clock-room allocation','Current native actual room/day unallocated','No current complete actual clock-room block','No complete current native actual clock/room block'}
for campus,V,configfile,clockfile,calendarfile in [('seoul',V7,'source-captured-scope-config.json','current-2026-2-campus-clock-education.json','current-2026-2-calendar-education.json'),('sejong',V8,'source-captured-scope-config-open.json','current-own-sejong-regular-clock-education.json','current-own-sejong-calendar-education.json')]:
 base=V9/f'korea-{campus}-2026-2.blank-room-own-clock-v9.json';prior=json.loads(base.read_text());save(f'prior-full-{campus}-baseline.json',prior);out=copy.deepcopy(prior)
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
   elif ident not in eligible[campus]:decision='not selected: own specific individual allocation/mode/date remains held'
   else:
    unique=sorted(set(parsed));segments=[{'weekday':day,'sourcePeriod':n,'startMinute':clock[n]['startMinute'],'endMinute':clock[n]['endMinute'],'classroom':rooms.get(ident,'')} for day,n in unique]
    if ident in rooms:assert rooms[ident] in raw['APPLY_DEPT']
    originalHolds=copy.deepcopy(c.get('sourceOperatingHolds',[]));originalSource=copy.deepcopy(c)
    ss=[];date=datetime.date.fromisoformat(calendar['semesterStart'])
    while str(date)<=calendar['ordinaryReservationEndDerived']:
     ds=str(date)
     if ds not in calendar['holidays'] and not calendar['midtermStart']<=ds<=calendar['midtermEnd']:
      for s in segments:
       if date.isoweekday()==s['weekday']:ss.append({k:v for k,v in s.items() if k!='sourcePeriod'}|{'date':ds})
     date+=datetime.timedelta(days=1)
    c['schedules']=ss;c['scheduleStatus']='scheduled';c['sourceOperatingHolds']=[];c['sourceCurrentClockSegments']=segments;c['sourceRoomUnpublished']=ident not in rooms;c['sourceRemarkPublishedRoomLiteral']=rooms.get(ident,'');c['sourceOriginalTargetRestrictionRemark']=raw['APPLY_DEPT'];c['personalEnrollmentEligibilityClaim']=False;c['sourceOriginalOperatingHolds']=originalHolds;c['sourceOperatingAudit']='own published weekday/period/currentcampus/currentregularsemester; exactremark individuallyreviewed restriction/OT-only/completeonevenue; no personaleligibilityclaim';c['sourcePartialCoverage']=False
    # Preserve original note/holds verbatim as historical provenance; make current status explicit.
    c['remarks']=c.get('remarks','')+' 현재 재검토: 원문 요일·교시는 확정이며 비고는 대상학과·학년·우선수강·OT장소·참고자료 또는 완전한 단일 정규장소로 개별검토했습니다. 대상제한과 원문비고 전체를 보존하며 개인 수강허용을 추정하지 않습니다. 정규장소 미공개이면 빈값 유지, OT장소를 정규장소로 차용하지 않습니다. 위 원문 일정보류 문구는 이전 판정 기록이며 현재는 수업 시각 예약이 가능함. 원문 교수·학수번호·분반·학점·구분·캠퍼스·기간·비고·전체 교육필드는 그대로 보존. 실제출석·개별시험·보강·최신폐강확인아님. 다른강좌/요일장소차용0.'
    record={'campus':campus,'sourceId':c['sourceId'],'identity':ident,'originalFullCourseObject':originalSource,'originalNativeCaptures':sources[ident],'independentPublishedClockSegments':segments,'newReservationCount':len(ss),'fullTargetRestrictionRemarkPreserved':raw['APPLY_DEPT'],'personalEligibilityClaim':False,'selectedRemarkRoomLiteral':rooms.get(ident,''),'roomUnpublished':ident not in rooms,'originalHolds':originalHolds}
    selected.append(record);proof['selectedNativeSources'].append(record);decision='eligible own clock; source room unpublished only'
  held.append({'sourceId':c['sourceId'],'nativeSchedule':c['sourceSchedule'],'sourceOperatingHolds':c.get('sourceOriginalOperatingHolds',c.get('sourceOperatingHolds',[])),'decision':decision,'wholeNativeFields':raw})
 ids={r['sourceId'] for r in selected};assert all(a==b for a,b in zip(prior['courses'],out['courses']) if b['sourceId'] not in ids)
 for a,b in zip(prior['courses'],out['courses']):
  if b['sourceId'] in ids:
   for k in ['sourceId','campus','academicYear','semester','courseCode','section','courseName','professor','classification','credits','departments','departmentCredits','departmentClassifications','sourceSchedule','sourceClassroom','sourceEducationalMetadata','period']:assert a.get(k)==b.get(k)
 out['researchOnly']=True;out['completionClaim']=False;out['researchRevision']='remarkful-own-clock-reviewed-v10-source-only';save(f'korea-{campus}-2026-2.remarkful-own-clock-v10.json',out)
 proof['heldReasonCensus'][campus]={'allPreviouslyHeld':len(held),'decisions':dict(collections.Counter(r['decision'] for r in held)),'rows':held};proof['candidateCounts'][campus]={'newScheduled':len(selected),'newReservations':sum(r['newReservationCount'] for r in selected),'whole':len(out['courses']),'scheduled':sum(bool(c['schedules']) for c in out['courses']),'reservations':sum(len(c['schedules']) for c in out['courses'])}
save('whole-remaining1245-native79-remark-operating-audit.json',proof);print(proof['candidateCounts'])
