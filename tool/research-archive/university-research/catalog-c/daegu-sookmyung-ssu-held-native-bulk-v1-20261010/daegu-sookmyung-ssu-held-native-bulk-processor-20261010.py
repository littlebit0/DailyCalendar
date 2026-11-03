"""One cached source-condition audit. No new per-packet SDK or network."""
import pathlib,json,re,copy,hashlib,collections,datetime,ast,shutil
b=pathlib.Path(__file__).parent;repo=b.parents[2];out=b/'daegu-sookmyung-ssu-held-native-bulk-v1-20261010';out.mkdir(exist_ok=False)
def load(f):return json.load(open(f))
def write(n,d):(out/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
sourceSSU=repo/'work/university-research/catalog-f/ssu';m=ast.parse((sourceSSU/'weekly-reservations-v4-20261008/prepare_research_candidate.py').read_text());parts=[n for n in m.body if isinstance(n,ast.FunctionDef) and n.name=='parse' or isinstance(n,ast.Assign) and any(isinstance(x,ast.Name) and x.id=='head' for x in n.targets)];env={'re':re};exec(compile(ast.Module(body=parts,type_ignores=[]),'existing-ssu-source-reader','exec'),env);ssuparse=env['parse']
ssuplans={}
for name in ['ssu-current-public-korean-major-plans-20261008.json','ssu-current-public-korean-major-next20-plans-20261008.json']:
 for p in load(sourceSSU/name)['publicTeachingFields']:ssuplans[p['nativeCourseId']]=p
DU=b/'daegu-current-20261008';special=set(load(DU/'special-operation-registration-numbers.json'));law=load(DU/'law-update-educational-notices.json');queue=[];counts={};possible=[]
for school,campuses in [('daegu',['main']),('sookmyung',['first','second','unknown']),('ssu',['main'])]:
 schoolcounts={'wholeOfferings':0,'previouslyScheduled':0,'priorMeetings':0,'heldProcessed':0,'newScheduledScopes':0,'newMeetings':0};reasoncounts=collections.Counter()
 for campus in campuses:
  key=f'{school}-{campus}';f=repo/'assets/timetable'/f'{key}-2026-2.json';d=load(f);shutil.copyfile(f,out/f'baseline-{key}-2026-2.json');shutil.copyfile(f,out/f'{key}-2026-2.native-bulk-unchanged.json');schoolcounts['wholeOfferings']+=len(d['courses']);schoolcounts['previouslyScheduled']+=sum(bool(c['schedules']) for c in d['courses']);schoolcounts['priorMeetings']+=sum(len(c['schedules']) for c in d['courses'])
  for c in d['courses']:
   if c['schedules']:continue
   reasons=[];native={};parsed=[];plan=None
   if school=='daegu':
    native=c['publicEducationRows'];ident=c['courseCode'];edu=[r['education'] for r in native];fields=['강의시간','강의실','담당교수','학점']
    if str(ident) in special:reasons.append('ownPublishedSpecialRemoteBlendedOrIntensiveTable')
    if any(len({e.get(k,'').strip() for e in edu})>1 for k in fields):reasons.append('currentNativeAliasesClockRoomProfessorOrCreditConflict')
    times=edu[0].get('강의시간','') or '';rooms=edu[0].get('강의실','') or '';parsed=re.findall(r'([월화수목금토일])\((\d\d?:\d\d)-(\d\d?:\d\d)\)',times)
    if not parsed:reasons.append('noPublishedFixedWeeklyHH')
    if '\n' in rooms or ',' in rooms:reasons.append('nativeMultipleVenuesWithoutExactPerMeetingAllocation')
    if not rooms:reasons.append('nativeClassroomUnpublished')
    if re.search(r'집중|MOOC|MOO\s*C|가상|블렌디드|원격|사이버',rooms+' '+' '.join(e.get('비고','') for e in edu),re.I):reasons.append('nativeSpecificDeliveryOperationUnallocated')
    if any(c['courseName'] in ['친족상속법','가족법'] or x in c.get('courseNameAliases',[]) for x in ['친족상속법','가족법']):reasons.append('ownPublishedCurrentRoomChangeLacksExactRegistrationJoin')
    if ident=='2204':reasons.append('ownCurrentFridayChangeAndProspectiveTuesdayChangeEffectivePeriodUnconfirmed')
   elif school=='sookmyung':
    native=c['metadata']['originalEducationalRecords'];edu=[r['values'] for r in native];values=edu[0];critical=['강의형태','강의시간','담당교수','교수법']
    if any(len({e.get(k,'') for e in edu})>1 for k in critical):reasons.append('nativeAliasOperatingFieldsConflict')
    if any('BL' in e.get('교수법','') for e in edu):reasons.append('ownNativeBLPhysicalRecordedWeekAllocationUnpublished')
    if any(re.search('녹화|원격|비대면|사이버',e.get('강의형태','')+' '+e.get('강의시간','')) for e in edu):reasons.append('ownNativeRemoteDatedContactUnassigned')
    times=values.get('강의시간') or '';parsed=re.findall(r'([월화수목금토일]+)\s*(\d\d?:\d\d)-(\d\d?:\d\d)\(([^()]+)\)',times)
    if not parsed:reasons.append('exactNativeWeeklyClockRoomUnavailable')
    groupmap=collections.defaultdict(set)
    for days,a,z,room in parsed:
     for day in days:groupmap[(day,a,z)].add(room)
    if any(len(rooms)>1 for rooms in groupmap.values()):reasons.append('ownConcurrentDifferentRoomAssignmentUnpublished')
    sourceNotes=' '.join(e.get('수강유의사항','')+' '+e.get('강의시간','') for e in edu)
    if re.search(r'\d+\s*(?:~|-|∼)\s*\d+\s*주|주차|집중|현장실습|교육실습|보육실습|실습기관|외부|격주|개별|수요일.*금요일|수.*금.*선택',sourceNotes):reasons.append('ownSpecificWeekIntensiveExternalOrIndividualOperationUnassigned')
    # These are full-quote previous source-specific reviews, not generic attendance warnings.
    specific=[x for x in c['metadata'].get('holdReasons',[]) if x not in ['BL individual physical/remote sessions unpublished','two native classrooms at the same weekday and clock; individual room assignment unknown, no arbitrary room choice or duplicate appointments','exact current clock/room unavailable','remote recorded course: dated lecture operation unverified']]
    if specific:reasons.append('previousSpecificNativeOperationSourceConditionRetained')
   else:
    native=c['sourceEducation']['allPublicQueryEducation'];typ=[r.get('강좌유형정보','') for r in native];parsed=ssuparse(c['sourceSchedule'],c['professor']) or []
    if any('녹화' in x for x in typ):reasons.append('ownExplicitRecordedOrPhysicalRecordedSourceType')
    if not parsed:reasons.append('nativeClockRoomTeacherSuffixOrOverlappingParallelAllocationUnresolved')
    sourceNotes=' '.join(r.get('수강유의사항','')+' '+r.get('수강대상','') for r in native)
    if re.search(r'집중\s*(?:이수|수업|강의)|격주|원격\s*(?:수업|강의)|온라인\s*(?:수업|강의)|녹화|별도\s*(?:시간|배정)|자율\s*(?:학습|수업)',sourceNotes):reasons.append('ownExplicitIndividualSpecialOperatingCondition')
    plan=ssuplans.get(c['sourceEducation']['nativeTenDigitCourseId'])
    if plan and re.search(r'고사|시험|자율학습|동영상\s*(?:강의|학습)|학습\s*영상|녹화|온라인\s*강의|비대면|휴강|보강|격주|집중',plan['weeklyTeachingPlan']):reasons.append('ownExactCurrentPlanExamVideoSelfStudyDateAllocationUnresolved')
   if not reasons:possible.append({'sourceId':c['sourceId'],'school':school,'native':native,'parsed':parsed})
   item={'school':school,'campus':campus,'sourceId':c['sourceId'],'courseCode':c['courseCode'],'section':c['section'],'originalEducationalSource':native,'originalSourceSHA256':hashlib.sha256(json.dumps(native,sort_keys=True,ensure_ascii=False).encode()).hexdigest(),'rawNativeClock':c['sourceSchedule'],'rawNativeRoom':c['sourceClassroom'],'parsedClockGeometryNotProjection':parsed,'sourceParserHeldReasons':sorted(set(reasons)),'researchAttendanceWarningUsedAsSchoolCondition':False,'newAppointments':0,'humanWholeOriginalReadClaim':False,'newNetworkRequest':False}
   if plan:item['currentPlanEducationCondition']={'nativeCourseId':plan['nativeCourseId'],'academicYear':plan['academicYear'],'semester':plan['semester'],'numericSection':plan['numericSection'],'weeklyTeachingPlan':plan['weeklyTeachingPlan']}
   queue.append(item);schoolcounts['heldProcessed']+=1;reasoncounts.update(set(reasons))
 schoolcounts['heldReasonCountsOverlapping']=dict(reasoncounts);counts[school]=schoolcounts
write('all782-held-native-source-processing-queue.json',queue);write('possible-new-ordinary-scope-not-projected.json',possible);write('processing-progress.json',{'sourceOnly':True,'SDKExecuted':False,'productModified':False,'completionClaim':False,'counts':counts,'processedHeld':len(queue),'positivePendingFurtherProof':len(possible),'newMeetings':0,'humanWholeReadAdded':0,'networkRequests':0,'timestamp':datetime.datetime.now().astimezone().isoformat()})
for n in ['law-update-educational-notices.json','law-native-update-links.json','special-operation-registration-numbers.json']:shutil.copyfile(DU/n,out/f'daegu-{n}')
shutil.copyfile(__file__,out/pathlib.Path(__file__).name);print(json.dumps({'counts':counts,'positivePending':[(r['school'],r['sourceId']) for r in possible]},ensure_ascii=False))
