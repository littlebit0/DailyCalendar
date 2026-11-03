"""Conservative current public header projection, with unknown campus and unit gates."""
import collections,datetime,hashlib,json,re
from pathlib import Path
P=Path(__file__).parent;D=P/'pknu-current-20261008'
def read(p):return json.loads(p.read_text())
def write(f,d):(D/f).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
old={r['identity']:r for r in read(P/'pknu-course-rows.json')};current=read(P/'pknu-latest-rows.json');closed={r['identity']for r in old.values()if r.get('closedPhases')};assert len(closed)==114
rule=read(P/'pknu-current-clock-policy-audit.json');assert rule['revision']=='2026-01-21'
buildings={'A11','A12','A13','A15','A21','A22','A23','B11','B12','B13','B14','B15','B21','B22','C11','C12','C13','C15','C21','C22','C23','C24','C25','D15','D16','D22','D24','E13','E14','E21','E22'}
exception=read(P/'pknu-v2-rolling-comparison.json')['academicDateRestrictionEvidence'];date_hold={x['identity']for x in exception if not any(t in x['title']for t in ['미적분학','계산대수학','선형대수학','2행정디젤기관실습','품질및신뢰성공학','성인간호학Ⅰ','동북아네트워크와문화'])}
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
explicit={'104866-101':['09-04','09-11','09-18','10-02','10-16','10-23','10-30','11-06','11-13','11-20','11-27','12-04','12-11','12-18'],'114376-101':['09-02','09-16','09-23','09-30','10-07','10-14','10-21','10-28','11-04','11-11','11-18','11-25','12-02','12-16'],'114380-101':['09-03','10-22','11-05','11-26']}
courses=[];holds=[];groups=collections.defaultdict(list)
for r in current:
 identity=r['COURSE_NO']+'-'+r['DCLSS_NO'];assert identity not in closed and r['CLS_CLSS_YN']=='N';o=old.get(identity,{});f=P/'pknu-current-syllabus'/(identity+'.json');plan=read(f)if f.exists()else{};fields=plan.get('fields',{})
 fresh=D/(identity+'.selected-education.json')
 if fresh.exists():freshplan=read(fresh);fields={k:(', 'if k=='강의실'else' ').join(v)for k,v in freshplan['fields'].items()};plan={**plan,'fields':fields,'verifiedAt':freshplan['verifiedAt']}
 source=fields.get('강의시간','');room=fields.get('강의실','');method=fields.get('강의형태','');s=source
 for a,b in [('Monday','월'),('Mon','월'),('Tuesday','화'),('Tue','화'),('Wednesday','수'),('Wed','수'),('Thursday','목'),('Thu','목'),('Friday','금'),('Fri','금'),('Saturday','토'),('Sat','토'),('Sunday','일'),('Sun','일')]:s=re.sub(r'\b'+a+r'[.]?',b,s,flags=re.I)
 native=[];pat=re.compile(r'([월화수목금토일])\s*([0-9]+(?:\s*[-~,]\s*[0-9]+)*)')
 for m in pat.finditer(s):
  day='월화수목금토일'.index(m[1])+1
  for part in m[2].split(','):
   ns=re.split('[-~]',part.strip());a=int(ns[0]);b=int(ns[-1]);assert a<=b
   native.extend({'weekday':day,'period':n}for n in range(a,b+1))
 remainder=pat.sub('',s).strip(' ,;/');reasons=[]
 if not plan:reasons.append('current public syllabus button absent; no unpublished plan queried')
 if not native:reasons.append('current header contains no fixed weekly periods')
 if remainder:reasons.append('unrecognized remaining native period text')
 if method not in {'대면 수업'}and identity not in explicit:reasons.append('current remote/mixed method actual per-period operation unresolved')
 if identity in date_hold and identity not in explicit:reasons.append('individual academic date/period/holiday evidence needs complete semantic review')
 if identity not in explicit and any(x['weekday']in [2,4]for x in native):reasons.append('current Tuesday/Thursday 50/75 unit not published in header; July unit cannot be assumed current')
 if o.get('unit')=='75'and any(x['weekday']not in [2,4]for x in native):reasons.append('July75 unit conflicts with current rule weekday scope')
 if any(x['period']not in range(15)for x in native):reasons.append('native period outside current official clock table')
 # A single explicit current source room is required. Multiple rooms lack source weekday pairing.
 roommatches=re.findall(r'\b([A-Z]\d{1,2})-\d+[A-Z]?\b',room)
 singleroom=bool(re.fullmatch(r'[A-Z]\d{1,2}-\d+[A-Z]?',room.strip()))
 campus='daeyeon'if roommatches and all(x in buildings for x in roommatches)else'unknown'
 if not singleroom:reasons.append('current room is absent/multiple/nonstandard and per-period mapping not verified')
 if campus=='unknown':reasons.append('current physical campus not established by current guide building map')
 if re.search('승선|임상|현장|인턴|군사학|실습기관',r['SBJT_KOR_NM'])and identity not in explicit:reasons.append('individual field/ship/clinical/military operation not proven by weekly header')
 blocks=[]
 if not reasons:
  unit=75 if identity=='114380-101' else 50
  for x in native:
   n=x['period'];a=540+90*(n-1)if unit==75 else 480+60*n;b=a+unit
   assert 0<=a<b<1440
   blocks.append({'weekday':x['weekday'],'startMinute':a,'endMinute':b,'classroom':room,'sourcePeriod':n,'sourceMinuteUnit':unit})
 dates=[]
 if identity in explicit and blocks:dates=[datetime.date.fromisoformat('2026-'+x)for x in explicit[identity]]
 elif blocks:dates=[datetime.date(2026,9,1)+datetime.timedelta(days=i)for i in range(98)if str(datetime.date(2026,9,1)+datetime.timedelta(days=i))not in holidays]
 schedules=[]
 for date in dates:
  for b in blocks:
   if date.isoweekday()==b['weekday']:schedules.append({**b,'date':str(date)})
 note='현재 공개 강의계획서의 학수번호·분반·시간·강의실을 보존합니다. 공개 계획이며 실제 출석 확정이 아닙니다. 정규 계획은 9/1~12/7, 기말·보강의 개별 시간은 확정하지 않았습니다. 현재 학과 전체 범위와 모든 개별 운영 예외는 검증되지 않았습니다.'
 if reasons:note+=' 일정 미생성: '+'; '.join(reasons)
 if identity in explicit:
  note+=' 이 강좌는 강의계획서에 실제 명시된 날짜만 반영했습니다.'
  if identity=='104866-101':note+=' 원문 12월09dlf 보강은 불명확한 날짜표기 및 평소 금요일 밖의 시각 미확정으로 제외했습니다.'
  if identity=='114376-101':note+=' 9/9 수상레저관 스마트짐 수업은 정확한 실번호가 없어 제외했습니다.'
  if identity=='114380-101':note+=' 9/3,10/22,11/5,11/26 전체 대면 2교시만 반영했습니다. 나머지 혼합 수업의 대면/비대면 교시 순서 및 기말 날짜는 미확정으로 제외했습니다.'
 dept=o.get('department');depts=sorted({x for x in [dept,*o.get('targetDepartments',[])]if x});credit=float(r['PNT_THEO_PRAC'].split('-')[0]);classification=r.get('SBJT_FG_NM','')
 note+=' 현재 강의실 건물로 확인된 캠퍼스: '+('대연캠퍼스' if campus=='daeyeon' else '미확인')+'; 7/30 원문 캠퍼스: '+o.get('campus','미공개')+'; 현재 단위 불명확한 화/목은 일정으로 치환하지 않았습니다.'
 note+=' 원문 강의형태: '+method+'; 수강대상학년: '+fields.get('개설학년','')+'; 공개 대상학과(7/30): '+', '.join(depts)
 education={k:r[k]for k in ['YY','SHTM_CD','SHTM_NM','UNIV_GRSC_CLSF','COURSE_NO','DCLSS_NO','PNT_THEO_PRAC','SBJT_KOR_NM','SBJT_FG_NM','STAFF_NM','CLS_CLSS_YN']}
 c={'sourceId':'pknu-2026-2-'+identity,'campus':campus,'academicYear':2026,'semester':'2','courseCode':r['COURSE_NO'],'courseName':r['SBJT_KOR_NM'],'section':r['DCLSS_NO'],'professor':r.get('STAFF_NM')or'','credits':credit,'classification':classification,'departments':depts,'departmentCredits':{x:credit for x in depts},'departmentClassifications':{x:classification for x in depts},'departmentRemarks':{x:note for x in depts},'remarks':note,'sourceSchedule':source,'sourceClassroom':room,'scheduleStatus':'scheduled'if schedules else'unrecognized','period':{'startDate':'2026-09-01','endDate':'2026-12-20'},'schedules':schedules,'sourceNativePeriods':native,'sourceSnapshotCampus':o.get('campus',''),'sourceSnapshotMinuteUnit':o.get('unit',''),'sourceCurrentEducation':education,'publicPlanEducation':{'identity':identity,'fields':fields,'verifiedAt':plan.get('verifiedAt'),'periodRestrictionEvidence':plan.get('periodRestrictionEvidence',[])},'dateProofKind':'explicit individual dates'if identity in explicit else'published ordinary weekday plan excluding holidays; not attendance confirmation','campusEvidence':'current guide printed4 explicit Daeyeon building map'if campus=='daeyeon'else'current physical campus unknown; July snapshot label preserved separately'}
 if reasons:holds.append({'identity':identity,'reasons':reasons})
 courses.append(c);groups[campus].append(c)
