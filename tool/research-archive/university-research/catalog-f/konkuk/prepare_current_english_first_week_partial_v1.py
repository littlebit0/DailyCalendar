"""Research only: original publicly published current educational PDF cells.
Does not access blocked sites, login or modify product assets.
"""
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
import pdfplumber
ROOT=Path('work/university-research/catalog-f/konkuk')
PDF=Path('/private/tmp/daily-konkuk-fall2026-english-public.pdf')
CLOCK=Path('/private/tmp/daily-konkuk-public-timetable.jpg')
GUIDE=Path('/private/tmp/daily-konkuk-public-guide-course.html')
MEIJI=Path('/private/tmp/daily-konkuk-meiji-original-public-provenance.pdf')
URL='https://drive.google.com/uc?id=1MKqaEHbVzJo1l9SMM0UDTzmXab06ddrW&export=download'
PAGE='https://sites.google.com/view/ku-student-guidebook/course-registration'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(n,x): (ROOT/n).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
fields=['nativeRowNumber','nativeCourseNumber','nativeTitle','nativeCredits','nativeOfferedBy','nativeSchedule','nativeProfessor','nativeMethod','nativeNote']
rows=[]
with pdfplumber.open(PDF) as pdf:
 assert len(pdf.pages)==3
 assert 'FALL 2026 COURSES OFFERED IN ENGLISH' in pdf.pages[0].extract_text()
 for n,page in enumerate(pdf.pages,1):
  for t in page.extract_tables():
   for cells in t:
    if len(cells)!=9 or not re.fullmatch(r'\d+',cells[0] or ''): continue
    row=dict(zip(fields,[v or '' for v in cells]))
    row.update(nativePage=n,referenceKind='internalDocumentLocator',sourceId=f'https://drive.google.com/file/d/1MKqaEHbVzJo1l9SMM0UDTzmXab06ddrW/view#page={n}&row={cells[0]}')
    rows.append(row)
assert [int(r['nativeRowNumber']) for r in rows]==list(range(1,207))
assert len(set(r['nativeCourseNumber'] for r in rows))==206
# Direct visually inspected image rows, without extrapolating unpublished21.
clock=[{'nativeTimeslot':f'{i:02}','nativeBegins':f'{(540+(i-1)*30)//60:02}:{(540+(i-1)*30)%60:02}','nativeEnds':f'{(570+(i-1)*30)//60:02}:{(570+(i-1)*30)%60:02}'} for i in range(1,21)]
calendar=json.loads(Path('work/university-research/calendar-a/konkuk-seoul-events2026.json').read_text())
notes=('공개 주간 예약 계획, 실제 운영/날짜 미확인. 현재2026 Fall 영어 강의표206개 범위이며 중앙 전체 강좌·폐강 대조는 미확인입니다. '
'정상 공개 안내서의 직접 Drive 게시 문서로 차단된 건국대 페이지의 우회나 프록시 사본이 아닙니다. '
'4자리 Course No.는 공개 안내서가 실제 수강신청 과목번호로 설명하는 값이며 학수번호·분반의 별도 정의는 미공개입니다. 분반·이수구분은 빈 값입니다. '
'내부 원문 문서 위치 식별자는 수강신청 분반번호가 아닙니다. 교수/학점/교실/요일교시/제약/Method는 원문을 보존합니다. '
'교시 시각은 동일 안내서의 실제 Timeslot01~20 표만 사용하며21은 미공개입니다. Hybrid/Recorded는 대면일 비율 및 개별 운영일 미확인으로 보류합니다. '
'캠퍼스의 전체 강의실별 물리 mapping은 미확인으로 unknown입니다. 자체 서울2026 달력의8월31일 개강을 대조하고 첫 주8월31일~9월4일만 주간 예약 후보입니다. '
'학기 종강은 원문 미공개로 termEndDate를 만들지 않았으며12월19일 동계방학/12월14~18일 기말고사를 종강으로 대체하지 않습니다. '
'개별 강의 실제 첫 수업일·휴강/보강·시험 시각·강좌 폐강 및 추가 수강제약은 미확인입니다. 자료 기준일2026-10-08은 직접 수집일이며 게시일은 미공개입니다. 사용자 강의방식3종을 원문 Method로 덮어쓰지 않습니다. ')
weekdays={'MON':1,'TUE':2,'WED':3,'THR':4,'FRI':5}
restrictions={'*1':'Only for majoring students','*2':'Non-majoring students can register during the 2nd round of Manual Registration','*3':'Prerequisite applied, please contact professor for the requirements'}
courses=[]
held=[]
for r in rows:
 raw=' '.join(r['nativeSchedule'].split())
 matches=list(re.finditer(r'(MON|TUE|WED|THR|FRI)(\d{2})-(\d{2})\(([^()]*)\)',raw))
 residue=re.sub(r'(MON|TUE|WED|THR|FRI)(\d{2})-(\d{2})\(([^()]*)\)','',raw).replace(',','').strip()
 reasons=[]
 if r['nativeMethod']!='In Person': reasons.append('mixedOrRecordedActualDatesUnpublished')
 if not matches or residue: reasons.append('nativeScheduleNotCompletelyRecognized')
 if any(int(m[2])<1 or int(m[3])>20 or int(m[3])<int(m[2]) for m in matches): reasons.append('nativeTimeslotOutsidePublished01To20')
 meetings=[]
 if not reasons:
  for m in matches:
   weekday=weekdays[m[1]]
   date=(dt.date(2026,8,31)+dt.timedelta(days=weekday-1)).isoformat()
   a=clock[int(m[2])-1]['nativeBegins'];b=clock[int(m[3])-1]['nativeEnds']
   minute=lambda s:int(s[:2])*60+int(s[3:])
   meetings.append({'date':date,'weekday':weekday,'startMinute':minute(a),'endMinute':minute(b),'classroom':m[4]})
 else: held.append({'sourceId':r['sourceId'],'nativeCourseNumber':r['nativeCourseNumber'],'nativeTitle':r['nativeTitle'],'reasons':reasons})
 dept=' '.join(r['nativeOfferedBy'].split())
 note=notes+'원문 Method: '+r['nativeMethod']+'; 원문 비고: '+r['nativeNote']+' '+restrictions.get(r['nativeNote'],'')
 c={'sourceId':r['sourceId'],'referenceKind':'internalDocumentLocator','academicYear':2026,'semester':'2','campus':'unknown','courseCode':r['nativeCourseNumber'],'courseName':' '.join(r['nativeTitle'].split()),'section':'','professor':' '.join(r['nativeProfessor'].split()),'credits':float(r['nativeCredits']),'classification':'','departments':[dept],'departmentClassifications':{},'departmentCredits':{},'departmentRemarks':{dept:note},'sourceSchedule':raw,'sourceClassroom':', '.join(m[4] for m in matches),'period':{'startDate':'2026-08-31','endDate':'2026-09-04'} if meetings else None,'scheduleStatus':'scheduled' if meetings else 'unrecognized','schedules':meetings,'notes':note,'rawCurrentEducation':r}
 courses.append(c)
