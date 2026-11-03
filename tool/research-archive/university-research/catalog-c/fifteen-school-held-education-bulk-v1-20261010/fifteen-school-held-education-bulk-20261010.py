import pathlib,json,re,copy,hashlib,collections,datetime,shutil
b=pathlib.Path(__file__).parent;repo=b.parents[2];o=b/'fifteen-school-held-education-bulk-v1-20261010';o.mkdir(exist_ok=False)
schools=['mmu','kmu','knue','kyonggi','kookmin','nsu','gist','kau','gknu','bnue','tuk','konkuk','jbnu','gnue','cje'];q=[];positive=[];counts={};allassets=[]
def load(p):return json.load(open(p))
def write(n,d):(o/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
nsu=repo/'work/university-research/catalog-e/nsu-two-images-semester-v2-20261009';clocks={r['period']:(r['startMinutes'],r['endMinutes']) for r in load(nsu/'nsu-clock-evidence.json')['periods']};holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
for school in schools:
 count={'whole':0,'priorScheduled':0,'priorMeetings':0,'heldProcessed':0,'newScopes':0,'newMeetings':0};reasonsCount=collections.Counter()
 for p in sorted((repo/'assets/timetable').glob(school+'-*-2026-2.json')):
  key=p.name[:-5];d=load(p);candidate=copy.deepcopy(d);shutil.copyfile(p,o/('baseline-'+p.name));allassets.append(key);count['whole']+=len(d['courses']);count['priorScheduled']+=sum(bool(c['schedules']) for c in d['courses']);count['priorMeetings']+=sum(len(c['schedules']) for c in d['courses'])
  for c in candidate['courses']:
   if c['schedules']:continue
   reasons=[];edu={};new=[];origin='';period=None
   if school=='mmu':
    edu=c['sourceEducation'];reasons=['ownExactCurrentAnticipatedClosureRows'] if edu.get('closureCandidates') else ['ownOperatingScopePending']
   elif school=='kmu':
    edu={'nativeClock':c['sourceSchedule'],'nativeRoom':c['sourceClassroom'],'nativeDepartmentNotes':c['departmentRemarks']}
    if '원격수업' in c['sourceSchedule']:reasons=['ownRemoteWithoutFixedContactHH']
    elif not c['sourceSchedule']:reasons=['nativeWeeklyHHUnpublished']
    else:reasons=['ownFieldworkOrSpecialCourseOperatingDatesUnassigned']
   elif school=='knue':
    edu=c['sourceEducation'];parts=[p for w in edu.get('allPublishedWeeklyEducation',[]) for p in w.get('datedNativePeriodParts',[])];unsupported=sorted({n for p in parts for n in p.get('nativePeriods',[]) if n not in [1,2,3,4,6,7,8]});reasons=['ownPeriodActualHHUnpublished:'+','.join(map(str,unsupported))] if unsupported else ['noCompleteKnownPeriodWeeklyAssignment']
   elif school=='kyonggi':edu=c['metadata'];reasons=[edu.get('decision','ownSourceClockOrOperatingAssignmentUnresolved')]
   elif school=='kookmin':
    edu={'nativeClock':c['sourceSchedule'],'nativeRoom':c['sourceClassroom'],'nativeDepartmentNotes':c['departmentRemarks']};notes=' '.join(c['departmentRemarks'].values())
    if not c['sourceSchedule']:reasons=['nativeWeeklyHHUnpublished']
    elif re.search('혼합수업|블렌디드|BL\+PBL',notes):reasons=['ownRecordedContactPerWeekHHAllocationUnresolved']
    elif re.search('사회봉사|창업.*실습|현장실습',c['courseName']):reasons=['nativeServiceOrPlacementPlaceholderNotActualWeeklyOperation']
    else:reasons=['cachedIndividualPlanHolidayDeliveryAllocationUnresolved']
   elif school=='nsu':
    edu=c.get('publicImageEducation') or c.get('publicEducationCells') or {'sourceClock':c['sourceSchedule'],'heldSourceCondition':c.get('scheduleHoldReason')};reason=c.get('scheduleHoldReason','');reasons=[reason]
    if reason=='instructor/room not printed':
     assert c['publicImageEducation']['room']=='' and c['sourceClassroom']=='' and c['professor']=='' and not c['closureExactTitleSectionTeacherMatches'];r=c['publicImageEducation'];assert all(n in clocks for n in r['periods']);day=datetime.date(2026,8,31)
     while day<=datetime.date(2026,12,19):
      if day.isoweekday()==r['weekday'] and day.isoformat() not in holidays:
       for n in r['periods']:new.append({'date':day.isoformat(),'weekday':r['weekday'],'startMinute':clocks[n][0],'endMinute':clocks[n][1],'classroom':'','sourcePeriod':n,'sourceGrade':r['grade'],'sourceBand':r['imageBand'],'sourceProfessor':''})
      day+=datetime.timedelta(days=1)
     period={'startDate':'2026-08-31','endDate':'2026-12-19'};reasons=[];origin='current public image fixed weekday+period; own printed period HH and calendar16week operation; instructor/room blank retained; not printed individual actual dates'
   elif school=='gist':edu=c['sourceMetadata'];reasons=edu.get('operatingGaps',[]) or ['sourceWeeklyOperationUnassigned']
   elif school=='kau':
    edu=c['sourceEducation'];reasons=['currentSameNativeClockConflict'] if edu.get('laterSourceUrl') else ['ownAnticipatedClosureFinalStatusUnconfirmed'] if edu.get('sourceKind')=='anticipatedClosure' or 'closure' in str(edu.get('sourceKind','')).lower() else ['nativeFixedHHUnpublished']
    if '(cid:113)' in c.get('sourceSchedule',''):reasons=['ownCurrentAnticipatedClosureFinalStatusUnconfirmedAndGlyphLiteralPreserved']
   elif school=='gknu':edu=c['metadata'];reasons=['ownNightPeriodActualEndHHUnpublished']
   elif school=='bnue':
    edu=c['sourceEducation'];r=edu['nativePublicBlock'];assert r['professorUnassignedNativeLabel'];assert r['courseName']==c['courseName'] and r['classroom']==c['sourceClassroom'] and c['professor']==r['professor'];assert r['startMinute']==(8+r['firstPeriod'])*60 and r['endMinute']==(8+r['lastPeriod'])*60+50
    day=datetime.date(2026,9,1)
    while day<=datetime.date(2026,12,7):
     blocked=day.isoformat() in holidays or day.isoformat()=='2026-09-02' or (r['grade']==2 and datetime.date(2026,10,12)<=day<=datetime.date(2026,10,23)) or (r['grade']==3 and datetime.date(2026,11,2)<=day<=datetime.date(2026,11,13))
     if day.isoweekday()==r['weekday'] and not blocked:new.append({'date':day.isoformat(),'weekday':r['weekday'],'startMinute':r['startMinute'],'endMinute':r['endMinute'],'classroom':r['classroom']})
     day+=datetime.timedelta(days=1)
    period={'startDate':'2026-09-01','endDate':'2026-12-07'};origin='current public native single-title cell fixed weekday+HH+room; own exactcalendar and grade placement exclusions; unassigned instructor label preserved, not confirmed individual instructor'
   elif school=='tuk':
    edu={'sourceEducation':c['sourceEducation'],'sourceSnapshotSchedules':c.get('sourceSnapshotSchedules'),'sourceDepartmentRemarks':c.get('sourceDepartmentRemarks'),'individualBlockingReasons':c.get('individualBlockingReasons')};reasons=c.get('individualBlockingReasons',[])[:]
    if not reasons:reasons=['sourceOnlineModeContactUnassigned'] if '온라인' in c['sourceSchedule'] else ['nativeWeeklyHHUnpublished']
   elif school=='konkuk':edu=c['rawCurrentEducation'];reasons=['ownHybridRecordedContactAllocationUnpublished'] if re.search('Hybrid|Recorded',edu['nativeMethod']) else ['ownNativeTimeslot21HHOrCompleteAssignmentUnpublished']
   elif school=='jbnu':edu={'publishedDocumentMetadata':c['publishedDocumentMetadata'],'publicDatedCells':c['publicDatedCells']};reasons=c['holds']
   elif school=='gnue':edu=c['sourceEducation'];reasons=['ownAFStudentGroupOrHalfSemesterDateMappingUnconfirmed']
   else:edu={'publicEducationCells':c['publicEducationCells'],'publicTeacherRoomAllocation':c.get('publicTeacherRoomAllocation')};reasons=['ownNativePeriodsActualStartEndHHUnpublished']
   if new:
    note='정규 시간·요일과 학교 자체학기가 명시된 원문 예정 수업입니다. 교수 미배정/교실 미공개는 원문 그대로이며 확정 교수·교실·실제 출석으로 주장하지 않습니다. 기존 보류 문구는 과거 검토 기록으로 보존합니다. '
    c['schedules']=new;c['period']=period;c['scheduleStatus']='scheduled';c['remarks']=note+c.get('remarks','');c['departmentRemarks']={k:note+v for k,v in c.get('departmentRemarks',{}).items()};c['sourceScheduleResolution']={'sourceOnly':True,'basis':origin,'unknownProfessorOrRoomNotFabricated':True,'actualAttendanceConfirmed':False,'individualLatestClosureConfirmed':False,'userDefaultModeRetained':True}
    positive.append({'asset':key,'sourceId':c['sourceId'],'educationSource':edu,'sourceDateBasis':origin,'independentExpectedMeetings':new,'newMeetings':len(new),'period':period});count['newScopes']+=1;count['newMeetings']+=len(new)
   q.append({'asset':key,'school':school,'sourceId':c['sourceId'],'nativeOriginalEducation':edu,'nativeEducationSHA256':hashlib.sha256(json.dumps(edu,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),'originalNativeClock':c.get('sourceSchedule',''),'originalNativeRoom':c.get('sourceClassroom',''),'actualSourceConstraints':reasons,'researchAttendanceWarningUsedAsSchoolCondition':False,'sourceOnlyNewMeetings':len(new),'humanWholeReadAdded':False});count['heldProcessed']+=1;reasonsCount.update(reasons)
  write(key+'.source-candidate.json',candidate)
 count['heldRemaining']=count['heldProcessed']-count['newScopes'];count['sourceReasonCountsOverlapping']=dict(reasonsCount);counts[school]=count
write('all-held-education-processing-queue.json',q);write('new-ordinary-native-scopes-independent-plan.json',positive);write('processing-progress.json',{'schools':schools,'allAssets':allassets,'counts':counts,'heldProcessed':len(q),'newScopes':len(positive),'newMeetings':sum(p['newMeetings'] for p in positive),'networkRequests':0,'SDKExecuted':False,'productModified':False,'AGENT_MEMORYModified':False,'humanWholeOriginalReadAdded':0,'completionClaim':False,'timestamp':datetime.datetime.now().astimezone().isoformat()});shutil.copyfile(__file__,o/pathlib.Path(__file__).name)
for p in [nsu/'nsu-clock-evidence.json',nsu/'literal-semester-source-proof.json',nsu/'own-guide-clock-calendar-education.json',repo/'work/university-research/catalog-f/bnue/bnue-current-calendar-education-receipt-20261008.json',repo/'work/university-research/catalog-f/bnue/bnue-current-native305-source-20261008.json']:shutil.copyfile(p,o/p.name)
print(json.dumps({'heldProcessed':len(q),'newScopes':len(positive),'newMeetings':sum(p['newMeetings'] for p in positive),'positiveSchools':collections.Counter(p['asset'].split('-')[0] for p in positive)},ensure_ascii=False))
