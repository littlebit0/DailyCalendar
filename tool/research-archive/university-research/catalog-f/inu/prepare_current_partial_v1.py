"""Freeze current public educational identity plus conservative dated reservations."""
from pathlib import Path
from datetime import date,timedelta
from collections import Counter
import importlib.util,hashlib,json,re,io
from pypdf import PdfReader
ROOT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('collector',ROOT/'collect_current_public_education.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def save(name,obj):
 p=ROOT/name;p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n');return hashlib.sha256(p.read_bytes()).hexdigest()
closure_url='https://www.inu.ac.kr/bbs/inu/246/393806/download.do'
body=m.fetch(closure_url); rows=m.educational_rows(body)
assert rows[0]['A']=='2026학년도 2학기 2차 폐강 교과목 현황'
closed=[{'nativeCourseId':r['F'],'courseName':r['H'],'department':r['C'],'classification':r['E'],'status':'폐강'} for r in rows[2:] if re.fullmatch('[A-Z0-9]{10}',r.get('F',''))]
closed_ids={r['nativeCourseId'] for r in closed}
save('inu-current-closure-education-20261008.json',{'sourceUrl':closure_url,'sourceSHA256':hashlib.sha256(body).hexdigest(),'publishedDate':'2026-09-15','nativeHeading':rows[0]['A'],'closedCourses':closed,'rawBodySaved':False})
cal_url='https://inu.ac.kr/bbs/safety/358/380929/download';body=m.fetch(cal_url)
t='\n'.join(p.extract_text() for p in PdfReader(io.BytesIO(body)).pages)
assert '제2학기 개강' in t and '2학기 보강주간' in t
holidays=['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09']
save('inu-current-term-boundary-20261008.json',{'sourceUrl':cal_url,'sourceSHA256':hashlib.sha256(body).hexdigest(),'nativeHeading':'2026년도 학사운영계획','startDate':'2026-09-01','finalExamStartDate':'2026-12-08','finalExamEndDate':'2026-12-14','makeupStartDate':'2026-12-15','makeupEndDate':'2026-12-21','termEndDate':'2026-12-21','termEndBasis':'Published makeup-week end, not invented per-course attendance','reservationEndDate':'2026-12-07','excludedHolidays':holidays,'rawBodySaved':False})
source=json.loads((ROOT/'inu-current-whole2437-education-20261008.json').read_text())
def parse(text):
 groups=re.findall(r'\[([^\[\]]+)\]',text)
 if ''.join(re.findall(r'\[[^\[\]]+\]',text)).replace(' ','')!=text.replace(' ',''):return None
 out=[]
 for g in groups:
  if ':' not in g:return None
  room,rest=g.split(':',1)
  if not re.fullmatch(r'(?:\d{2}|N[A-D]|Z[B-C])-\S+',room):return None
  parts=rest.split(',')
  for part in parts:
   if not part or part[0] not in '월화수목금토일':return None
   day='월화수목금토일'.index(part[0])+1
   clocks=re.findall(r'\((\d{2}):(\d{2})~(\d{2}):(\d{2})\)',part[1:])
   if ''.join('('+a+':'+b+'~'+c+':'+d+')' for a,b,c,d in clocks)!=part[1:]:return None
   for a,b,c,d in clocks:
    start,end=int(a)*60+int(b),int(c)*60+int(d)
    if end<=start or end>1440:return None
    out.append({'weekday':day,'startMinute':start,'endMinute':end,'classroom':room})
 return out or None
courses=[];reasons=Counter();parse_failed=[]
for r in source['educationRows']:
 cid=r['학수번호'];reason=''
 if cid in closed_ids:reason='2026-09-15 2차 폐강'
 elif r['집중이수제']!='일반(1~15주)':reason='집중이수 실제 날짜 확인 필요'
 elif r['수업방법']:reason='온라인·혼합 방식의 실제 운영 날짜 확인 필요'
 elif r['수업구분']!='일반과목':reason='현장실습·교환·특수 수강 대상 운영 확인 필요'
 elif r['수업유형'] not in ['강의(이론)','실험실습','이론+실험실습','이론+어학','미술실기','체육실기','예술체육실기']:reason='특수 수업유형 운영 확인 필요'
 slots=parse(r['시간표(시간)'])
 if not reason and not slots:reason='전체 요일·실제 시간·강의실 구문 확인 필요';parse_failed.append(cid)
 meetings=[]
 if not reason:
  current=date(2026,9,1)
  while current<=date(2026,12,7):
   if current.isoformat() not in holidays:
    for slot in slots:
     if current.isoweekday()==slot['weekday']:meetings.append({'date':current.isoformat(),**slot})
   current+=timedelta(days=1)
 reasons[reason or 'published reservation']+=1
 note='공개 주간 예약 계획, 실제 운영/날짜 미확인. 9월 4일 최신 종합강의시간표의 학수번호·수업 시간·강의실을 보존했습니다. 숫자 분반은 별도 기재되지 않아 학수번호를 임의로 분리하지 않았습니다. 9월 15일 2차 폐강 목록을 대조했습니다. '
 note+=('개강 9월 1일부터 시험 전 12월 7일까지 학교 공휴일을 제외한 예약 계획입니다. 12월 8~14일 시험 및 15~21일 보강의 실제 운영은 확인 전까지 보류합니다.' if meetings else '일정 보류: '+reason+'.')
 visible={k:r[k] for k in ['학년','이수영역','교시유형','수업구분','수업유형','집중이수제','성적평가','원어강의','원어강의구분','수강대상','수업방법'] if r[k]}
 note+=' 공개 조건: '+'; '.join(k+': '+v for k,v in visible.items())
 c={'sourceId':'inu/main/2026-2/'+cid,'campus':'main','academicYear':2026,'semester':'2','courseCode':cid,'courseName':r['교과목명'],'section':'','professor':r['담당교수'],'classification':r['이수구분'],'departmentClassifications':{r['학과(부)']:r['이수구분']},'credits':float(r['학점']) if r['학점'] else None,'departmentCredits':{r['학과(부)']:float(r['학점'])} if r['학점'] else {},'departments':[r['학과(부)']],'departmentRemarks':{r['학과(부)']:note},'sourceSchedule':r['시간표(시간)'],'sourceClassroom':r['강의실'],'scheduleStatus':'scheduled' if meetings else 'unrecognized','schedules':meetings,'sourceEducation':{'nativeCourseId':cid,'numericSectionIndividuallyPrinted':False,'nativePublicCells':r,'physicalCampusIndividuallyPrinted':False,'sourceModePublished':False,'operatingReviewComplete':False,'closureChecked':True,'closed':cid in closed_ids,'holdReason':reason,'allMeetingsIndividuallyPrinted':False,'dateBasis':'Current published weekly reservation plus own official calendar; actual attendance unknown'}}
 if meetings:c['period']={'startDate':'2026-09-01','endDate':'2026-12-07'}
 courses.append(c)
out={'schemaVersion':2,'universityId':'inu','campus':'main','campusName':'본교','institutionId':'institution:academyinfo:0002660','academicYear':2026,'semester':'2','publishedDate':'2026-09-04','sourceUrl':source['noticeUrl'],'candidateRevision':'whole2437-partial-dated-v1','wholeSchoolCourseCoverageComplete':False,'wholeSourceAcquired':True,'wholeOperatingVerified':False,'completionClaim':False,'campusScopeBasis':'Institution main scope only; native rooms retained, physical campus not guessed','courses':courses}
sha=save('inu-main-2026-2.whole2437-partial-dated-v1.json',out)
audit={'candidateSHA256':sha,'nativeRows':len(courses),'scheduledCourses':sum(bool(c['schedules']) for c in courses),'datedSlots':sum(len(c['schedules']) for c in courses),'heldCourses':sum(not c['schedules'] for c in courses),'closureRows':len(closed),'closureOverlap':len(closed_ids&{c['courseCode'] for c in courses}),'reasonCounts':dict(reasons),'parseFailedIds':parse_failed,'excludedHolidays':holidays,'completionClaim':False}
save('inu-current-partial-v1-audit.json',audit);print(audit)