source={'researchOnly':True,'completionClaim':False,'impossibleClaim':False,'retrievalDate':'2026-10-08','sourcePublicationDateUnpublished':True,'currentNativeHeading':'FALL 2026 COURSES OFFERED IN ENGLISH','nativeCaution':'Course list is subject to change without notice','sourceUrl':URL,'parentPublicationUrl':PAGE,'pdfSourceSha256':sha(PDF),'pdfPageCount':3,'publicationLinks':{'actualPublishedPDFDownload':URL,'actualPublishedClockDownload':'https://drive.google.com/uc?id=17Imsia0YAQwF7dvofBeMJDafC7mddz_X&export=download','guideOriginalSha256':sha(GUIDE)},'officialIndependentPublicationProvenance':[{'sourceUrl':'https://www.meiji.ac.jp/cip/recruitment/qfki0t000003dd9x-att/201027.pdf','sourceSha256':sha(MEIJI),'nativeStatement':'This information is provided by each partner university at the time of publication of the application guidelines.','nativeEducationLink':'https://sites.google.com/view/ku-student-guidebook/home?authuser=0','nativeCourseListLink':'https://sj21kr.notion.site/KONKUK-UNIVERSITY-PROMOTIONAL-DOCUMENTS-LINKS-979fdda9f78143629204b269d09f5780','meaning':'Independent original partner publication verifies university-provided guidebook; historical course/date details are not borrowed.'}], 'courseNumberMeaning':{'nativeGuideText':'find and take note of all the course numbers for your courses (4-digit number) using the List of Courses Taught in English','nativeFAQText':'4-digit Course number for each course in 과목번호','sectionDefinitionUnpublished':True},'undergraduateScopeProof':{'nativeCurrentPDFHeaders':['COLLEGE OF BUSINESS','SANG-HUH COLLEGE'],'nativeCurrentDepartmentColumnsPreserved':True,'explicitGraduateRows':0,'scopeMeaning':'Current exchange English course list offers undergraduate college and department courses; no graduate-school rows acquired. Not all undergraduate university courses.'},'nativeClockImage':{'sourceSha256':sha(CLOCK),'rows':clock,'timeslot21Unpublished':True,'currentScope':'Same current course registration page embeds this Timeslot image beside FALL2026 PDF; image publication year itself unpublished.'},'calendar':{'sourceUrl':'https://www.konkuk.ac.kr/konkuk/2161/subview.do','savedNativeSource':'work/university-research/calendar-a/konkuk-year.html','savedNativeSourceSha256':sha(Path('work/university-research/calendar-a/konkuk-year.html')),'priorAcquisitionDate':'2026-10-07','protectedWebsiteNotRefetched':True,'nativeEvents':calendar,'termStartDate':'2026-08-31','termEndDate':None,'firstWeekCandidateBoundary':'2026-08-31/2026-09-04','candidateBoundaryMeaning':'Conservative initial public weekly reservation window; not directly published per-course actual date.'},'nativeRestrictionDefinitions':restrictions,'nativeCourseRows':rows,'heldCourses':held,'privacyBoundary':'Only education table cells, clocks and provenance retained. No contact/private/student/session/auth fields.','closureBoundary':'Guide instructs checking Cancelled Classes after login. Login not attempted; current full closure verification remains unknown.'}
source['courseNumberMeaning']['faqSourceUrl']='https://sites.google.com/view/ku-student-guidebook/course-registration/course-registration-faq'
source['courseNumberMeaning']['faqOriginalSha256']=sha(Path('/private/tmp/daily-konkuk-public-course-faq.html'))
source['otherCurrentPublicReceipts']=[{'sourceUrl':'https://sites.google.com/view/ku-student-guidebook/academic-calendar','sourceSha256':sha(Path('/private/tmp/daily-konkuk-public-guide-calendar.html')),'nativeEmbeddedTitle':'2025 Academic calendar','usedForCurrent2026Dates':False},{'sourceUrl':'https://sj21kr.notion.site/KONKUK-UNIVERSITY-PROMOTIONAL-DOCUMENTS-LINKS-979fdda9f78143629204b269d09f5780','sourceSha256':sha(Path('/private/tmp/daily-konkuk-original-notion-public.html')),'normalHTTP':200,'bodyKind':'clientRenderedPublicAppShell','educationDocumentLinksRecovered':False,'hiddenAPIRequests':False}]
landing=Path('work/university-research/calendar-a/konkuk-landing.html')
body=landing.read_text()
college=re.search(r'<ul[^>]*id="top_k2wiz_GNB_ul_2066"[^>]*>(.*?)</ul>',body,re.S).group(1)
collegeLinks=[]
for attrs,label in re.findall(r'<a\b([^>]*)>(.*?)</a>',college,re.S):
 href=re.search(r'href="([^"]+)"',attrs).group(1)
 name=' '.join(re.sub(r'<[^>]+>','',label).split())
 collegeLinks.append({'nativeLabel':name,'nativePublicHref':href})
