import pathlib,json,copy,re,hashlib,datetime as dt,shutil
O=pathlib.Path('work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1');V=O/'bulk-remaining1371-1917-v3-20261010';P=O/'bulk-remaining1371-1917-final-v5-20261010';assert not P.exists();P.mkdir()
for f in V.iterdir():
 if f.is_file():shutil.copy2(f,P/f.name)
xs=json.load(open(O/'whole1917-original-registry.json'));proof=json.load(open(P/'bulk-independent-proof.json'));queue=json.load(open(P/'uncertain-operating-queue.json'));archive=json.load(open(P/'previous-full-remarks-archive.json'))
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)');closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};N=[1,2,3,4,5,6,7,9,10,11,12,13,14]
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.';oldonline='현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.'
livenote='현재 2026-2 개별 원문의 명시 실시간 온라인 운영과 동일 강좌·교수·캠퍼스·주차 및 절대 수업시각이 일치한 정규 수업 전체 그룹만 부분 예약합니다. 평가·보강·기간 및 방식 미확정 그룹은 원문에 보존하고 예약하지 않습니다. 기존 개인 데이터와 원문 강의실은 유지하며 실제 출석 또는 대학 전체 최신 변경 확인 완료를 뜻하지 않습니다.'
newLive={}
for n in [1373,1374]:
 x=xs[n-1];c=x['originalWholeObject'];native=list(slot.finditer(c['sourceSchedule']));ps=[]
 for z in x['plans']:
  p=z['originalWholeEducationPlan'];assert p['header']==['2026학년도 2학기 강의계획서'] and p['campus']=='국제' and p['lectureCode']==c['sourceEducationalVariants'][0]['lecture_cd'];ss={s['section']:s['rows']for s in p['educationalSections']};ch=next(r for r in ss['수업운영방식']if r[0]=='수업운영방식');assert ch[1:]==['','○','','',''];clock=next(r[1]for r in ss['기본정보']if r[0]=='강의시간강의실');cl=re.sub(r'\s+','',clock)
  for m in native:assert re.sub(r'\s+','',p['queriedProfessorName']+' '+m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5]) in cl
  ps.append(p);f=pathlib.Path(z['file']);assert json.load(open(f))==p;proof['rawSHAs'][str(f)]=hashlib.sha256(f.read_bytes()).hexdigest()
 rows={int(r[0][:-1]):r for r in next(s['rows']for s in ps[0]['educationalSections']if s['section']=='주별강의내용')if r and re.fullmatch(r'\d+주',r[0])}
 if n==1374:assert next(s['rows']for s in ps[1]['educationalSections']if s['section']=='주별강의내용')==next(s['rows']for s in ps[0]['educationalSections']if s['section']=='주별강의내용')
 meetings=[]
 for w in N:
  a=dt.date(2026,9,1)+dt.timedelta(days=7*(w-1));b=a+dt.timedelta(days=6);assert rows[w][1]==f'{a.month}/{a.day} ~ {b.month}/{b.day}'
  for m in native:
   wd='월화수목금토일'.index(m[1])+1;d=a+dt.timedelta(days=(wd-a.isoweekday())%7)
   if d.isoformat()not in closed:meetings.append({'date':d.isoformat(),'weekday':wd,'startMinute':int(m[2])*60+int(m[3]),'endMinute':int(m[4])*60+int(m[5]),'classroom':'','deliveryMode':'liveOnline'})
 assert len(meetings)=={1373:25,1374:11}[n];newLive[c['sourceId']]=meetings
 proof['proofs'].append({'ordinal':n,'sourceId':c['sourceId'],'originalWholeObject':c,'wholeEducationPlan':ps[0],'wholeEducationPlans':ps,'sourceFiles':[z['file']for z in x['plans']],'nativeClockLiteral':c['sourceSchedule'],'ownProfessorClockLiteral':clock,'allowedWeeksLiteral':N,'allowedWholeRowsLiteral':[rows[w]for w in N],'expectedWholeMeetings':meetings,'mode':'explicit_liveOnline','actualAttendanceConfirmed':False,'excludedWeeksLiteral':[{'week':w,'wholeRow':rows[w],'reason':'own_project_or_exam_or_makeup'}for w in [8,15,16]]})
 queue=[q for q in queue if q['ordinal']!=n]
for campus in ['seoul','global']:
 path=P/f'khu-{campus}-2026-2.bulk-remaining-prepared.json';a=json.load(open(path))
 for c in a['courses']:
  if c['sourceId']not in newLive:continue
  assert not c['schedules'];archive[c['sourceId']]=copy.deepcopy(c['departmentRemarks']);c['schedules']=newLive[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True;c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace(oldonline,'')+'\n'+livenote for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedLiveOnlineWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside_bulk_remaining_v5'}
 path.write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n')
# Independent reference iterates literal semester days, not candidate schedules or generator week loop.
expected={}
for pr in proof['proofs']:
 slots=list(slot.finditer(pr['nativeClockLiteral']));rows={int(r[0][:-1]):r for r in next(s['rows']for s in pr['wholeEducationPlan']['educationalSections']if s['section']=='주별강의내용')if r and re.fullmatch(r'\d+주',r[0])};vv=[];day=dt.date(2026,9,1)
 while day<=dt.date(2026,12,21):
  w=(day-dt.date(2026,9,1)).days//7+1
  if w in pr['allowedWeeksLiteral'] and day.isoformat()not in closed:
   rr=rows[w];a,b,c,d=map(int,re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',rr[1]).groups());assert dt.date(2026,a,b)<=day<=dt.date(2026,c,d)
   for m in slots:
    wd='월화수목금토일'.index(m[1])+1
    if wd==day.isoweekday():
     t={'date':day.isoformat(),'weekday':wd,'startMinute':int(m[2])*60+int(m[3]),'endMinute':int(m[4])*60+int(m[5]),'classroom':''if pr['mode']=='explicit_liveOnline'else m[6].strip()}
     if pr['mode']=='explicit_liveOnline':t['deliveryMode']='liveOnline'
     vv.append(t)
  day+=dt.timedelta(days=1)
 assert sorted(vv,key=lambda x:(x['date'],x['weekday']))==sorted(pr['expectedWholeMeetings'],key=lambda x:(x['date'],x['weekday']));expected[pr['sourceId']]=vv
proof.update({'newCourses':63,'newMeetings':1076,'candidateCourses':3158,'candidateMeetings':58934,'uncertainQueueCount':484,'physicalNewCourses':61,'physicalNewMeetings':1040,'liveNewCourses':2,'liveNewMeetings':36,'originalDraftParser':'parser.py','finalLiveDerivativeScript':'finalize.py'})
proof['uncertainReasonCounts']=dict(__import__('collections').Counter(r for q in queue for r in q['reason']))
(P/'bulk-independent-proof.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n');(P/'literal-source-independent-expectations.json').write_text(json.dumps(expected,ensure_ascii=False,indent=2)+'\n');(P/'uncertain-operating-queue.json').write_text(json.dumps(queue,ensure_ascii=False,indent=2)+'\n');(P/'previous-full-remarks-archive.json').write_text(json.dumps(archive,ensure_ascii=False,indent=2)+'\n');(P/'resume-ledger.json').write_text(json.dumps({k:v for k,v in proof.items()if k not in ['proofs','rawSHAs']},ensure_ascii=False,indent=2)+'\n');(P/'finalize.py').write_text(pathlib.Path(__file__).read_text())
print({'newCourses':63,'newMeetings':1076,'total':3158,'meetings':58934,'queue':484})
