"""Retain public teaching fields; only 12 directly printed first meetings enabled."""
from pathlib import Path
import json,re,hashlib,collections,datetime
R=Path(__file__).resolve().parent
old=R.parent.parent/'catalog-c'/'ssu-all-2026-2.json'
src=json.loads(old.read_text());fresh=json.loads((R/'ssu-current-public-smallgroup-chapel-education-20261008.json').read_text())
auth=json.loads((R/'current-section-and-smallgroup-authority-20261008.json').read_text())
allowed=['이수구분(주전공)','이수구분(다전공)','공학인증','과목번호','과목명','수강유의사항','강좌유형정보','분반','교수명','개설학과','시간/학점(설계)','강의시간(강의실)','수강대상','교과영역']
redactions=collections.Counter()
def clean(v):
 for label,pattern in [('email',r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'),('phone',r'(?<!\d)0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)'),('webAccess',r'https?://[^\s<>]+')]:
  v,n=re.subn(pattern,'[연락·접속 정보 제외]',v);redactions[label]+=n
 return v
def edu(row):return {k:clean(row[k]) for k in allowed if k in row}
by=src['recordsByCode'];new={r['과목번호']:r for r in fresh['rows']};deltas=[];courses=[];cases=[]
for cid,rows in by.items():
 assert re.fullmatch(r'\d{10}',cid)
 educational=[edu(r) for r in rows]
 r=rows[0]
 if cid in new:
  for q in rows:
   assert {k:q.get(k,'') for k in allowed}=={k:new[cid].get(k,'') for k in allowed},cid
  r=new[cid]
 departments=list(dict.fromkeys(q['개설학과'] for q in rows));classes={};remarks={};credits={}
 for dep in departments:
  rr=[q for q in rows if q['개설학과']==dep]
  classes[dep]='/'.join(dict.fromkeys(q.get('이수구분(주전공)','') for q in rr))
  texts=[]
  for q in rr:
   for key in ['수강유의사항','수강대상','분반','강좌유형정보','공학인증','교과영역','이수구분(다전공)']:
    if q.get(key):texts.append(key+': '+clean(q[key]))
  remarks[dep]='\n'.join(dict.fromkeys(texts))
  credits[dep]=float(rr[0]['시간/학점(설계)'].split('/')[1].split('(')[0])
 meetings=[];period=None
 if cid in new:
  section=cid[-2:];g=next(g for g in auth['groups'] if section in g['sections']);i=g['sections'].index(section);start,end=g['clockRanges'][i]
  clock=r['강의시간(강의실)'];expected=f'{start//60:02}:{start%60:02}-{end//60:02}:{end%60:02}'
  assert expected in clock and '소예배실08106' in clock.replace(' ','')
  room='한경직기념관 소예배실 08106';date=g['startDate'];assert datetime.date.fromisoformat(date).isoweekday()==g['weekday']
  meetings=[{'date':date,'weekday':g['weekday'],'startMinute':start,'endMinute':end,'classroom':room,'deliveryMode':'inPerson'}]
  period={'startDate':g['startDate'],'endDate':g['endDate']}
  note='학교가 날짜·시각·장소를 직접 안내한 첫 수업 1회만 반영했습니다. 후속 정규수업과 공휴일 온라인 보강의 날짜·방식은 확인 중이며 추가하지 않았습니다. 자연대·공과대·IT대·AI대 1학년 신입생 대상이며 유급·재입학생은 제외됩니다. 지정 분반 외 출석 불가, 취소 후 재신청·일반채플 이동 불가.'
  cases.append({'nativeCourseId':cid,'date':date,'startMinute':start,'endMinute':end,'classroom':room,'section':section})
 else:note='현재 공개 강의의 수강 조건을 보존했습니다. 개별 수업 운영 검토 전으로 자동 시간표 추가는 아직 지원하지 않습니다.'
 for dep in remarks:remarks[dep]+=('\n' if remarks[dep] else '')+note
 c={'sourceId':f'ssu/main/2026-2/{cid}','campus':'main','academicYear':2026,'semester':'2','courseCode':cid[:8],'courseName':r['과목명'],'section':cid[-2:],'professor':r['교수명'],'classification':r.get('이수구분(주전공)',''),'departmentClassifications':classes,'credits':float(r['시간/학점(설계)'].split('/')[1].split('(')[0]),'departmentCredits':credits,'departments':departments,'departmentRemarks':remarks,'sourceSchedule':clean(r['강의시간(강의실)']),'sourceClassroom':clean(r['강의시간(강의실)']),'scheduleStatus':'scheduled' if meetings else 'unrecognized','schedules':meetings,'sourceEducation':{'nativeTenDigitCourseId':cid,'nativeSectionFlags':list(dict.fromkeys(q.get('분반','') for q in rows)),'allPublicQueryEducation':educational,'sectionBasis':'Current 2026-2 guide PDF page10: subject ID first8 digits; current chapel notice explicitly base(01..12) and native10 IDs; finance current notice separately confirms01=1분반/02=2분반. Other suffixes are derived from same format, not separately printed numeric sections.','directNumericSectionIndividuallyPrinted':cid in new or cid in ['5011566301','5011566302','2150624201','2150624202'],'partialSchedule':bool(meetings),'allMeetingsIndividuallyPrinted':bool(meetings),'currentSubsetRechecked':cid in new,'operatingReviewComplete':False,'remainingScheduleReason':'Subsequent meetings and online holiday makeup unresolved' if meetings else 'Operating semantic review pending','lectureType':r.get('강좌유형정보','')}}
 if period:c['period']=period
 courses.append(c)
x={'schemaVersion':2,'universityId':'ssu','campus':'main','campusName':'본교','institutionId':'institution:academyinfo:0000143','academicYear':2026,'semester':'2','publishedDate':'2026-10-08','sourceUrl':'https://ecc.ssu.ac.kr/sap/bc/webdynpro/sap/zcmw2100?sap-language=KO','courses':courses,'completionClaim':False,'wholeUniversitySupportComplete':False,'wholePreviousCurrentSemesterEducationRetained':True,'wholeCurrentDayRecheckComplete':False,'currentPublicRecheckScope':'12 small-group chapel courses; remaining2207 are preserved previous public2026-2 acquisition, not fresh current whole requery.'}
p=R/'ssu-main-2026-2.whole2219-partial-first12-v1.json';p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
a={'candidateSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'sourceSHA256':hashlib.sha256(old.read_bytes()).hexdigest(),'wholeCourseCount':len(courses),'publicQueryEducationRows':sum(len(c['sourceEducation']['allPublicQueryEducation']) for c in courses),'scheduledCourses':len(cases),'datedMeetings':len(cases),'freshPublicSubsetEducationChanges':0,'redactionTokenCounts':dict(redactions),'excludedFields':['계획 button/IDs','수강인원','여석','queryFile'],'cases':cases,'completionClaim':False}
assert len(courses)==2219 and len(cases)==12
(R/'ssu-whole2219-partial-first12-v1-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in a.items() if k!='cases'})
