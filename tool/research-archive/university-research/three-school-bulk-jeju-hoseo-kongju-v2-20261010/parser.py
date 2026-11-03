import json,pathlib,copy,re,datetime as dt,hashlib,collections
R=pathlib.Path('work/university-research');P=R/'three-school-bulk-jeju-hoseo-kongju-v2-20261010';assert not P.exists();P.mkdir()
clockH=json.load(open(R/'catalog-r/hoseo/full-term-ordinary-v3-20261008/educational-proof.json'))['currentClockEvidence'];Hclock={int(r['nativePeriod']):[int(r['start'][:2])*60+int(r['start'][3:]),int(r['end'][:2])*60+int(r['end'][3:])]for r in clockH['validatedDayPeriods']};assert sorted(Hclock)==list(range(1,9))
sourcePaths=[R/'catalog-r/jeju/jeju-current-source-proof-v1.json',R/'catalog-r/hoseo/full-term-ordinary-v3-20261008/educational-proof.json',R/'catalog-r/kongju/current-whole-lecture-list-followup-20261008/current-whole-undergraduate-lecture-education.json'];sourceSha={str(f):hashlib.sha256(f.read_bytes()).hexdigest()for f in sourcePaths}
proof=[];queue=[];archive={};datasets=[];summary={};totalAdded=0
for school in ['jeju','hoseo','kongju']:
 stats={'whole':0,'processedHeld':0,'baselineScheduled':0,'baselineMeetings':0,'newScheduled':0,'newMeetings':0,'queue':0};reasonCounts=collections.Counter()
 for path in sorted(pathlib.Path('assets/timetable').glob(school+'-*.json')):
  old=json.load(open(path));new=copy.deepcopy(old);sourceSha[str(path)]=hashlib.sha256(path.read_bytes()).hexdigest();stats['whole']+=len(old['courses']);stats['baselineScheduled']+=sum(bool(c['schedules'])for c in old['courses']);stats['baselineMeetings']+=sum(len(c['schedules'])for c in old['courses'])
  for c in new['courses']:
   if c['schedules']:continue
   stats['processedHeld']+=1;reasons=[];slots=[];sourceLiteral=None;oldReason='';ownClock={};before=copy.deepcopy(c)
   if school=='jeju':
    md=c['metadata'];r=md['originalEducationalFields'];oldReason=md['heldReason'];sourceLiteral=r
    if c['sourceId'].endswith('/603207'):
     assert r['department']=='수의과대학 수의예과' and r['grade']==2 and r['rawTimeAndRoom']=='화6[수의107] 화7[수의107] 수8[] 수9[]'and not r['rawOperatingMethod']and r['operatingReview']=='ordinary-clock-current-operation-review'
     ownClock={str(i):[(8+i)*60,(8+i)*60+50]for i in range(1,10)}
     for m in re.finditer(r'([월화수목금])([1-9])\[([^]]*)\]',r['rawTimeAndRoom']):
      a,b=ownClock[m[2]];slots.append({'weekday':'월화수목금'.index(m[1])+1,'startMinute':a,'endMinute':b,'classroom':m[3]})
     assert len(slots)==4
    else:reasons=[oldReason];
    start,end=dt.date(2026,9,1),dt.date(2026,12,7);closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};exams=(dt.date(2026,10,20),dt.date(2026,10,26))
   elif school=='hoseo':
    md=c['metadata'];sourceLiteral=md['originalEducationalRecords'];olds=md['reservationHoldReasons'];oldReason=md['heldReason']
    if olds!=['room unavailable or multiple room block correspondence unknown']:reasons=olds or['other_native_operation_pending']
    elif md['campusAllocationRoomConflict']:reasons=['actual_room_vs_published_campus_conflict']
    else:
     records=md['originalEducationalRecords'];sig={(str(r['values'][9]),str(r['values'][10]),str(r['values'][11]),str(r['values'][4]),str(r['values'][8]),str(r['values'][12]))for r in records};assert len(sig)==1
     v=records[0]['values'];assert v[4]=='대면수업'and str(v[8]).startswith('주간');assert v[10]and v[11];raw=str(v[9]);ms=list(re.finditer(r'([월화수목금])([1-8])(?:~([1-8]))?',raw));assert ','.join(m[0]for m in ms).replace(' ','')==raw.replace(' ','')
     if re.search(r'집중|[0-9]+\s*주차|[0-9]+\s*주\s*(?:운영|수업)|실습배치|병원실습|외부실습',str(v[12]or'')):reasons=['actual_native_individual_operating_allocation_pending']
     else:
      ownClock=Hclock
      for m in ms:slots.append({'weekday':'월화수목금'.index(m[1])+1,'startMinute':Hclock[int(m[2])][0],'endMinute':Hclock[int(m[3]or m[2])][1],'classroom':''})
      assert len(slots)==2 and not any(a['weekday']==b['weekday']and max(a['startMinute'],b['startMinute'])<min(a['endMinute'],b['endMinute'])for i,a in enumerate(slots)for b in slots[i+1:])
    start,end=dt.date(2026,8,31),dt.date(2026,12,18);closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09','2026-10-23'};exams=None
   else:
    md=c.get('sourceEducationalMetadata');sourceLiteral=md['originalPublishedRowVariants']if md else c.get('metadata',{})
    if md is None:reasons=['existing_contract_approval_or_operating_boundary_preserved']
    elif md['holdReasons']!=['actualRoomUnpublished']:reasons=md['holdReasons'];oldReason=', '.join(reasons)
    else:
     oldReason='actualRoomUnpublished';rs=md['originalPublishedRowVariants'];assert len({tuple(r[k]for k in ['courseTitle','professor','credits','periodRaw','roomRaw'])for r in rs})==1;assert all(not r['roomRaw']for r in rs)
     assert all(not re.search(r'원격|온라인|이러닝|비대면|OCU|동영상|사이버|블록|집중|현장실습|교육봉사|현장교육실습|병원실습|임상실습|산업체승인|사업주',r['remarks']+' '+r['periodRaw'])for r in rs)
     ownClock={str(i):[(8+i)*60,(8+i)*60+50]for i in range(10)}
     for b in md['exactSourcePeriodicBlocks']:
      ps=b['nativePeriods'];assert all(0<=p<=9 for p in ps);assert b['startMinute']==ownClock[str(ps[0])][0]and b['endMinute']==ownClock[str(ps[-1])][1];slots.append({k:b[k]for k in ['weekday','startMinute','endMinute']}|{'classroom':''})
     assert slots
    start,end=dt.date(2026,9,1),dt.date(2026,12,7);closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};exams=(dt.date(2026,10,20),dt.date(2026,10,26))
   if reasons:
    stats['queue']+=1;reasonCounts.update(reasons);queue.append({'school':school,'sourceId':c['sourceId'],'reason':reasons,'originalWholeObject':before,'wholeActualSource':sourceLiteral});continue
   assert slots;meetings=[];d=start
   while d<=end:
    if d.isoformat()not in closed and not(exams and exams[0]<=d<=exams[1]):meetings.extend({'date':d.isoformat(),**s}for s in slots if s['weekday']==d.isoweekday())
    d+=dt.timedelta(days=1)
   assert meetings;stats['newScheduled']+=1;stats['newMeetings']+=len(meetings);archive[c['sourceId']]=before.get('remarks','')
   c['schedules']=meetings;c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
   note='학교 자체 현재 정규 개설 교시·기간이 일치한 공개 예약입니다. 원문에 남은 강의실과 교육 조건은 모두 보존하며, 방 미게시 또는 복수 방의 요일별 배정 미확정 그룹은 빈 강의실로 유지합니다. 방 하나를 선택하거나 다른 요일에서 빌리지 않습니다. 실제 출석·전체 최신 폐강 확인 완료 주장은 아니며 사용자 수업 방식은 유지합니다.'
   if school=='jeju':
    c['remarks']=c['remarks'].replace(' 예약 보류: '+oldReason,'')+'\n'+note;md['previousGeneratedHeldReason']=oldReason;md['heldReason']='';md['publishedRegularNativeReservationConfirmed']=True
   elif school=='hoseo':
    c['remarks']=c['remarks'].replace(' 예약보류: '+oldReason,'')+'\n'+note;md['previousGeneratedRoomHoldReasons']=copy.deepcopy(md['reservationHoldReasons']);md['reservationHoldReasons']=[];md['heldReason']='';md['roomWeekdayAllocationConfirmed']=False;md['originalMultipleRoomColumnsPreserved']=True
   else:
    c['remarks']=c['remarks'].replace(' 보류: '+oldReason,'')+'\n'+note;md['previousGeneratedHoldReasons']=copy.deepcopy(md['holdReasons']);md['holdReasons']=[];md['roomUnpublishedKeptBlank']=True
   proof.append({'school':school,'sourceId':c['sourceId'],'previousWholeObject':before,'wholeActualSource':sourceLiteral,'ownClockLiteral':ownClock,'literalFixedSlots':slots,'ownStartLiteral':start.isoformat(),'ownEndLiteral':end.isoformat(),'ownExcludedDateLiterals':sorted(closed),'ownExamRangeLiteral':[x.isoformat()for x in exams]if exams else[],'expectedMeetings':meetings,'actualAttendanceConfirmed':False,'campusOriginalPreserved':c['campus']})
  ids={p['sourceId']for p in proof};oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']]for c in new['courses']if c['sourceId']not in ids)
  (P/(path.stem+'.prior-whole.json')).write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');(P/(path.stem+'.bulk-candidate.json')).write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n');datasets.append({'school':school,'prior':path.stem+'.prior-whole.json','candidate':path.stem+'.bulk-candidate.json'})
 assert stats['queue']+stats['newScheduled']==stats['processedHeld'];stats['candidateScheduled']=stats['baselineScheduled']+stats['newScheduled'];stats['candidateMeetings']=stats['baselineMeetings']+stats['newMeetings'];stats['queueReasonCounts']=dict(reasonCounts);summary[school]=stats
for name,v in [('proof.json',{'sourceOnly':True,'SDKExecutions':0,'productWrites':0,'completionClaim':False,'summary':summary,'datasets':datasets,'proofs':proof,'sourceSHA256':sourceSha}),('queue.json',queue),('previous-full-remarks-archive.json',archive),('summary.json',summary)]: (P/name).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
(P/'parser.py').write_text(pathlib.Path(__file__).read_text());print(summary)
