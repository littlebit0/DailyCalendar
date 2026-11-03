"""Build a held-public-snapshot candidate; source IDs are native registration references."""
import collections,datetime,hashlib,json,re
from pathlib import Path
D=Path(__file__).parent/'daegu-current-20261008'
def read(f):return json.loads((D/f).read_text())
def write(f,d):(D/f).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
by=collections.defaultdict(list)
for r in read('educational-source-offerings.json'):by[r['nativeRegistrationNumber']].append(r)
closed={r['education']['수강번호']for r in read('closure-educational-rows.json')}|{'1316','2210'}
special=set(read('special-operation-registration-numbers.json'))
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
courses=[];holds=[];clock=re.compile(r'([월화수목금토일])\((\d{2}):(\d{2})-(\d{2}):(\d{2})\)')
for code,src in sorted(by.items()):
 if code in closed:continue
 e=src[0]['education'];fields={k:sorted({x['education'].get(k,'')for x in src})for k in ['교과목명','강의시간','강의실','담당교수','학점','구분']}
 conflicts={k:v for k,v in fields.items()if len({re.sub(r'\s+','',x)for x in v})>1 and k!='구분'}
 cats=[x for x in fields['구분']if x];cat=cats[0]if len(cats)==1 else ''
 reasons=[]
 if conflicts:reasons.append('published duplicate native reference has conflicting '+','.join(conflicts))
 if code in special or any(re.search('집중|블렌디드|가상|MOOC|원격|실습기간',str(x['education']))for x in src):reasons.append('special/remote/blended operation dates or mode unresolved; native snapshot clock is not assumed actual teaching')
 if code=='2204':reasons.append('September3 notice cancels first September week and states Tuesday change as 예정; final operation unconfirmed')
 if any(re.search('친족상속법|가족법',x['education']['교과목명'])for x in src):reasons.append('September3 room change is published by course title; native reference join not established')
 source=e.get('강의시간','');room=e.get('강의실','');blocks=[]
 for m in clock.finditer(source):
  a=int(m[2])*60+int(m[3]);b=int(m[4])*60+int(m[5]);assert 0<=a<b<=1440
  blocks.append({'weekday':'월화수목금토일'.index(m[1])+1,'startMinute':a,'endMinute':b,'classroom':room})
 remainder=clock.sub('',source).strip(' ,/')
 if remainder:reasons.append('native weekly clock notation unrecognized: '+remainder)
 if not blocks:reasons.append('source publishes no fixed weekly clock')
 if not room:reasons.append('source classroom absent')
 if any('\n'in str(x['sourceCells'][list(x['education']).index('강의실')])for x in src) or any(ch in room for ch in [',','/']):reasons.append('room contains multiple lines/places without meeting-specific mapping')
 meetings=[]
 if not reasons:
  for i in range(98):
   d=datetime.date(2026,9,1)+datetime.timedelta(days=i)
   if str(d)in holidays:continue
   for b in blocks:
    if b['weekday']==d.isoweekday():meetings.append({**b,'date':str(d)})
 if reasons:holds.append({'nativeRegistrationNumber':code,'reasons':reasons,'sourceConflicts':conflicts})
 depts=sorted({x['education'].get('수강학과','')for x in src}-{''});depcredit={};depclass={};depremarks={}
 for dept in depts:
  rows=[x['education']for x in src if x['education'].get('수강학과')==dept]
  cr={x.get('학점','')for x in rows};cl={x.get('구분','')for x in rows}-{''}
  if len(cr)==1:
   try:depcredit[dept]=float(next(iter(cr)))
   except ValueError:pass
  if len(cl)==1:depclass[dept]=next(iter(cl))
  depremarks[dept]='수강학과 원문: '+dept+'; '+ '; '.join(sorted({x.get('비고','')for x in rows}-{''}))
 remark='학교 공개 수업시간표의 수강번호입니다. 별도 교과목코드 및 분반은 공개되지 않았습니다. 공개 정규 수업 계획이며 실제 출석·개별 휴강 확정이 아닙니다. 휴일 자율보강 및 12/8~12/14 기말 운영은 강좌별 확인이 필요하여 일정에 포함하지 않았습니다. TIGERS 실시간 변경 전체는 검증되지 않았습니다.'
 if reasons:remark+=' 일정 미생성: '+'; '.join(reasons)
 remark+=' 수강 대상: '+', '.join(depts)+'; 원문 비고: '+'; '.join(sorted({x['education'].get('비고','')for x in src}-{''}))
 depremarks={dept:remark+'\n'+value for dept,value in depremarks.items()}
 try:credits=float(fields['학점'][0])if len(fields['학점'])==1 else None
 except ValueError:credits=None
 courses.append({'sourceId':'daegu-2026-2-registration-'+code,'referenceKind':'수강번호','canonicalSubjectCodePublished':False,'nativeSectionPublished':False,'campus':'main','campusEvidence':'academyinfo:0000084 본교 institution scope; comprehensive timetable has no per-offering campus selector, no inferred room location','academicYear':2026,'semester':'2','courseCode':code,'courseName':e['교과목명'],'courseNameAliases':fields['교과목명'],'section':'','professor':e.get('담당교수','')if '담당교수'not in conflicts else '','credits':credits,'classification':cat,'sourceClassificationAliases':cats,'departments':depts,'departmentCredits':depcredit,'departmentClassifications':depclass,'departmentRemarks':depremarks,'remarks':remark,'sourceSchedule':source,'sourceClassroom':room,'sourceScheduleAliases':fields['강의시간'],'sourceClassroomAliases':fields['강의실'],'scheduleStatus':'scheduled'if meetings else'unrecognized','period':{'startDate':'2026-09-01','endDate':'2026-12-14'},'schedules':meetings,'sourceSnapshotSchedules':blocks,'publicEducationRows':src,'datesMeaning':'published ordinary regular teaching through December7, without autonomous makeups or exams; attendance unconfirmed'})
f='daegu-main-2026-2.published-partial-20261008.json';write(f,{'schemaVersion':2,'universityId':'daegu','campus':'main','campusName':'본교','academicYear':2026,'semester':'2','publishedDate':'2026-07-27','sourceUrl':'https://rst.daegu.ac.kr/article/table_01/detail/224014','courses':courses})
audit={'completionClaim':False,'candidate':{'file':f,'sha256':hashlib.sha256((D/f).read_bytes()).hexdigest()},'uniqueSourceIdentityCount':len(by),'closedNativeReferenceCount':len(closed),'closedStillPresent':sorted({x['courseCode']for x in courses}&closed),'candidateClasses':len(courses),'scheduledClasses':sum(bool(c['schedules'])for c in courses),'datedMeetings':sum(len(c['schedules'])for c in courses),'holds':holds,'excludedHolidays':sorted(holidays),'regularTeachingEnd':'2026-12-07','semester':['2026-09-01','2026-12-14'],'datesProof':'comprehensive PDF page2 Sept1 opening, Dec8–14 final examinations, Dec15 winter vacation; holidays marked autonomous makeup so no fixed replacement date inferred','unverified':['full TIGERS current timetable changes','canonical subject code and separate native section not published','per-offering physical campus','special course actual operation dates/modes','autonomous makeups and final exams','all 68 duplicate source field differences pending review'],'productionChanged':False}
write('candidate-audit.json',audit);print(json.dumps({k:v for k,v in audit.items()if k in ['candidateClasses','scheduledClasses','datedMeetings','closedNativeReferenceCount','closedStillPresent']},ensure_ascii=False))
