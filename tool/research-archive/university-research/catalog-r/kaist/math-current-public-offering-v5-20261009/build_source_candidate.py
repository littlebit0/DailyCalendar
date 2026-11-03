import json,hashlib,datetime,copy
from pathlib import Path
P=Path(__file__).parent
save=lambda n,d:(P/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
base=Path('assets/timetable/kaist-main-2026-2.json'); prior=json.loads(base.read_text()); assert len(prior['courses'])==23
save('prior-full-23-course-baseline.json',prior)
cal=Path('work/university-research/catalog-r/kaist/nqe-current-ug-v2-20261009/current-calendar-campus-proof.json'); calendar=json.loads(cal.read_text());save('reused-own-current-calendar-proof.json',calendar)
rows=[
('270','','논리 및 집합','최서영','산경1225','E2 1225','09:00','10:15','MW'),
('411','','대수기하학개론','박진형','자연3435','E6 3435','09:00','10:15','TT'),
('321','','미분기하학개론','최서영','산경1225','E2 1225','10:30','11:45','MW'),
('430','','조합적 위상수학','김우진','산경1223','E2 1223','10:30','11:45','MW'),
('250','A','확률및통계','박철우','창의304','E11 304','10:30','11:45','TT'),
('242','','해석학Ⅱ','임미경','창의303','E11 303','10:30','11:45','TT'),
('456','','컴퓨터 통계방법론','전현호','산경1225','E2 1225','10:30','11:45','TT'),
('250','B','확률및통계','하우석','창의304','E11 304','13:00','14:15','MW'),
('365','','수치해석학개론','이창옥','산경1225','E2 1225','13:00','14:15','MW'),
('441','','르베그적분론','권순식','자연3435','E6 3435','13:00','14:15','TT'),
('355','','수리통계학','김일문','창의412','E11 412','14:30','15:45','MW'),
('477','','그래프이론 개론','김재훈','자연3435','E6 3435','14:30','15:45','MW'),
('312','','현대대수학Ⅱ','백상훈','창의301','E11 301','14:30','15:45','TT')]
# Directly reviewed bilingual UG cells; original full PDF and whole extracted text retained.
eng=[('Logic and Set Theory','Suhyoung CHOI'),('Introduction to Algebraic Geometry','Jinhyung PARK'),('Introduction to Differential Geometry','Suhyoung CHOI'),('Combinatorial Topology','Woojin KIM'),('Probability and Statistics','Cheolwoo PARK'),('Analysis II','Mikyoung LIM'),('Statistical Methods with Computer','Hyonho CHUN'),('Probability and Statistics','Wooseok HA'),('Introduction to Numerical Analysis','Chang-Ock LEE'),('Lebesgue Integral Theory','Soonsik KWON'),('Mathematical Statistics','Ilmun KIM'),('Introduction to Graph Theory','Jaehoon KIM'),('Modern Algebra II','Sanghoon BAEK')]
proof={'sourceUrl':'https://mathsci.kaist.ac.kr/home/en/education/timetable/','actualLinkedPdfUrl':'https://mathsci.kaist.ac.kr/ko/education/tt_files/185_2.pdf','sourcePDFSHA256':sha(P/'actual-2026-fall-timetable.pdf'),'sourcePrintedDate':'2026-09-30','menuUpdatedDate':'2026-10-01','nativeCurrentTerm':'2026 Fall / 2026학년도 가을학기','UGScopeRule':'Both actual pages explicitly label each included horizontal band 학부 / Under-graduate; no numeric threshold or colour inference','nativeHeaderOrder':['Mon','Tue','Wed','Thu','Fri'],'campusProof':'Actual current math menu footer: KAIST, 291 Daehak-ro Yuseong-gu Daejeon34141 SouthKorea','shortCodePublishedFullOfficialCodeUnknown':True,'wholeExtractedEducationalTextFile':'actual-timetable-text.txt','rows':[],'completionClaim':False}
out=copy.deepcopy(prior);out['researchOnly']=True;out['completionClaim']=False
for i,r in enumerate(rows):
 code,section,title,prof,room,roomEN,start,end,days=r
 original=dict(zip(['nativeShortCode','nativeSection','nativeTitleKR','nativeProfessorKR','nativeClassroomKR','nativeClassroomEN','nativeStartClock','nativeEndClock','nativeDayPair'],r)); original.update(nativeTitleEN=eng[i][0],nativeProfessorEN=eng[i][1],nativeUGLabels=['학부','Under-graduate'],nativeCurrentOfferingCreditsPublished=False,nativeIndividualMajorClassificationPublished=False,rawWholeEducationalFieldsFile='actual-timetable-text.txt')
 proof['rows'].append(original)
 mins=lambda hh:sum(int(v)*k for v,k in zip(hh.split(':'),(60,1)))
 dates=[];day=datetime.date(2026,8,31)
 while day<=datetime.date(2026,12,13):
  ds=day.isoformat(); week=[1,3] if days=='MW' else [2,4]
  if day.isoweekday() in week and ds not in calendar['holidayExclusion'] and not ('2026-10-19'<=ds<='2026-10-23'):
   dates.append({'weekday':day.isoweekday(),'startMinute':mins(start),'endMinute':mins(end),'classroom':room,'date':ds})
  day+=datetime.timedelta(days=1)
 assert len(dates)==27
 out['courses'].append({'sourceId':f'kaist/main/2026-2/math-185_2/{code}/{section or "unpublished"}','campus':'main','academicYear':2026,'semester':'2','courseCode':code,'courseName':title,'section':section,'professor':prof,'classification':'','credits':None,'departmentCredits':{},'departments':['수리과학과'],'departmentClassifications':{},'sourceSchedule':f'{days} {start}~{end} [{room}]','sourceClassroom':room,'scheduleStatus':'scheduled','schedules':dates,'period':{'startDate':'2026-08-31','endDate':'2026-12-18'},'remarks':'공개 예약 계획. 원문 학부 표시와 단축 과목코드 보존; 전체 공식 과목코드·학점·개별 이수구분 미공개. 자체 학사일정 중간·기말고사 및 휴일을 제외한 일반 예약이며 실제 출석·폐강·시험·보강 미확인.','metadata':{'researchOnly':False,'completionClaim':False,'sourceUrl':proof['actualLinkedPdfUrl'],'publishedDate':'2026-09-30','sourceUpdatedDate':'2026-10-01','sourcePDFSHA256':proof['sourcePDFSHA256'],'sourceIdKind':'Internal PDF/native-shortcode/actual-section locator, not official full offering ID','originalEducationalFields':original,'nativeShortCodePublished':True,'fullOfficialOfferingCodeUnverified':True,'actualAttendanceConfirmed':False,'currentActiveStatusVerified':False,'deliveryModeStatus':'unknown-user-choice','ownCalendarSHA256':sha(cal),'campusEvidence':proof['campusProof'],'regularReservationEndDerivedFromNextFinalStart':True}})
assert out['courses'][:23]==prior['courses'];assert len(out['courses'])==36; assert sum(len(c['schedules']) for c in out['courses'])==940
out['researchRevision']='math-public-single-section-v5-source-only';save('kaist-main-2026-2.math-single-ug-planned-v5.json',out);save('manual-bilingual-current-ug-proof.json',proof)
# Independent literal calendar sets and source HH, separate from candidate iteration algorithm.
mw='2026-08-31 2026-09-02 2026-09-07 2026-09-09 2026-09-14 2026-09-16 2026-09-21 2026-09-23 2026-09-28 2026-09-30 2026-10-07 2026-10-12 2026-10-14 2026-10-26 2026-10-28 2026-11-02 2026-11-04 2026-11-09 2026-11-11 2026-11-16 2026-11-18 2026-11-23 2026-11-25 2026-11-30 2026-12-02 2026-12-07 2026-12-09'
tt='2026-09-01 2026-09-03 2026-09-08 2026-09-10 2026-09-15 2026-09-17 2026-09-22 2026-09-29 2026-10-01 2026-10-06 2026-10-08 2026-10-13 2026-10-15 2026-10-27 2026-10-29 2026-11-03 2026-11-05 2026-11-10 2026-11-12 2026-11-17 2026-11-19 2026-11-24 2026-11-26 2026-12-01 2026-12-03 2026-12-08 2026-12-10'
for c,r in zip(out['courses'][23:],rows): assert [s['date'] for s in c['schedules']]==(mw if r[-1]=='MW' else tt).split()
save('independent-python-validation.json',{'result':'PASS','priorWhole23ObjectsPreserved':True,'addedCourses':13,'addedDates':351,'totalCourses':36,'totalDates':940,'sourcePDFSHA256':proof['sourcePDFSHA256'],'ownCalendarActualSHA256':sha(cal),'SDKExecuted':False,'wholeUniversitySupportClaim':False})