datasets=[]
for campus,rows in groups.items():
 f=f'pknu-{campus}-2026-2.published-partial-20261008.json';write(f,{'schemaVersion':2,'universityId':'pknu','campus':campus,'campusName':'대연캠퍼스'if campus=='daeyeon'else'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-10-07','sourceUrl':'https://www.pknu.ac.kr/main/112','courses':rows});datasets.append({'file':f,'sha256':hashlib.sha256((D/f).read_bytes()).hexdigest(),'classes':len(rows)})
audit={'completionClaim':False,'knownOwningOrganizationQueries':120,'currentIdentityCount':len(current),'datasets':datasets,'scheduledClasses':sum(bool(c['schedules'])for c in courses),'datedMeetings':sum(len(c['schedules'])for c in courses),'holds':holds,'knownClosureCount':len(closed),'knownClosuresStillPresent':sorted(set(c['courseCode']+'-'+c['section']for c in courses)&closed),'excludedHolidays':sorted(holidays),'ordinaryDates':['2026-09-01','2026-12-07'],'semester':['2026-09-01','2026-12-20'],'explicitDateProof':explicit,'unverified':['whole current organization coverage','current Tuesday/Thursday units except explicitly proven75','individual operations outside selected dated plans','public152 unavailable plans and external146 actual timing','later updates after Oct7 known nativecatalog read'],'noLoginOrVisibleUI':True,'productionChanged':False}
write('candidate-audit.json',audit);print(json.dumps({'classes':len(current),'scheduled':audit['scheduledClasses'],'meetings':audit['datedMeetings'],'held':len(holds),'campuses':{k:len(v)for k,v in groups.items()}},ensure_ascii=False))
