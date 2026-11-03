"""Current normal public undergraduate education; never cross authentication/WAF boundary."""
from pathlib import Path
from datetime import date,timedelta
import hashlib,html,io,json,re,urllib.request
import pdfplumber
ROOT=Path(__file__).resolve().parent
def fetch(u):return urllib.request.urlopen(u,timeout=35).read()
def sha(b):return hashlib.sha256(b).hexdigest()
def save(n,v):
 p=ROOT/n;p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n');return sha(p.read_bytes())
def text(v):return html.unescape(re.sub('<[^>]+>','',v)).strip()
def tables(s):return [[[text(c) for c in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>',r,re.S)] for r in re.findall(r'<tr\b.*?</tr>',t,re.S)] for t in re.findall(r'<table\b.*?</table>',s,re.S)]
def receipt(u,heading,columns,selector):
 b=fetch(u);s=b.decode();assert heading in text(s)
 t=next(t for t in tables(s) if selector(t[0]));rows=[]
 for r in t[1:]:
  if not r or not re.fullmatch(r'\d{4}',r[0]):continue
  rows.append({k:r[i] for k,i in columns.items()})
 return {'sourceUrl':u,'sourceSHA256':sha(b),'nativeHeading':heading,'educationRows':rows,'staffNumbersSaved':False,'enrollmentCountsSaved':False,'rawBodySaved':False}
ta=receipt('https://sw.kau.ac.kr/pages/notice.php?code=s1401&mode=read&seq=841','2026학년도 2학기 [TA인턴쉽] 수강생 모집 안내',{'nativeLectureNumber':0,'classification':1,'nativeCourseCode':2,'courseName':3,'grade':4,'nativeTeachingHours':5,'professor':6,'department':7,'nativeSchedule':8,'remark':9},lambda h:'학수코드' in h)
assert len(ta['educationRows'])==22;ta.update({'publishedDate':'2026-07-23','nativeTableContext':'4. 인턴쉽 교과목','scope':'Current undergraduate courses eligible for TA assignment. Preserve only printed course times; entire course weekly meeting coverage is not verified. TA인턴쉽II/IV themselves are separate courses and not misidentified with these rows.','teachingHoursAreNotCredits':True})
save('kau-current-ta-undergraduate-education-20261008.json',ta)
latest=receipt('https://sw.kau.ac.kr/pages/notice.php?code=s1401&mode=read&seq=845','2026학년도 2학기 수강 인원 증원 안내',{'nativeLectureNumber':0,'courseName':1,'nativeSchedule':2,'professor':3,'remark':6},lambda h:'강의시간' in h)
assert len(latest['educationRows'])==3;latest['publishedDate']='2026-08-13';save('kau-current-sw-later-clock-20261008.json',latest)
other=receipt('https://sse.kau.ac.kr/pages/notice.php?code=s1401&mode=read&seq=26','2026-2학기 2차 전공과목(전선/전필) 수강인원 증원 안내',{'grade':0,'nativeLectureNumber':1,'courseName':2,'professor':3},lambda h:'과목번호' in h)
# First column is grade, so reconstruct exact native positions with its own explicit header.
b=fetch(other['sourceUrl']);tab=next(t for t in tables(b.decode()) if '과목번호' in t[0]);other['educationRows']=[{'grade':r[0],'nativeLectureNumber':r[1],'courseName':r[2],'professor':r[3]} for r in tab[1:] if re.fullmatch(r'\d{4}',r[1])]
assert len(other['educationRows'])==17;save('kau-current-electronics-education-20261008.json',other)
pred_url='https://kau.ac.kr/upfile/2026/09/04/20260904145026-6848.pdf';b=fetch(pred_url);pred=[]
keys={'nativeLectureNumber':0,'classification':1,'nativeCourseCode':2,'courseName':3,'credits':4,'grade':5,'nativeTeachingHours':6,'professor':8,'nativeCourseType':10,'nativeSchedule':11,'classroom':12,'department':13}
with pdfplumber.open(io.BytesIO(b)) as doc:
 for page in doc.pages:
  for tab in page.extract_tables():
   for row in tab:
    if row[0] and re.fullmatch(r'\d{4}',row[0]):pred.append({k:row[i] or '' for k,i in keys.items()})
assert len(pred)==43
predicted={'sourceUrl':pred_url,'sourceSHA256':sha(b),'noticeUrl':'https://kau.ac.kr/kaulife/acdnoti.php?mode=read&seq=11145','publishedDate':'2026-09-04','nativeHeading':'2026학년도 2학기 폐강 예상 과목 현황(260904 11시 30분 기준)','educationRows':pred,'isFinalClosure':False,'staffNumbersSaved':False,'enrollmentCountsSaved':False,'rawBodySaved':False}
save('kau-current-predicted-closure-education-20261008.json',predicted)
final_url='https://kau.ac.kr/kaulife/acdnoti.php?mode=read&seq=11155';b=fetch(final_url);s=b.decode();assert '[2026학년도 2학기] 폐강 교과목 공고' in text(s)
image_url=html.unescape(re.search(r'<img src="([^"]+gohanway[^\"]+)"',s)[1])
# Explicitly public embedded education image, ordinary request already returned403. No repeat or bypass.
save('kau-current-final-closure-boundary-20261008.json',{'sourceUrl':final_url,'sourceSHA256':sha(b),'nativeHeading':'[2026학년도 2학기] 폐강 교과목 공고','publishedDate':'2026-09-08','observedEmbeddedEducationImageUrl':image_url,'normalEmbeddedImageRequestStatus':403,'nativeFinalClosedIdsVerified':False,'privateOrAuthenticationRequestsMade':False,'rawBodySaved':False})
cal_url='https://kau.ac.kr/kaulife/schedule.php';b=fetch(cal_url);native_table=next(t for t in re.findall(r'<table\b.*?</table>',b.decode(),re.S) if '2학기 학사일정' in t);tab=tables(native_table)[0];events=[]
for row in tab:
 if len(row)>1:
  # A rowspanned month column changes native length, date/event stay the last two cells.
  ds,label=row[-2:]
  if ds.startswith(('2026.','2027.')):events.append({'nativeDates':ds,'label':label})
assert any(r['label']=='개강' and '9. 1' in r['nativeDates'] for r in events)
assert any(r['label']=='2학기 보강' and '12.21' in r['nativeDates'] for r in events)
calendar={'sourceUrl':cal_url,'sourceSHA256':sha(b),'nativeHeading':'2학기 학사일정','sourceEvents':events,'startDate':'2026-09-01','finalExamStartDate':'2026-12-08','finalExamEndDate':'2026-12-14','makeupStartDate':'2026-12-15','makeupEndDate':'2026-12-21','academicOperatingEndDate':'2026-12-21','endBoundaryBasis':'Direct published 2학기 보강 end; not invented ordinary lecture end or independently printed vacation start.','ordinaryReservationEndDate':'2026-12-07','excludedHolidays':['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'],'midtermDatesIndividuallyPublished':False,'rawBodySaved':False}
save('kau-current-calendar-20261008.json',calendar)
by_id={}
for r in ta['educationRows']:by_id[r['nativeLectureNumber']]={'education':dict(r),'sourceKind':'taUndergraduateTable','sourceUrl':ta['sourceUrl'],'sourceNativeRows':[r]}
for r in latest['educationRows']:
 id=r['nativeLectureNumber']
 if id in by_id:
  by_id[id]['sourceNativeRows'].append(r)
  by_id[id]['laterSourceUrl']=latest['sourceUrl']
  by_id[id]['education']['nativeSchedule']=r['nativeSchedule']
  if id=='0595':by_id[id]['clockConflict']=True
 else:by_id[id]={'education':dict(r),'sourceKind':'currentClockIncreaseTable','sourceUrl':latest['sourceUrl'],'sourceNativeRows':[r]}
for r in other['educationRows']:
 id=r['nativeLectureNumber'];assert id not in by_id;by_id[id]={'education':dict(r),'sourceKind':'electronicsIncreaseTable','sourceUrl':other['sourceUrl'],'sourceNativeRows':[r]}
for r in pred:
 id=r['nativeLectureNumber'];assert id not in by_id;by_id[id]={'education':dict(r),'sourceKind':'predictedClosureTable','sourceUrl':pred_url,'sourceNativeRows':[r],'predictedClosure':True}
courses=[];conflicts=[]
for id,item in by_id.items():
 r=item['education'];native=r.get('nativeSchedule','');conflict=item.get('clockConflict',False);pending=item.get('predictedClosure',False);meetings=[]
 if conflict:conflicts.append(id)
 if native and not conflict and not pending:
  blocks=[]
  # Explicit weekday / HH:mm blocks, preserving exact source durations (not inferred teaching hours).
  pat=r'([월화수목금토일](?:/[월화수목금토일])*)\s*\)?\s*(\d{1,2}):(\d{2})\s*[~∼]\s*(\d{1,2}):(\d{2})'
  for m in re.finditer(pat,native):
   st=int(m[2])*60+int(m[3]);en=int(m[4])*60+int(m[5]);assert en>st
   for day in m[1].split('/'):blocks.append(('월화수목금토일'.index(day)+1,st,en))
  assert blocks,(id,native)
  day=date(2026,9,1)
  while day<=date(2026,12,7):
   ds=day.isoformat()
   if ds not in calendar['excludedHolidays']:
    for wd,st,en in blocks:
     if day.isoweekday()==wd:meetings.append({'date':ds,'weekday':wd,'startMinute':st,'endMinute':en,'classroom':r.get('classroom','')})
   day+=timedelta(days=1)
 dept=r.get('department','소프트웨어학과' if item['sourceKind']=='currentClockIncreaseTable' else '');credits=float(r['credits']) if r.get('credits') else None
 note='현재 학부 공개 교육 원문의 실제 과목번호·학수코드를 보존했습니다. 별도 숫자 분반 및 미게재 강의실은 빈 값입니다. 강의시수는 학점으로 가정하지 않았습니다. 확정 폐강 공고의 교육 이미지는 정상공개 요청403으로 실제 확정 폐강 대조 미완료입니다.'
 if meetings:note+=' 공개 주간 예약 계획, 실제 운영/날짜 미확인. 공개된 요일·정확시각만 9월1일~12월7일 예약하며 공휴일을 제외합니다. 기말시험12월8~14일과 보강12월15~21일 실제 일정, 중간시험과 추후 변경은 미확인입니다.'
 if item['sourceKind']=='taUndergraduateTable':note+=' TA 인턴쉽 모집 공지의 인턴쉽 대상 학부 교과목 시간 표입니다. 각 과목의 전체 주간 회의/교실 운영을 확인한 시간표는 아니며 미게재 시간을 추가하지 않았습니다.'
 if pending:note+=' 9월4일 폐강 예상 목록입니다. 확정 폐강과 동일시하지 않고 실제 후속 상태 미확인으로 모든 일정 보류.'
 if conflict:note+=' 과목번호0595의 TA 대상 표12:00~13:30와 후속8월13일 증원 표12:00~12:30가 상충합니다. 원문을 오타로 고치지 않고 일정 보류.'
 if item['sourceKind']=='electronicsIncreaseTable':note+=' 공지 제목의 전공과목(전선/전필)만 보존하며 각 행의 전필/전선·개설전공·학수코드·시각은 미공개입니다.'
 if r.get('remark'):note+=' 원문 비고: '+r['remark']
 c={'sourceId':f'kau/main/2026-2/{id}','campus':'main','academicYear':2026,'semester':'2','courseCode':r.get('nativeCourseCode',''),'courseName':r['courseName'],'section':'','professor':r.get('professor',''),'classification':r.get('classification','전공과목(전선/전필)' if item['sourceKind']=='electronicsIncreaseTable' else ''),'departmentClassifications':({dept:r['classification']} if r.get('classification') else {}),'credits':credits,'departmentCredits':({dept:credits} if credits is not None else {}),'departments':([dept] if dept else []),'departmentRemarks':{dept:note},'sourceSchedule':native,'sourceClassroom':r.get('classroom',''),'scheduleStatus':'scheduled' if meetings else 'unrecognized','schedules':meetings,'sourceEducation':{'referenceKind':'nativeLectureNumber','nativeLectureNumber':id,'sourceKind':item['sourceKind'],'sourceUrl':item['sourceUrl'],'laterSourceUrl':item.get('laterSourceUrl'),'nativeEducationRows':item['sourceNativeRows'],'numericSectionIndividuallyPrinted':False,'physicalCampusIndividuallyProven':False,'campusScope':'본교 기관 범위만, 실제 강좌별 물리 캠퍼스 미확인','clockConflictHeld':conflict,'predictedClosureHeld':pending,'finalNativeClosureCheckComplete':False,'entireWeeklyMeetingCoverageVerified':False,'actualOperatingVerified':False}}
 if meetings:c['period']={'startDate':'2026-09-01','endDate':'2026-12-07'}
 courses.append(c)
assert len(courses)==83 and sum(bool(c['schedules']) for c in courses)==22
out={'schemaVersion':2,'universityId':'kau','campus':'main','campusName':'본교','institutionId':'institution:academyinfo:0000194','academicYear':2026,'semester':'2','publishedDate':'2026-09-04','sourceUrl':ta['sourceUrl'],'candidateRevision':'public83-partial-v1','wholeSchoolCourseCoverageComplete':False,'wholeOperatingVerified':False,'completionClaim':False,'courses':courses}
n='kau-main-2026-2.public83-partial-v1.json';h=save(n,out)
audit={'file':n,'SHA256':h,'nativeCourses':83,'nativeSourceIdsUnique':len(by_id),'scheduledCourses':22,'datedSlots':sum(len(c['schedules']) for c in courses),'heldCourses':61,'clockConflictNativeIds':conflicts,'predictedClosureCoursesHeld':43,'actualFinalClosureNativeCompared':False,'sectionInvented':False,'unknownCourseCodeInvented':False,'creditFromTeachingHoursGuessed':False,'classroomInvented':False,'oldSemesterOrGraduateRowsUsed':False,'authWafQueueBypassed':False,'staffNumbersSaved':False,'enrollmentCountsSaved':False,'completionClaim':False}
save('kau-current-public83-partial-v1-audit.json',audit);print(audit)
