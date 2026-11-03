"""Literal current source date heads; preserve native continuous reservation clocks."""
import copy, datetime as dt, hashlib, json, re
from pathlib import Path
from sogang_public_education import same_educational_value
R=Path(__file__).parent;O=R/'sogang-additions-v15-20261008';B=R/'sogang-additions-v14-20261008/sogang-unknown-2026-2.one-hundred-thirty-three-reviewed-20261008.json'
base=json.loads(B.read_text());out=copy.deepcopy(base);proofs=[];held=[]
configs={
'AAT3007-01':(['09-18','10-09','10-23','11-20','11-27'],None,'10/23 원문정규주제와 native75분중간시험 충돌; 녹화강의 10/9·11/20·27의 실제시청시각미배정 보류. 10/30·11/6·12/11·18 Zoom발표 liveOnline;10/16 in-class퀴즈·12/4프로젝트작업 inPerson. 초급웹개발 개인연습·AI없는퀴즈·프로젝트 제출조건.'),
'AIE4091-01':(['10-05','10-19','10-26','12-21'],None,'원문 CSE4187/AIE4091 (01분반) 공동표기 실제교차개설 참조 보존. 10/5·19 온라인강의 live/녹화 시각미배정;10/26리포트와 native시험 충돌·12/21시험실제시각미공개 보류. TrackA/B 팀 구성·기업멘토·ANCHOR·예산/완료보고조건.'),
'CSE4187-01':(['10-05','10-19','10-26','12-21'],None,'원문 CSE4187/AIE4091 (01분반) 공동표기와 native각개설 sourceId 보존. 10/5·19 온라인강의운영 미배정·10/26리포트·12/21시험시간 미확인 보류. 팀구성·기업멘토·TrackA/B·예산신청조건.'),
'CHS2004-01':(['10-05','12-14'],'10-26','10/5 대면휴강 보강영상 실제시청시각미배정, 원문기말12/14시험실제시각미공개 보류. source/native10/26중간고사75분J219. 수업내다큐/영상시청은 별도VOD수업으로 변환하지 않음. 토론서·두번글쓰기조건.'),
'CHS2004-02':(['09-18','09-25','10-09','11-20','12-18'],'10-23','추석/한글날휴강 및 1주일 내 ppt녹강 보강시청 미배정 보류. source/native10/23중간시험75분J215;기말12/18미공개시각 보류. 사전자료읽기·조별토론·수업중영상감상조건.'),
'CSE4115-01':(['09-18','09-25','10-09','11-20','12-18'],'10-23','추석개인발표 온라인동영상·11/20온라인팀발표 실제방식/시각 미배정, 공휴일·축제·기말시험시각 미확인보류. source/native10/23시험75분K502. 12/11실제팀최종발표 정규범위. 팀과제·ANCHOR·연계전공기본과목이수권고조건.'),
'ECO2002-06':(['09-18','09-25','10-09','10-23','11-20','12-18'],None,'주1회연강 실제1차75분+휴식15분+2차75분, 출석2회 원문명시;전체165분 예약범위 보존. 추석/한글날 비대면강의 시각미배정, 중간시험 GN202/GN203 개별방배정미확인·기말시각 미공개 보류. 한국어시험/영어시험지없음·예습·연습문제조건.'),
'EDU3045-01':(['09-21','10-05','10-26','12-14','12-21'],None,'native EDU3045와 원문EDU-3045 동일숫자 원문별칭 보존. 9/21동영상강의 혼합시각,10/26과제작성/LMS제출,12/14기말시험시각,12/21동영상특강시청시각 미배정 보류. 교직수강대상·PBL·팀프로젝트·개인도서사례과제.'),
'EDUS982-01':(['10-05','12-18'],'10-26','원문교직(3)/과학교육이수 및 native교직이수자만 전공학점인정 조건.10/5LMS보강 시각미배정;12/18 개인발표자료 제출기한은 정규수업일이아님. source/native10/26중간시험75분J114. 12/21기말평가·발표·토론 실제연속수업 예약범위165분;별도시험추정없음. 논술·개인수업실연·피드백·AI윤리조건.'),
'EDUS983-01':(['09-24','10-15','10-22','12-17'],None,'과학교직이수·교직이수자만 전공학점인정. source10/15중간평가 실제시간미공개 vsnative10/22중간시험 및 source동일날짜정규강의 충돌 두날짜보류.12/17대면기말시험 실제시각미공개. 나머지실습/팀활동/수업실연 실제날짜만.'),
'EEE2105-01':(['10-05','10-26','12-21'],None,'첨단반도체세미나 원문현재연사별 날짜·50분범위.10/26중간·12/21기말휴강: native중간75분시험표와 충돌하므로 예약안함. 초청연사/세미나주제 원문교육메타보존;학교공지및연사일정변경조건.'),
'ENG3216-01':(['09-18','09-25','10-09','10-23','11-20','12-18'],None,'한국어강의·학부2/3/4대상. source10/23정규문학주제 vsnative중간75분시험충돌보류.9/30과제제출은 수업날짜아님.10/9·11/20YouTube보강 실제시청시각미배정,12/18기말시험미공개시각 보류. 읽기자료·1쪽과제조건.'),
'EUR4108-01':(['09-18','09-25','10-09','11-20','12-18'],'10-23','원문주차역순표제의 직접날짜 유지. source/native10/23필기중간75분J204;기말12/18실제시각미공개.9/25·10/9오프라인혹은온라인 보강예정 날짜조정조건/실제미배정 held. 읽기·토론·발표조건.'),
'HIS3062-01':(['10-05','12-21'],'10-26','source/native10/26중간75분J215;12/21기말시험 실제시각미공개.10/5휴강 보강은 학교/학생협의후 일정미배정.사료강독·해제·발표자료 사전읽기조건.'),
'HIS3083-01':(['09-18','09-25','10-02','10-09','10-23','11-13','11-20','12-11','12-18'],None,'10/2온라인강의/화면공유 운영조건 확인미완료보류;10/23시험기간만표시 실제시험운영미확인.11/13대면미실시 자율작업+사전신청온라인자문,12/11별도약속 비대면구술시험 미배정.11/27프로젝트작업 수업시간내필수출석·12/4최종발표 비발표자출석 실제165분. 노트북필수/태블릿불가·출석페널티.'),
'HSS3016-01':(['09-24','10-22','12-17'],None,'source50분/학년1~3(3학년진로미결정자) 및 native학년제한 전체신청기간 유지/SU평가 보존.10/22수업없음 워크넷검사+직무카드 대체 vsnative75분시험 충돌 보류.12/17수업없음 커리어로드맵제출 보류. 진로프로그램 참여권장조건.')}
held_reasons={
'AAT4011-01':'Native current remarks explicitly 비대면 실시간100%강의 but current original PDF on-site tutorial/presentation/seminar and mixed online/on-site practice. Whole conflicting delivery held; no silent modality choice.',
'EDU3046-01':'Actual attached original title explicitly2025년도2학기 conflicts current2026-2 native publication; no year correction.',
'ENGG003-01':'Actual attached plan prints onlyENG5003 graduate code, no explicitENGG003 cross-list identity; graduate/undergraduate eligibility alone insufficient to infer identity.',
'HFU4024-01':'CU12 sharing course original15-week calendar startsAug31 before ownSogangSep1, endsDec7, sourcemidOct19 report vsnativeOct26 exam. Own special CU operating calendar/clock allocation unconfirmed; no inferred university-calendar shift.'}
for key,reason in held_reasons.items():
 s=json.loads((O/f'{key}.source-education.json').read_text());c=next(c for c in out['courses'] if c['courseCode']+'-'+c['section']==key);assert not c['schedules'];held.append({'offering':key,'reason':reason,'sourcePDFSHA256':s['fileSha256']})
