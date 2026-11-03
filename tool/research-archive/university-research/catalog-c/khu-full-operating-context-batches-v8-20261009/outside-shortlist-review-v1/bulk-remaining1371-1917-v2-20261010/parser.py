import json,pathlib,re,copy,hashlib,datetime as dt,collections
O=pathlib.Path('work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1')
P=O/'bulk-remaining1371-1917-v2-20261010';assert not P.exists();P.mkdir()
registry=O/'whole1917-original-registry.json';xs=json.load(open(registry));assert len(xs)==1917
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
oldonline='현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.'
# Only operational fields are mode classified. Book titles, homework, prerequisites and curricular video topics are not modes.
remote=re.compile(r'온라인|비대면|원격|녹화|비실시간|블[랜렌]디드|하이브리드|[Vv][Oo][Dd]|[Zz]oom|콘텐츠\s*업로드|영상\s*강의')
special=re.compile(r'지도교수별|개별\s*(지도|연구|면담)|개인별|팀별\s*(지도|미팅)|집중\s*(강의|수업)|별도\s*(일정|배정)|임상\s*실습|현장\s*실습|인턴|실제\s*수업.*보고서')
rowhold=re.compile(r'시험|고사|Exam|exam|TEST|Test|test|퀴즈|Quiz|quiz|평가|발표|[Pp]resentation|[Pp]roject|프로젝트|보강|휴강|견학|답사|현장|야외|기말|중간|미팅|면담|상담')
selected={};proof=[];queue=[];shas={str(registry):hashlib.sha256(registry.read_bytes()).hexdigest()}
for n,x in enumerate(xs,1):
 if n<1371:continue
 c=x['originalWholeObject'];reason=[];plans=x['plans'];native=list(slot.finditer(c['sourceSchedule']))
 if not native or re.sub(r'[\s,]','',slot.sub('',c['sourceSchedule'])):reason.append('native_clock_unparsed_or_absent')
 elif any(int(m[2])*60+int(m[3])>=int(m[4])*60+int(m[5]) for m in native):reason.append('native_clock_range_invalid')
 if len(plans)!=1:reason.append('no_plan' if not plans else 'multiple_professor_plan_allocation_pending')
 if reason:queue.append({'ordinal':n,'sourceId':c['sourceId'],'reason':reason});continue
 z=plans[0];p=z['originalWholeEducationPlan'];sec={s['section']:s['rows'] for s in p['educationalSections']}
 for key in ['기본정보','수업운영방식','수업유형 및 방법','수업개요 및 목표','주별강의내용']:
  if key not in sec:reason.append('missing_section:'+key)
 if reason:queue.append({'ordinal':n,'sourceId':c['sourceId'],'reason':reason});continue
 basic=sec['기본정보'];code=[r[1] for r in basic if r[0]=='학수번호'];clock=next((r[1] for r in basic if r[0]=='강의시간강의실'),'')
 if p['header']!=['2026학년도 2학기 강의계획서'] or p['campus']!={'seoul':'서울','global':'국제'}.get(c['campus']) or code!=[p['lectureCode']] or p['lectureCode']!=c['sourceEducationalVariants'][0]['lecture_cd']:reason.append('own_current_identity_or_campus_mismatch')
 prof=p['queriedProfessorName'];cl=re.sub(r'\s+','',clock)
 if prof not in [v['teach_na'] for v in c['sourceEducationalVariants']]:reason.append('own_professor_mismatch')
 for m in native:
  token=m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5]
  if token not in cl or re.sub(r'\s+','',m[6]) not in cl or re.sub(r'\s+','',prof+' '+token) not in cl:reason.append('own_full_clock_group_unmatched')
 op=sec['수업운영방식'];choice=next((r for r in op if r and r[0]=='수업운영방식'),[]);extra=' '.join(str(v) for r in op if r and r[0]=='추가설명' for v in r[1:])
 progress=' '.join(str(v) for r in sec['수업유형 및 방법'] if r and r[0] in ['수업진행추가설명','수업유형추가설명'] for v in r[1:])
 overview=' '.join(str(v) for r in sec['수업개요 및 목표'] for v in r[1:])
 physicalExplicit=bool(re.search(r'대면\s*수업|대면수업|대면\s*강의|대면강의|[Ff]ace[ -]?to[ -]?[Ff]ace',extra+' '+progress)) or len(choice)>1 and bool(choice[1].strip())
 if not physicalExplicit:reason.append('no_explicit_physical_operation')
 if len(choice)>2 and any(str(v).strip() for v in choice[2:]):reason.append('other_operating_mode_selected')
 remoteMatches=list(remote.finditer(extra));conditionalRemote=bool(remoteMatches) and all(re.search(r'필요|상황|경우|공휴일|휴강|출장|부득이|특별한|불가피|보강',extra[:m.start()]) for m in remoteMatches) and not re.search(r'후반|이후.*온라인|온라인.*이후|[0-9]+%|[0-9]+주차|하이브리드|블[랜렌]디드|1-2회|1–2회',extra)
 if remote.search(progress) or remoteMatches and not conditionalRemote:reason.append('remote_or_conditional_mode_requires_context_review')
 if re.search(r'독립심화|연구연수|졸업논문',str(basic[0])):reason.append('individual_research_operation_requires_exact_group_review')
 if re.search(r'유연하게|탄력적으로|일정.*조율|미팅.*조율|필드 리서치|현장 조사를 해야',progress):reason.append('flexible_or_field_operation_requires_exact_group_review')
 if special.search(extra+' '+progress+' '+overview):reason.append('individual_or_special_operation_pending')
 method=sec['수업유형 및 방법'];mc=next((r for r in method if r and r[0]=='수업방법'),[])
 if len(mc)>6 and mc[6].strip() and not re.search(r'대면.{0,8}(원칙|기본|진행)|전체.{0,10}대면|강의실.{0,10}대면|100%.{0,8}대면',extra):reason.append('online_method_selected_requires_context_review')
 if reason:queue.append({'ordinal':n,'sourceId':c['sourceId'],'reason':sorted(set(reason))});continue
 rows={int(r[0][:-1]):r for r in sec['주별강의내용'] if r and re.fullmatch(r'\d+주',r[0])};allowed=[];excluded=[];meetings=[];literal=[]
 for w in range(1,17):
  r=rows.get(w);why=[]
  if r is None or len(r)<3:why.append('missing_week_row')
  else:
   match=re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',r[1]);a=dt.date(2026,9,1)+dt.timedelta(days=7*(w-1));b=a+dt.timedelta(days=6)
   if not match or tuple(map(int,match.groups()))!=(a.month,a.day,b.month,b.day):why.append('own_week_date_anchor_mismatch')
   text=' '.join(str(v) for v in r[2:])
   if not str(r[2]).strip():why.append('blank_teaching_content')
   if remote.search(text):why.append('weekly_remote_or_ambiguous')
   if special.search(text):why.append('weekly_individual_or_special_operation')
   if rowhold.search(text):why.append('evaluation_makeup_or_special_week')
   if w in [8,16]:why.append('general_exam_week_no_parser_override')
  if why:excluded.append({'week':w,'reasons':why,'wholeRow':r});continue
  allowed.append(w);literal.append(r)
  for m in native:
   wd='월화수목금토일'.index(m[1])+1;day=a+dt.timedelta(days=(wd-a.isoweekday())%7)
   if day.isoformat() in closed:continue
   meetings.append({'date':day.isoformat(),'weekday':wd,'startMinute':int(m[2])*60+int(m[3]),'endMinute':int(m[4])*60+int(m[5]),'classroom':m[6].strip()})
 # Duplicate same clock is not silently collapsed. Multi-allocation needs separate review.
 if len({tuple(t.items()) for t in meetings})!=len(meetings):queue.append({'ordinal':n,'sourceId':c['sourceId'],'reason':['duplicate_native_group_allocation_pending']});continue
 if not meetings:queue.append({'ordinal':n,'sourceId':c['sourceId'],'reason':['no_whole_regular_week_group_survived'],'weeklyExcluded':excluded});continue
 raw=pathlib.Path(z['file']);shas[str(raw)]=hashlib.sha256(raw.read_bytes()).hexdigest()
 assert json.load(open(raw))==p
 selected[c['sourceId']]=meetings
 proof.append({'ordinal':n,'sourceId':c['sourceId'],'originalWholeObject':c,'wholeEducationPlan':p,'sourceFile':z['file'],'sourceSHA256':shas[str(raw)],'nativeClockLiteral':c['sourceSchedule'],'ownProfessorClockLiteral':clock,'ownOperationWholeRows':op,'ownOperationProgressLiteral':progress,'allowedWeeksLiteral':allowed,'allowedWholeRowsLiteral':literal,'excludedWeeksLiteral':excluded,'expectedWholeMeetings':meetings,'mode':'physical_user_preference_preserved','actualAttendanceConfirmed':False})
