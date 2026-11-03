"""Whole held native audit; only independently complete own-campus groups. No network/SDK."""
import pathlib,json,re,copy,hashlib,datetime,collections,shutil,sys
b=pathlib.Path(__file__).parent;repo=b.parents[2];out=b/'yonsei-korea-held-native-bulk-v13-20261010';assert not (out/'SHA256.json').exists();out.mkdir(exist_ok=True)
def load(f):return json.load(open(f))
def write(n,d):(out/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
yproof=b/'yonsei-held-native-clock-blanket-audit-v5-20261009';clockproof=load(yproof/'current-native-clock-proof-v1.json');ycal=load(yproof/'own-current-term-calendar-educational-proof.json');yk={r['period']:(r['startMinute'],r['endMinute']) for r in clockproof[0]['nativeClockRows']};assert set(yk)==set(range(11));assert all({r['period']:(r['startMinute'],r['endMinute']) for r in p['nativeClockRows']}==yk for p in clockproof)
for name in ['current-native-clock-proof-v1.json','own-current-term-calendar-educational-proof.json','current-mirae-official-legend.json']:shutil.copyfile(yproof/name,out/name)
v8=b/'yonsei-h1-published-mode-segments-v8-20261009'
# Existing own H1 published video/live classroom legend; never borrow H2 parentheses.
for f in v8.iterdir():
 if f.name.endswith('.json') and any(w in f.name for w in ['mode-legend','guide-education','page7','page-7','mode-native']):shutil.copyfile(f,out/f.name)
rawpath=repo/'work/university-research/catalog-d/yonsei-2026-2-public-all.json';raw=load(rawpath);rawidx=collections.defaultdict(list)
for r in raw['records']:rawidx[(r['sysinstDivCd'],r['subjtnbCorsePrcts'])].append(r)
KU=repo/'work/university-research/catalog-r/ku/blank-room-own-clock-audit-v9-20261009';kclocks={};kcals={}
for campus in ['seoul','sejong']:
 kclocks[campus]=load(KU/f'reused-own-{campus}-clock-proof.json');kcals[campus]=load(KU/f'reused-own-{campus}-calendar-proof.json');shutil.copyfile(KU/f'reused-own-{campus}-clock-proof.json',out/f'korea-{campus}-clock-proof.json');shutil.copyfile(KU/f'reused-own-{campus}-calendar-proof.json',out/f'korea-{campus}-calendar-proof.json')
DAYS='월화수목금토일';base={};datasets={};queue=[];changed=[]
# Independent native group reader, complete group or held, never prefix cut.
def grammar(text):
 p=[];pos=0
 for m in re.finditer(r'\([^()]*\)',text):
  if m.start()>pos:p.append(('lecture',text[pos:m.start()]))
  p.append(('practice',m[0][1:-1]));pos=m.end()
 if pos<len(text):p.append(('lecture',text[pos:]))
 if any('(' in x or ')' in x for k,x in p):raise ValueError('unmatched own group syntax')
 return p

def plain(t):
 matches=list(re.finditer(r'([월화수목금토])(\d+(?:,\d+)*)',t));
 if not matches or ','.join(m[0] for m in matches)!=t:return None
 periods=[(DAYS.index(m[1])+1,int(n)) for m in matches for n in m[2].split(',')]
 return periods if all(n in yk for wd,n in periods) else None

def ygroups(e):
 ts=(e.get('lctreTimeNm') or '').split('/');rs=(e.get('lecrmNm') or '').split('/');inst=e['sysinstDivCd'];result=[];slots=[]
 if len(ts)!=len(rs):return [],[],['nativeSlashGroupCountMismatch']
 # H1 opaque parenthesis applies to whole original cell, not an isolated suffix.
 if inst=='H1' and any(x in (e.get('lctreTimeNm') or '')+(e.get('lecrmNm') or '') for x in '()'):
  # Known recorded-room literal parentheses are part of the published video label, not a time practice symbol.
  if '(' in (e.get('lctreTimeNm') or '') or ')' in (e.get('lctreTimeNm') or '') or any(('(' in r or ')' in r) and r!='동영상(중복수강불가)' for r in rs):return [],[],['H1WholeCellParenthesisMeaningUnconfirmed']
 for index,(t,r) in enumerate(zip(ts,rs)):
  if r in ['동영상콘텐츠','동영상(중복수강불가)']:
   result.append({'sourceGroupIndex':index,'kind':'recorded','nativeTime':t,'nativeRoom':r,'reserved':False,'overlapAllowed':r=='동영상콘텐츠'});continue
  if inst=='H2':
   try:tg=grammar(t);rg=grammar(r)
   except ValueError:return [],[],['nativeGroupSyntaxUnconfirmed']
   if len(rg)==1 and rg[0][0]=='lecture':rg=[(kind,rg[0][1]) for kind,x in tg]
   if [k for k,x in tg]!=[k for k,x in rg]:return [],[],['ownLecturePracticeRoomKindsMismatch']
  else:tg=[('lecture',t)];rg=[('lecture',r)]
  for sub,((kind,t),(rk,r)) in enumerate(zip(tg,rg)):
   parsed=plain(t);group={'sourceGroupIndex':index,'sourceSubgroupIndex':sub,'kind':kind,'nativeTime':t,'nativeRoom':r,'reserved':False}
   if parsed is None or not r or any(x in r for x in ['미정','배정','동영상','콘텐츠']):group['heldReason']='wholeGroupClockOrRoomUnconfirmed';result.append(group);continue
   group['reserved']=True;group['nativePeriods']=[n for wd,n in parsed];result.append(group)
   for wd,n in parsed:slots.append({'weekday':wd,'sourcePeriod':n,'startMinute':yk[n][0],'endMinute':yk[n][1],'classroom':r,'deliveryMode':'liveOnline' if r=='실시간온라인' else 'inPerson','sourceGroupIndex':index,'sourceSubgroupIndex':sub,'nativeGroupKind':kind})
 return result,slots,[]

for school,campuses in [('yonsei',['sinchon','international','mirae','unknown']),('korea',['seoul','sejong'])]:
 for campus in campuses:
  key=f'{school}-{campus}';f=repo/'assets/timetable'/f'{key}-2026-2.json';d=load(f);base[key]=copy.deepcopy(d);shutil.copyfile(f,out/f'baseline-{key}-2026-2.json')
  for c in d['courses']:
   if c['schedules']:continue
   reasons=[];segments=[];slots=[];own=c.get('sourceEducation',c.get('sourceEducationalMetadata'));rawclock=c['sourceSchedule'] or '';ownnotes=[]
   if school=='yonsei':
    e=own[0];inst=e['sysinstDivCd'];mode=(e.get('subjtClNm') or '').strip();ownnotes=[r.get('atntnMattrDesc') or '' for r in own];notes='\n'.join(ownnotes)
    rawmatches=rawidx[(inst,e['subjtnbCorsePrcts'])];assert all(any(all(n.get(k)==v for k,v in r.items()) for n in rawmatches) for r in own)
    if e.get('syy')!='2026' or e.get('smtDivCd')!='20' or e['rmvlcYn']!='0':reasons.append('sourceSemesterOrClosureConflict')
    if inst not in ['H1','H2']:reasons.append('ownInstitutionClockAndPeriodMissing')
    if e.get('lessnSessnDivNm')!='학기':reasons.append('sourceNonRegularSession')
    if c['courseCode'].startswith('UCR'):reasons.append('actualRCOperatingDatesUnconfirmed')
    if re.search('현장실습|인턴|개별연구|독립연구|사회봉사|연구지도|연구프로젝트',c['courseName']):reasons.append('explicitIndividualOperationScopeUnconfirmed')
    if mode not in ['대면강의','비대면(실시간)','블랜디드(동영상)','블랜디드(실시간+동영상)','비대면(실시간+동영상)']:reasons.append('sourceModeAssignmentNotFixed')
    if inst in ['H1','H2']:segments,slots,gap=ygroups(e);reasons+=gap
    if not slots:reasons.append('noIndependentlyCompleteOwnClockGroup')
    # Enrolment-change period is eligibility context, not actual contact-day change.
    contactnotes=re.sub(r'수강(?:신청\s*)?\s*변경\s*기간','[enrolment change period]',notes)
    if re.search(r'75분|집중|격주|블록|실제\s*수업시간|별도|현장|대면수업주차|주차별|주별|분반별|추후|사전협의|수업.*변경|변경.*수업',contactnotes):reasons.append('sourceActualContactOperatingConditionNeedsEvidence')
    if any(r.get(k)!=e.get(k) for r in own for k in ['lctreTimeNm','lecrmNm','subjtClNm','lessnSessnDivNm','cgprfNm','syy','smtDivCd','rmvlcYn']):reasons.append('nativeCrossAffiliationOperatingFieldsConflict')
   else:
    if not isinstance(own,dict) or 'TIME_ROOM' not in own:reasons.append('separateDocumentNativeAllocationUnconfirmed')
    else:
     r=own;ownnotes=[r.get('APPLY_DEPT') or ''];clockrows=kclocks[campus]['seoul'] if campus=='seoul' else kclocks[campus]['periods'];kt={z['period']:z for z in clockrows};groupmap=collections.defaultdict(set);valid=True
     for line in r['TIME_ROOM'].splitlines():
      m=re.fullmatch(r'([월화수목금토일])\(([\d,~\-]+)\)\s*(.*)',line.strip())
      if not m:valid=False;break
      for part in m[2].split(','):
       ns=[int(x) for x in re.split('[-~]',part)]
       for n in range(ns[0],ns[-1]+1):groupmap[(DAYS.index(m[1])+1,n)].add(m[3])
     if not valid or not groupmap:reasons.append('sourceWeeklyDayPeriodsMissingOrNonRegular')
     if any(n not in kt for wd,n in groupmap):reasons.append('ownNativePeriodHHUnpublished')
     if any(len(rooms)>1 for rooms in groupmap.values()):reasons.append('sourceSimultaneousDifferentClassroomsAllocationUnconfirmed')
     if r.get('YEAR')!='2026' or r.get('TERM')!='2R' or r.get('CAMPUS')!=('서울' if campus=='seoul' else '세종'):reasons.append('sourceSemesterCampusMismatch')
     if r.get('MOOC_YN')=='1' or r.get('NEMO_YN')=='1':reasons.append('sourceMOOCNeMoDatedContactUnknown')
     if r.get('FLEXIBLE_SCHOOL_YN') or r.get('FLEXIBLE_FR_DT') or r.get('FLEXIBLE_TO_DT') or re.search('유연학기|Flexible Term|Intensive Course',r.get('APPLY_DEPT',''),re.I):reasons.append('sourceFlexibleOperationDatesUnknown')
     if c['courseCode'].startswith('PMED'):reasons.append('ownMedicalCalendarAndClockScopeUnconfirmedDeniedRouteNotRetried')
     if re.search('혼합|별도|홈페이지.*참조|일정.*참조|이론|실습|교시|강의실|아이스링크|체육생활관|화정체육관|수영장|테니스|골프장|8:40',r.get('APPLY_DEPT','')):reasons.append('sourceExplicitActualClockOrVenueAllocationNeedsEvidence')
     specific=[x for x in c.get('sourceOperatingHolds',[]) if x not in ['No current complete actual clock-room block','No complete current native actual clock/room block','Unresolved native time-room line','No current clock-room allocation','Current native actual room/day unallocated']]
     if specific:reasons.append('specificPriorSourceOperatingConstraintPreserved')
     if not reasons:
      slots=[{'weekday':wd,'sourcePeriod':n,'startMinute':kt[n]['startMinute'],'endMinute':kt[n]['endMinute'],'classroom':next(iter(rooms))} for (wd,n),rooms in sorted(groupmap.items())]
   entry={'school':school,'campus':campus,'sourceId':c['sourceId'],'courseCode':c['courseCode'],'section':c['section'],'originalNativeEducation':own,'originalNativeEducationSHA256':hashlib.sha256(json.dumps(own,sort_keys=True,ensure_ascii=False).encode()).hexdigest(),'rawNativeClock':rawclock,'rawNativeRoom':c['sourceClassroom'],'sourceOwnNotesOnly':ownnotes,'researchWarningUsedAsNativeSourceConstraint':False,'parserHeldReasons':sorted(set(reasons)),'parsedWholeGroups':segments,'knownWholeSlotsNotAutomaticallyProjected':slots,'actualAttendanceClaim':False,'humanWholeSyllabusReadClaim':False}
   if reasons:entry['result']='held';queue.append(entry);continue
   if school!='yonsei':raise RuntimeError('New Korea eligible primary row requires narrow proof instead of silent generation')
   old=copy.deepcopy(c);plans=[];day=datetime.date.fromisoformat(ycal['reservationStartDate']);end=datetime.date.fromisoformat(ycal['reservationEndDate']);holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
   while day<=end:
    if day.isoformat() not in holidays and not ycal['excludedMidtermStart']<=day.isoformat()<=ycal['excludedMidtermEnd']:
     plans.extend({**s,'date':day.isoformat()} for s in slots if s['weekday']==day.isoweekday())
    day+=datetime.timedelta(days=1)
   assert plans
   note='학교 자체2026-2 범례·교시·학기기간 및 정확 native교육행의 서로 독립된 완전한 그룹만 부분예정예약으로 반영합니다. H1수강신청/수강변경기간은 수업운영변경이 아닌 원문 수강자격 문맥이며 이를 시간보류의 근거로 사용하지 않습니다. H2괄호는 미래 자체 강의/실습 범례만 적용하고 H1괄호 의미는 추정하지 않습니다. 11교시 이후가 섞인 하나의 group 전체는 보류하며 알려진 앞부분을 잘라 예약하지 않았습니다. 영상/미공표그룹 전체원문·요일/교시·교실·중복허용조건을 아래원문과 publishedModeSegments에 보존합니다. 날짜는 native매주요일+자체정규기간에서 파생된 계획이며 개별인쇄일자·실제출석·최신취소/시험/보강확인 아님입니다. 기본 사용자강의모드는 유지하고 자체범례로 확인한 대면/실시간 그룹 날짜에만 override합니다. 학기말 자율학습/보충·시험·중간시험/국가휴일 제외, 미확정영상출석예약0. 학교전체완료·수업전체완전지원 주장0.'
   c.update(schedules=plans,scheduleStatus='scheduled',partialCoverage=True,publishedModeSegments=segments,priorHeldResearchRemarks=old['remarks'],priorHeldDepartmentRemarks=old['departmentRemarks'],remarks=note+'\n[이전 연구 원문]\n'+old['remarks'],departmentRemarks={k:note+'\n[이전 연구 원문]\n'+v for k,v in old['departmentRemarks'].items()})
   c['nativeBulkScopeProof']={'sourceOnly':True,'SDKExecuted':False,'productModified':False,'wholeOriginalSourceEducationUnchanged':True,'ownInstitution':e['sysinstDivCd'],'ownCalendarSource':'own-current-term-calendar-educational-proof.json','ownClockSource':'current-native-clock-proof-v1.json','sourceH1VideoLegend':{'PDFSHA256':'5d46c008e7b4a3f690a3f0a3d1a05a30d2c076d1b383fd55b2485be62ec16822','physicalPage':7,'printedPage':5},'H2ParenthesisLegendBorrowedForH1':False,'allUnknownGroupReservations':0,'wholeNativeGroupSourcePreserved':True,'sourcePrintedIndividualDates':False,'actualAttendanceConfirmed':False}
   entry.update(result='eligibleIndependentWholeGroupPartialOnly',expectedSchedulesCalendarDerived=plans);queue.append(entry);changed.append(entry)
  datasets[key]=d;write(f'{key}-2026-2.native-bulk-v13.json',d)
allold=[c for d in base.values() for c in d['courses']];allnew=[c for d in datasets.values() for c in d['courses']];ids={x['sourceId'] for x in changed};idx={c['sourceId']:c for c in allnew};assert all(c==idx[c['sourceId']] for c in allold if c['sourceId'] not in ids)
counts={}
for school in ['yonsei','korea']:
 prior=[c for k,d in base.items() if k.startswith(school+'-') for c in d['courses']];after=[c for k,d in datasets.items() if k.startswith(school+'-') for c in d['courses']];counts[school]={'wholeOfferings':len(after),'priorScheduledScopes':sum(bool(c['schedules']) for c in prior),'priorMeetings':sum(len(c['schedules']) for c in prior),'newScheduledScopes':sum(r['school']==school for r in changed),'newMeetings':sum(len(r['expectedSchedulesCalendarDerived']) for r in changed if r['school']==school),'resultScheduledScopes':sum(bool(c['schedules']) for c in after),'resultMeetings':sum(len(c['schedules']) for c in after),'remainingHeld':sum(not c['schedules'] for c in after)}
write('all-current-held-native-processing-queue.json',queue);write('independent-native-group-calendar-validation.json',{'sourceOnly':True,'SDKExecuted':False,'productModified':False,'counts':counts,'processedPreviouslyHeld':len(queue),'allOtherWholeObjectsExact':len(allold)-len(changed),'byCourse':changed,'humanWholeReadAdded':0,'rawSourceCensusFile':str(rawpath),'rawSourceCensusSHA256':hashlib.sha256(rawpath.read_bytes()).hexdigest(),'individualDatesPrintedClaim':False});write('processing-progress.json',{'sourceOnly':True,'SDKExecuted':False,'productModified':False,'completionClaim':False,'counts':counts,'processedPreviouslyHeld':len(queue),'categories':dict(collections.Counter(r['result'] for r in queue)),'sourceReasons':dict(collections.Counter(x for r in queue for x in r['parserHeldReasons'])),'networkRequests':0,'humanWholeReadAdded':0,'updatedAt':datetime.datetime.now().astimezone().isoformat()})
shutil.copyfile(__file__,out/pathlib.Path(__file__).name);print(json.dumps(counts,ensure_ascii=False))