head=re.compile(r'(?<!\d)(?:Week\s*\d+|\d+\s*주차|주차\s*\d+)(?!\d)',re.I)
for key,(excluded,exam_day,note) in configs.items():
 s=json.loads((O/f'{key}.source-education.json').read_text());row=s['currentPublicRow'];text=s['weeklyOperatingText'].replace('\x00',' ');c=next(c for c in out['courses'] if c['courseCode']+'-'+c['section']==key);assert not c['schedules'];assert all(same_educational_value(k,row.get(k,''),v) for k,v in c['sourceEducationalMetadata'].items())
 clock=re.search(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})',row['meetingText']);start=int(clock[1])*60+int(clock[2]);end=int(clock[3])*60+int(clock[4]);room=re.search(r'\[([^\]]+)\]',row['meetingText'])[1];assert end-start in {50,110,165}
 markers=list(head.finditer(text));date_sources={};traces=[]
 for i,m in enumerate(markers):
  block=text[m.start():markers[i+1].start() if i+1<len(markers) else len(text)]
  dm=re.search(r'\(\s*(\d{1,2})\s*[/.]\s*(\d{1,2})\s*\)',block[:160])
  if not dm:continue
  date=dt.date(2026,int(dm[1]),int(dm[2]));date_sources[date.isoformat()]=block
 g=json.loads((O/f'{key}.date-geometry.json').read_text());assert g['sourcePDFSha256']==s['fileSha256'];assert g['educationalDateTokens']
 holds=[];plans=[];ex={'2026-'+x for x in excluded}|{'2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-11-20'}
 for ds,block in sorted(date_sources.items()):
  date=dt.date.fromisoformat(ds)
  if ds in ex:holds.append({'date':ds,'reason':note,'originalWeekBlock':block});continue
  assert dt.date(2026,9,1)<=date<=dt.date(2026,12,21),(key,ds)
  expectedweekday=1 if row['meetingText'].startswith('월') else 4 if row['meetingText'].startswith('목') else 5;assert date.isoweekday()==expectedweekday,(key,ds)
  plan={'date':ds,'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room}
  if exam_day and ds=='2026-'+exam_day:
   exam=re.fullmatch(r'(\d{2})\.(\d{2})\([^)]+\)(\d{2}):(\d{2})~(\d{2}):(\d{2})\[([^\]]+)\]',row['exam']);assert exam and ',' not in exam[7];assert ds==f'2026-{exam[1]}-{exam[2]}' and re.search(r'중간|Mid',block);plan.update(startMinute=int(exam[3])*60+int(exam[4]),endMinute=int(exam[5])*60+int(exam[6]),classroom=exam[7]);assert plan['endMinute']-plan['startMinute']==75
  if key=='AAT3007-01':
   if ds in {'2026-10-30','2026-11-06','2026-12-11','2026-12-18'}:assert 'zoom class' in block;plan['deliveryMode']='liveOnline'
   if ds in {'2026-10-16','2026-12-04'}:assert 'in-class' in block
  plans.append(plan);matches=[t for t in g['educationalDateTokens'] if re.search(rf'0?{date.month}\s*[/.]\s*0?{date.day}(?!\d)',t['text'])];assert matches,(key,ds);traces.append({'date':ds,'numericHeaderToken':matches[0],'geometryFile':f'{key}.date-geometry.json','originalWeekBlock':block})
 assert plans,key
 c.update(schedules=plans,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':plans[0]['date'],'endDate':plans[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':len(plans),'attendanceConfirmed':False})
 if key=='EDUS982-01':c['sourceNativeClassification']='교직'
 c['sourcePublishedReservationNote']='공개 시작·끝 연속 수업 예약범위 보존; 휴게·구간별 실제 운영 미확인.' if key!='ECO2002-06' else '원문75분수업+15분휴게+75분수업의165분연속 예약범위, 출석2회.'
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]+='\n'+note+'\n'+c['sourcePublishedReservationNote']
 proofs.append({'offering':key,'sourcePdfSHA256':s['fileSha256'],'holds':holds,'meetings':plans,'addedPlans':len(plans),'nativeClock':row['meetingText'],'actualExamDate':'2026-'+exam_day if exam_day else None,'sourceDateGeometry':traces,'operatingNote':note});print(key,len(plans))
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],out['courses']) if a!=b];assert len(changed)==16
count=sum(len(c['schedules']) for c in out['courses']);scheduled=sum(bool(c['schedules']) for c in out['courses']);assert scheduled==149
f=O/'sogang-unknown-2026-2.one-hundred-forty-nine-reviewed-20261008.json';f.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
a={'baseFile':str(B),'baseSHA256':hashlib.sha256(B.read_bytes()).hexdigest(),'candidateFile':f.name,'candidateSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'whole':1541,'reviewedNativeOfferings':20,'previousScheduled':133,'previousPlans':3305,'addedScheduled':16,'addedPlans':count-3305,'scheduled':scheduled,'plans':count,'changedOnly':changed,'proofs':proofs,'reviewedStillHeld':held,'otherOfferingsAndSourceIdsUnchanged':True,'productionEdited':False,'completionClaim':False};(O/'additions-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print(scheduled,count)
