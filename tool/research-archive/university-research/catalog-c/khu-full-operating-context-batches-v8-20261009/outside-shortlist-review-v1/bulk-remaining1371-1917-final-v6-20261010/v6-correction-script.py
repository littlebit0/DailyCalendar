import pathlib,json,shutil,hashlib,re,datetime as dt
O=pathlib.Path('work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1');V=O/'bulk-remaining1371-1917-final-v5-20261010';P=O/'bulk-remaining1371-1917-final-v6-20261010';assert not P.exists();P.mkdir()
for f in V.iterdir():
 if f.name!='SHA256SUMS.json':shutil.copy2(f,P/f.name)
x=json.load(open(O/'whole1917-original-registry.json'));proof=json.load(open(P/'bulk-independent-proof.json'));exp=json.load(open(P/'literal-source-independent-expectations.json'));q=json.load(open(P/'uncertain-operating-queue.json'));archive=json.load(open(P/'previous-full-remarks-archive.json'));native=re.compile(r'([월화水목금토일])').pattern if False else re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};actual={};receipt=[]
for n in [1380,1387]:
 a=x[n-1];c=a['originalWholeObject'];z=a['plans'][0];p=z['originalWholeEducationPlan'];secs={s['section']:s['rows']for s in p['educationalSections']};rows={int(r[0][:-1]):r for r in secs['주별강의내용']if r and re.fullmatch(r'\d+주',r[0])};assert p['header']==['2026학년도 2학기 강의계획서'] and p['campus']=='국제';assert p['lectureCode']==c['sourceEducationalVariants'][0]['lecture_cd'];assert len(a['plans'])==1
 clock=next(r[1]for r in secs['기본정보']if r[0]=='강의시간강의실');ms=list(native.finditer(c['sourceSchedule']));assert len(ms)==2
 for m in ms:assert re.sub(r'\s+','',p['queriedProfessorName']+' '+m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5]) in re.sub(r'\s+','',clock)
 assert 'Detection' in ' '.join(rows[8]) if n==1380 else 'Mixers' in ' '.join(rows[8])
 meetings=[];day=dt.date(2026,9,1)
 while day<=dt.date(2026,12,14):
  w=(day-dt.date(2026,9,1)).days//7+1;rr=rows[w];aa,bb,cc,dd=map(int,re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',rr[1]).groups());assert dt.date(2026,aa,bb)<=day<=dt.date(2026,cc,dd)
  if day.isoformat()not in closed:
   for m in ms:
    wd='월화수목금토일'.index(m[1])+1
    if day.isoweekday()==wd:meetings.append({'date':day.isoformat(),'weekday':wd,'startMinute':int(m[2])*60+int(m[3]),'endMinute':int(m[4])*60+int(m[5]),'classroom':m[6].strip()})
  day+=dt.timedelta(days=1)
 assert len(meetings)==29;actual[c['sourceId']]=meetings;exp[c['sourceId']]=meetings
 r=next((r for r in proof['proofs']if r['sourceId']==c['sourceId']),None)
 if r is None:
  r={'ordinal':n,'sourceId':c['sourceId'],'originalWholeObject':c,'wholeEducationPlan':p,'sourceFile':z['file'],'sourceSHA256':hashlib.sha256(pathlib.Path(z['file']).read_bytes()).hexdigest(),'nativeClockLiteral':c['sourceSchedule'],'ownProfessorClockLiteral':clock,'ownOperationWholeRows':secs['수업운영방식'],'mode':'physical_user_preference_preserved','actualAttendanceConfirmed':False};proof['proofs'].append(r);proof['rawSHAs'][z['file']]=r['sourceSHA256'];archive[c['sourceId']]=c['departmentRemarks']
 r.update({'allowedWeeksLiteral':list(range(1,16)),'allowedWholeRowsLiteral':[rows[w]for w in range(1,16)],'excludedWeeksLiteral':[{'week':16,'wholeRow':rows[16],'reason':'own_makeup_not_fixed'}],'expectedWholeMeetings':meetings,'ownNormalExamWeekException':['2026-10-20','2026-10-22']if n==1380 else['2026-10-21','2026-10-26'],'sourceOverrideReason':'Prior actual full-plan review confirms own physical default and own week8 normal instructional content. Generic exam-week/online-method parser is more restrictive than own published operating evidence; preserve exact own group.'})
 receipt.append({'ordinal':n,'sourceId':c['sourceId'],'ownWeek8Literal':rows[8],'wholeOperatingRows':secs['수업운영방식'],'wholeProgressRows':[r for r in secs['수업유형 및 방법']if r and r[0]=='수업진행추가설명'],'literalOriginalClock':clock,'priorActualFullPlanReviewPreserved':True,'addedMeetings':2 if n==1380 else 29})
