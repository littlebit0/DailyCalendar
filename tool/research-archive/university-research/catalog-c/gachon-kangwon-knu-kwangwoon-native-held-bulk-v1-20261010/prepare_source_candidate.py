# coding: utf-8
import json, pathlib, copy, hashlib, datetime as dt, collections, re
R=pathlib.Path.cwd(); W=R/'work/university-research'; O=W/'catalog-c/gachon-kangwon-knu-kwangwoon-native-held-bulk-v1-20261010'
O.mkdir(exist_ok=True)
def read(p):return json.loads(pathlib.Path(p).read_text())
def save(n,v):(O/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
inputs={}
def source(p):
 p=W/p;inputs[str(p.relative_to(R))]=sha(p);return read(p)
grows=source('catalog-g/conditional-operating-followup-v4-20261009/held-571-source-census.json')['rows'];gb=source('catalog-g/gachon-full-normalized-source-candidates.json')['courses'];gr=source('catalog-g/gachon-full-operating-report-audit.json')['reports'];source('catalog-g/gachon-current-scope-clock-term-manifest.json');source('catalog-g/gachon-current-undergraduate-holiday-rule-20261008.json');source('catalog-g/gachon-current-fall-calendar-boundary-proof-20261008.json')
gby={x['sourceId']:x for x in grows};gbby={(x['campusSourceCode'],x['officialOfferingCode']):x for x in gb};grby={(x['campus'],x['sourceRow']['HAKSU_NO']):x for x in gr}
kr=source('catalog-q/kangwon-current-whole-source-rows.json');ka=source('catalog-q/kangwon-normalized-candidate-audit.json');kby={(x['campus'],x['code'],x['section']):x for x in kr};kab={(x['campus'],x['code'],x['section']):x['reasons'] for x in ka['individualUnresolved']}
kncalendar=source('catalog-p/knu-current-2026-calendar-items.json');kn=source('catalog-p/knu-2026-2-expanded-public-owner-course-rows.json');knby={x['crseNo']:x for x in kn};knreceipts=source('catalog-p/knu-unassigned-ordinary-audit-20261008/all184-held-independent-educational-receipts.json');knrb={x['identity']:x for x in knreceipts};remote=source('catalog-p/knu-current-public-special-scopes/05-remote.json');national=source('catalog-p/knu-current-public-special-scopes/08-national-remote.json');remoteids={x['crseNo'] for x in remote+national}
kw=source('catalog-g/kw-all-2026-2.json')['records'];kwby={x['6:학정번호']:x for x in kw};kwreviews=source('catalog-g/kw-current-operating-review-20261008.json')['records'];kwrb={x['sourceId']:x for x in kwreviews};sports=source('catalog-g/kw-empty-room-sports-operating-review-20261008.json')['rows'];sportids={x['sourceAcademicNumber'] for x in sports};source('catalog-g/kw-continuous-additions-audit-20261008.json');source('catalog-g/kw-current-holiday-rule-20261008.json');source('catalog-g/kw-cancellation-crosscheck.json')
HOL={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};DAYS='월화수목금토일';DAY_TWO={'1,2':(540,650),'3,4':(720,830),'5,6':(900,1010)}
# These rows have exact current header/professor plus date-printed weekly rows;
# only the separately printed row ranges are reserved, never generic15-week extension.
GSAFE={'08386010','08386014','15314003','16024001','12894001','12894002','13642001','13642002','14717001','15522001'}
# 15735016 remains queued: retained topic signal alone insufficient full original context.
proofs=[];queue=[];datasets=[];census=collections.defaultdict(collections.Counter)
for school in ['gachon','kangwon','knu','kwangwoon']:
 for p in sorted((R/'assets/timetable').glob(school+'-*.json')):
  before=read(p);after=copy.deepcopy(before);inputs[str(p.relative_to(R))]=sha(p);save('prior-'+p.name,before)
  oldSched=sum(bool(c['schedules']) for c in before['courses']);oldMeet=sum(len(c['schedules']) for c in before['courses'])
  for old,c in zip(before['courses'],after['courses']):
   if c['schedules']:continue
   reason='';raw=None;blocks=[];ranges=[];omit=[];basis='';extras={}
   if school=='gachon':
    x=gby.get(c['sourceId']);raw=x
    reason=x['decision'] if x else 'untimedOutsidePrior571Census'
    offering=c['courseCode']+c['section'];camp='20' if c['campus']=='global' else '21';base=gbby[(camp,offering)]
    if offering in GSAFE:
     assert x['decision']=='heldPrintedPeriodCorrespondenceUnproved';report=grby[(camp,offering)]
     assert all(report['report'][k] for k in ['headerCourseCodeMatches','currentTermMatches','catalogProfessorAppearsInReport'])
     assert not report['potentialDifferentTermStatement'];assert report['sourceRow']['CYBER_YN'] is None
     assert report['sourceRow']['PROFNM']==c['professor'];assert report['sourceRow']['TIME']==base['rawSchedule'];assert (report['sourceRow']['LOC_NM']or'')==c['sourceClassroom']
     assert len(report['weeklyRows'])==14 and all(w['activityPresent'] and not w['operatingContextTruncationDetected'] and not w['operatingContextLimitReached'] for w in report['weeklyRows'])
     # Academic drawing/self-portrait is not live videoconference allocation.
     assert all(set(w['signals'])<= {'중간고사','기말고사','시험','화상'} for w in report['weeklyRows'])
     if any('화상'in w['signals'] for w in report['weeklyRows']):assert any('동물자화상'in z for w in report['weeklyRows'] for z in w['operatingContexts'])
     for w in report['weeklyRows']:
      a=dt.date(2026,*map(int,w['startMonthDay'].split('/')));z=dt.date(2026,*map(int,w['endMonthDay'].split('/')));assert(z-a).days==6
      if set(w['signals'])&{'중간고사','기말고사','시험'}:omit.append({'startDate':str(a),'endDate':str(z),'sourceWeek':w['week'],'reason':'printedAssessmentScopeWithheld'})
      else:ranges.append((a,z))
     blocks=[{k:v for k,v in b.items() if k not in ['firstPeriod','lastPeriod']} for b in base['schedules']];assert blocks
     basis='currentReportPrintedWeeklyDateUnionOnly; old15WeekEndMismatchDoesNotInvalidateExplicitRows'
     extras={'sourceWeeklyRows':report['weeklyRows'],'sourceTeachingMethod':report['teachingMethodEducationalExcerpt'],'sourceIdentity':report['report'],'rawEducationalRow':report['sourceRow'],'publishedActualSlots':base['publishedActualSlots'],'omittedAssessmentRanges':omit}
   elif school=='kangwon':
    key=(c['campus'],c['courseCode'],c['section']);raw=kby[key];reason=';'.join(kab[key]);assert not raw['closed']
    if key==('wonju','71500008','01'):extras['unpublishedClock']='own75-minute chart A1–A6 only; literalA7,A8 lacks ABS start/end; no extrapolation'
   elif school=='knu':
    identity=c['courseCode']+'-'+c['section'];raw=knby[identity]
    assert raw['estblYear']=='2026' and raw['estblSmstrSctcd']=='CMBS001400002';assert (raw['totalPrfssNm']or'')==c['professor'];assert (raw['lssnsRealTimeInfo']or'')==c['sourceSchedule']
    # Preserve only educational fields from the source response, not capacity/application cells.
    raw={k:raw.get(k) for k in ['crseNo','estblYear','estblSmstrSctcd','sbjetCd','sbjetDvnno','sbjetNm','totalPrfssNm','crdit','sbjetSctnm','estblDprtnNm','estblGrade','lssnsRealTimeInfo','lssnsTimeInfo','lctrmInfo','rmnmCd','rmrk','thryTime','prctsTime']}
    if not c['sourceSchedule']:reason='nativeAbsoluteClockUnpublished'
    elif identity in remoteids:reason='actualRemoteScopeDeliveryDateAndLiveVsRecordedAllocationUnpublished'
    elif identity in knrb:reason='actualIndividualIntensiveOrFieldAllocationUnpublished';extras['sourcePlanEducationalFields']=knrb[identity].get('sourcePlanEducationalFields')
    else:reason='currentTimedOfferingRequiresOwnOperatingSource';
    wp=W/'catalog-p/knu-current-public-weekly-plans'/f'{identity}.json'
    if wp.exists():
     inputs[str(wp.relative_to(R))]=sha(wp);weekly=read(wp)
     assert all(y['estblYear']=='2026'and y['estblSmstrSctcd']=='CMBS001400002' and y['sbjetCd']==c['courseCode']and y['sbjetDvnno']==c['section'] for y in weekly)
     extras['wholeCurrentEducationalWeeklyPlan']=weekly
    op=W/'catalog-p/knu-current-public-plans'/f'{identity}.json'
    if op.exists():
     inputs[str(op.relative_to(R))]=sha(op);overview=read(op);assert overview['estblYear']=='2026'and overview['estblSmstrSctcd']=='CMBS001400002' and overview['crseNo']==identity
     educ={k:overview.get(k)for k in ['crseNo','estblYear','estblSmstrSctcd','sbjetNm','totalPrfssNm','lssnsTimeInfo','lctrmInfo','attlcRefMtterCntns','lssnsMethdMediaCntns','lctrePrdInfo','smmryPrpsCntns','lctreGoalCntns']};extras['sourcePlanEducationalFields']=educ
     if reason=='currentTimedOfferingRequiresOwnOperatingSource':
      t=str(educ.get('attlcRefMtterCntns')or'')+' '+str(educ.get('lctreGoalCntns')or'')
      reason='actualPublishedMixedRecordedFieldOrIntensiveAllocation'if re.search(r'집중|동영상|field work|답사',t)else'currentPracticalOperationNotIndividuallyResolved'
     if identity in ['DOLS0610-001','CLTR0058-001','CLTR0058-002']:
      refs=overview['attlcRefMtterCntns'];assert '중간고사' in refs
      assert '10.21.~10.27.' in str(kncalendar)
      day=5 if identity=='DOLS0610-001'else(3 if identity=='CLTR0058-001'else 1)
      if day==5:assert '중간고사 전 까지 학교에서 실시' in refs
      if day==3:assert '수요일 수업은 1, 2차시에 해당하며 대면 강의' in refs
      if day==1:assert '월요일(1, 2차시) 수업은 대면 강의' in refs
      parts=re.findall(r'([월화수목금토일]) (\d{2}):(\d{2}) ~ (\d{2}):(\d{2})',c['sourceSchedule']);assert parts
      actual=[x for x in parts if DAYS.index(x[0])+1==day];assert actual
      blocks=[{'weekday':day,'startMinute':int(x[1])*60+int(x[2]),'endMinute':int(x[3])*60+int(x[4]),'classroom':c['sourceClassroom']}for x in actual]
      ranges=[(dt.date(2026,9,1),dt.date(2026,10,20))]
      if identity=='CLTR0058-001':
       assert '3주차 수업은 모두 동영상' in refs
       # Literal current weekly row prints9/16,19; no week-index calendar inference.
       third=next(x for x in weekly if x['weekSn']=='3');assert '9/16, 19' in third['lssnsGoalLrnngCntns']
       ranges=[(dt.date(2026,9,1),dt.date(2026,9,15)),(dt.date(2026,9,20),dt.date(2026,10,20))]
      basis='explicitOwnCurrentBeforeMidtermCampusComponentOnly; schoolMidtermStartsOct21; recordedSaturdayAndLaterFieldConcentrationWithheld'
      extras['sourceMidtermBoundary']='2026-10-21';extras['allLaterOrRecordedComponentsWithheld']=True
      # Mode is named only for these two exactweekday classroom components.
      if identity.startswith('CLTR'):blocks=[dict(x,deliveryMode='inPerson')for x in blocks]
   else:
    identity=c['sourceAcademicNumber'];raw=kwby[identity];review=kwrb[identity];reason=review['operatingGroup']+'/'+review['clockReviewProfile']
    if identity in sportids:
     assert raw['20:시간']==2 and all(raw[k] is None for k in ['9:원격100%','10:원격50%이상','11:사전녹화100%','13:집중이수제'])
     assert raw['33:비고(1학년은 "신입생 및 1학년 분반" 정보 참고하여 수강)'] is None
     ix=[i for i in [24,27,30]if raw[f'{i+1}:None']is not None];assert len(ix)==1;i=ix[0];periods=str(raw[f'{i+1}:None']);assert periods in DAY_TWO
     day=raw[f'{i}:요일{(i-24)//3+1}'];start,end=DAY_TWO[periods];assert not raw[f'{i+2}:None']
     blocks=[{'weekday':DAYS.index(day)+1,'startMinute':start,'endMinute':end,'classroom':''}];ranges=[(dt.date(2026,9,1),dt.date(2026,12,14))]
     basis='currentNativeOrdinaryTwoHourContinuousChartExactMatch; emptyRoomAndSportTitleAloneDoNotCancelPublishedReservation'
     extras={'nativeEducationalRow':{k:v for k,v in raw.items()if k not in ['0:None','22:수강\n인원','23:수강여석']},'sourceClockChartPdfPage':6,'sourcePeriods':periods,'sourceHours':2,'sportsActualIndividualOperatingConfirmed':False,'roomUnpublished':True}
   if blocks:
    expected=[]
    for a,z in ranges:
     for b in blocks:
      day=a+dt.timedelta(days=(b['weekday']-a.isoweekday())%7)
      while day<=z:
       if str(day)not in HOL:expected.append(dict(b,date=str(day)))
       day+=dt.timedelta(days=7)
    expected.sort(key=lambda y:(y['date'],y['weekday'],y['startMinute'],y['endMinute'],y['classroom']))
    assert expected and len({json.dumps(m,sort_keys=True)for m in expected})==len(expected)
    period={'startDate':str(min(a for a,z in ranges)),'endDate':str(max(z for a,z in ranges))}
    evidence={'basis':basis,'priorResearchPeriod':old.get('period'),'priorResearchDepartmentRemarks':old.get('departmentRemarks'),'priorUnresolvedReasons':old.get('unresolvedReasons'),'sourceExplicitDateRanges':[{'startDate':str(a),'endDate':str(z)}for a,z in ranges],'scope': 'publishedPlannedReservationsOnly','actualAttendanceConfirmed':False,'newWholeAcquisition':False,'sourceSnapshotDate':'2026-10-08','remainingMissingWeeklyRangesNotExtended':True}
    # Native school eligibility/conditions preserved; remove only exact prior research warning.
    oldnotes=old.get('departmentRemarks',{});note='공개 원문 요일·자체 시각과 명시된 기간에 한정한 계획 예약입니다. 실제 출석·개별 시험·현장 일정·최신 변경은 확인되지 않았습니다. 강의실 미게시값은 빈값이며 원문 복수실은 모두 함께 보존합니다.'
    if school=='gachon':note+=' 원문 날짜가 인쇄된 주의 정규 범위만 예약하며 누락 주와 시험표시 주는 보류합니다. 자료·자화상 등의 학습 주제를 원격 운영으로 해석하지 않습니다.'
    elif school=='knu':note+=' 학교 원문에서 명시한 중간시험 이전 교내 수업 성분만 예약합니다. 토요일 녹화 및 중간시험 이후 현장·집중 구간은 예약하지 않습니다.'
    else:note+=' 종목명만으로 집중 운영을 가정하지 않습니다. 개별 실사용 장소와 실제 스포츠 운영은 미확인입니다.'
    warning='수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
    c.update(schedules=expected,scheduleStatus='scheduled',period=period,nativeBulkReservationEvidence=evidence,departmentRemarks={k:'\n'.join(line for line in v.split('\n')if line!=warning)+'\n'+note for k,v in oldnotes.items()})
    proofs.append({'sourceId':c['sourceId'],'school':school,'campus':c['campus'],'reason':basis,'originalWholeCourse':old,'sourceClockBlocks':blocks,'period':period,'calendarExcludedDates':sorted(HOL),'sourceDateRanges':evidence['sourceExplicitDateRanges'],'literalMeetingsIndependentExpected':expected,**extras});census[school]['added']+=1;census[school]['addedMeetings']+=len(expected)
   else:
    queue.append({'sourceId':c['sourceId'],'school':school,'campus':c['campus'],'reason':reason,'originalWholeCourse':old,'nativeEducationalSource':({k:v for k,v in raw.items()if k not in ['0:None','22:수강\n인원','23:수강여석']}if school=='kwangwoon'else raw),**extras});census[school][reason]+=1
  after['researchOnly']=True;after['completionClaim']=False;save(p.name,after)
  specs={'school':school,'candidateFile':p.name,'priorFile':'prior-'+p.name,'native':len(after['courses']),'previousScheduled':oldSched,'previousMeetings':oldMeet,'scheduled':sum(bool(c['schedules'])for c in after['courses']),'meetings':sum(len(c['schedules'])for c in after['courses'])};datasets.append(specs)
  chosen={x['sourceId']for x in proofs}
  for x,y in zip(before['courses'],after['courses']):
   if x['sourceId']not in chosen:assert x==y
   else:
    for k in x:
     if k not in ['schedules','scheduleStatus','period','departmentRemarks']:assert x[k]==y[k]
assert sum(x['native']for x in datasets)==14678
assert len(queue)+len(proofs)==1597
save('independent-native-whole-clock-date-proof.json',{'researchOnly':True,'completionClaim':False,'datasets':datasets,'eligibleProofs':proofs,'sourceInputsSHA256':inputs,'census':{k:dict(v)for k,v in census.items()},'verification':{'pythonWholePreservation':True,'actualThreeModeDrive':False,'sdkUsed':False}})
save('all-four-school-remaining-held-queue.json',{'reviewedHeldCount':1597,'remainingHeldCount':len(queue),'rows':queue,'universitySupportImpossibleClaim':False})
print(json.dumps({'folder':str(O),'datasets':datasets,'added':len(proofs),'addedMeetings':sum(len(x['literalMeetingsIndependentExpected'])for x in proofs),'remaining':len(queue),'census':{k:dict(v)for k,v in census.items()}},ensure_ascii=False))