source['undergraduateScopeProof']['ownCollegeNavigation']={'savedOfficialSource':'work/university-research/calendar-a/konkuk-landing.html','sourceSha256':sha(landing),'nativeParentLabel':'대학','nativeSeparateGraduateParentLabel':'대학원','nativeCollegeLinks':collegeLinks,'nativeSanghuhLabel':'상허교양대학 / KU자유전공학부','meaning':'Own public university navigation separates colleges including Sanghuh, business, engineering etc from graduate schools; current offered-by college/department cells preserved independently. Source retrieval reused, blocked host not retried.'}
source['protectedBoundary']='Known blocked first-party homepage/registration/biomed sources not re-requested; no alternate first-party host, proxy, custom headers, security bypass or login used.'
save('konkuk-current-public-english-education-source-20261008.json',source)
ds={'schemaVersion':2,'universityId':'konkuk','institutionId':'institution:academyinfo:0000052','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','sourceUrl':PAGE,'sourceUrls':[URL],'candidateRevision':'current-public-english-first-week-partial-v1','publishedDate':'2026-10-08','publishedDateMeaning':'sourceSnapshotRetrievalDate','sourcePublicationDateUnpublished':True,'termStartDate':'2026-08-31','termEndDate':None,'completionClaim':False,'courses':courses,'researchMetadata':{'nativeCourses':len(courses),'scheduledCourses':sum(bool(c['schedules']) for c in courses),'datedMeetings':sum(len(c['schedules']) for c in courses),'heldCourses':len(held),'wholeUniversityCoverageClaim':False,'currentClosuresComplete':False}}
save('konkuk-unknown-2026-2.current-public-english-first-week-partial-v1.json',ds)
print(ds['researchMetadata'])