prior={};archive={};added=0;dates=0
note='当前 2026-2 원문 자체 명시 대면 운영·절대 수업시각·교수·캠퍼스·주차 기간이 일치하는 정규 전체 수업 그룹만 부분 예약합니다. 원격·혼합·개별 배정·평가·보강·운영 미확정 그룹은 예약하지 않고 원문과 별도 큐에 보존합니다. 사용자 강의 방식과 기존 개인 데이터는 유지하며, 실제 출석 또는 대학 전체 변경 확인 완료를 뜻하지 않습니다.'.replace('当前','현재')
for campus in ['seoul','global']:
 old=json.load(open(O/'packet047-reviewed30'/f'khu-{campus}-2026-2.packet047-physical-groups-prepared.json'));new=copy.deepcopy(old);prior[campus]=old
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'],c['sourceId'];added+=1;dates+=len(selected[c['sourceId']]);archive[c['sourceId']]=copy.deepcopy(c['departmentRemarks']);c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace(oldonline,'')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside_bulk_remaining_v1'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.bulk-remaining-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n');(P/f'prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n')
assert added==len(selected);assert len(queue)+len(proof)==547
out={'completionClaim':False,'SDKExecutions':0,'productWrites':0,'range':[1371,1917],'processedNative':547,'newCourses':added,'newMeetings':dates,'baselineCourses':3095,'baselineMeetings':57858,'candidateCourses':3095+added,'candidateMeetings':57858+dates,'uncertainQueueCount':len(queue),'uncertainReasonCounts':dict(collections.Counter(k for q in queue for k in q['reason'])),'rawSHAs':shas,'proofs':proof}
(P/'bulk-independent-proof.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');(P/'uncertain-operating-queue.json').write_text(json.dumps(queue,ensure_ascii=False,indent=2)+'\n');(P/'previous-full-remarks-archive.json').write_text(json.dumps(archive,ensure_ascii=False,indent=2)+'\n');(P/'parser.py').write_text(pathlib.Path(__file__).read_text());(P/'whole-source-range.json').write_text(json.dumps(xs[1370:],ensure_ascii=False,indent=2)+'\n')
(P/'resume-ledger.json').write_text(json.dumps({k:v for k,v in out.items() if k not in ['proofs','rawSHAs']},ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in out.items() if k not in ['proofs','rawSHAs']})