for campus in ['seoul','global']:
 f=P/f'khu-{campus}-2026-2.bulk-remaining-prepared.json';a=json.load(open(f));base=json.load(open(P/f'prior-{campus}-whole.json'));old={c['sourceId']:c for c in base['courses']}
 for c in a['courses']:
  if c['sourceId']not in actual:continue
  c['schedules']=actual[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True;c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'ownNormalExamWeekPublished':True,'sourceSnapshot':'2026-10-08','packet':'outside_bulk_remaining_v6'}
  if c['sourceId'].endswith('/EE32500'):
   other=next(y for y in a['courses']if y['sourceId'].endswith('/EE21103'));note=next(iter(other['departmentRemarks'].values())).split('\n')[-1];warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.';online='현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.';c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace(online,'')+'\n'+note for k,v in old[c['sourceId']]['departmentRemarks'].items()}
 f.write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n')
q=[r for r in q if r['ordinal']!=1387];proof.update({'newCourses':64,'newMeetings':1107,'candidateCourses':3159,'candidateMeetings':58965,'uncertainQueueCount':483,'physicalNewCourses':62,'physicalNewMeetings':1071,'finalDirectSourceCorrection':'own-normal-week8-exception-receipt.json'})
for fn,ob in [('bulk-independent-proof.json',proof),('literal-source-independent-expectations.json',exp),('uncertain-operating-queue.json',q),('previous-full-remarks-archive.json',archive),('own-normal-week8-exception-receipt.json',receipt)]: (P/fn).write_text(json.dumps(ob,ensure_ascii=False,indent=2)+'\n')
s=(P/'khu_final_bulk_fixture_test.dart.txt').read_text().replace(str(V),str(P)).replace('hasLength(63)','hasLength(64)').replace('hasLength(484)','hasLength(483)').replace('expect(added,1076)','expect(added,1107)').replace('hasLength(3158)','hasLength(3159)');(P/'khu_final_bulk_fixture_test.dart.txt').write_text(s)
(P/'HANDOFF.md').write_text((V/'HANDOFF.md').read_text()+'\n## v6 자체 정상 시험주 정정\n1380 EE21103 자체8주 Detection Oct20/22 2회와 1387 EE32500 자체 대면 진행·1–15주(8주 Mixers Oct21/26 포함) 29회는 이전 직접 전체 판독 근거로 복원했습니다. 파서 일반 시험주 필터로 자체 명시 정상수업을 삭제하지 않습니다. 추가31회/1강좌, 최신 누적3,159강좌/58,965회. 신규64강좌/1,107회. 불확정 큐483개. v5 원본 변경0, 이 v6가 최신 채택 후보입니다. 제품/SDK0.\n')
(P/'resume-ledger.json').write_text(json.dumps({k:v for k,v in proof.items()if k not in ['proofs','rawSHAs']},ensure_ascii=False,indent=2)+'\n');(P/'v6-correction-script.py').write_text(pathlib.Path(__file__).read_text());files={f.name:{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}for f in sorted(P.iterdir())if f.is_file()and f.name!='SHA256SUMS.json'};(P/'SHA256SUMS.json').write_text(json.dumps({'files':files,'SDKExecutions':0,'productWrites':0,'completionClaim':False},ensure_ascii=False,indent=2)+'\n');print(len(files),hashlib.sha256((P/'SHA256SUMS.json').read_bytes()).hexdigest())
