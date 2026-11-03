"""Use current public native education rows and individually published chapel dates."""
from pathlib import Path
from datetime import date
import hashlib, html, json, re, urllib.parse, urllib.request
ROOT=Path(__file__).resolve().parent
OLD=ROOT.parent.parent/'catalog-l'
def sha(b): return hashlib.sha256(b).hexdigest()
def fetch(u): return urllib.request.urlopen(urllib.parse.quote(u,safe=':/?=&%'),timeout=45).read()
def save(n,v):
 p=ROOT/n; p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n'); return sha(p.read_bytes())
def text(v): return html.unescape(re.sub('<[^>]+>','',v)).strip()
def tables(s):
 return [[[text(c) for c in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>',r,re.S)] for r in re.findall(r'<tr\b.*?</tr>',t,re.S)] for t in re.findall(r'<table\b.*?</table>',s,re.S)]
chapel_url='https://www.syu.ac.kr/blog/2026학년도-2학기-채플-안내/'
b=fetch(chapel_url);s=b.decode();t=tables(s)[0]
program=[{'week':int(r[0]),'thirdYearWednesday':r[1],'secondYearMonday':r[2],'theme':r[3],'remark':r[4]} for r in t[2:]]
assert len(program)==15 and '대강당' in text(s)
# Notice directly excludes these separately operated programs; candidate match excludes them too.
excluded=['상담','신학','항공관광','글로벌한국','화학생명','물리치료']
for x in excluded: assert x in text(s)
chapel={'sourceUrl':chapel_url,'sourceSHA256':sha(b),'publishedDate':'2026-07-30','nativeHeading':'2026학년도 2학기 채플 안내','sourceProgram':program,'eligibleProgram':'정규 2학년 월3 / 3학년 수2 채플, 대강당','excludedSeparateDepartmentChapelTerms':excluded,'foreignChapelExcluded':True,'onlineRecognitionDatesConfirmed':False,'futureEclassChangesAccessed':False,'publishedPlanNotAttendanceProof':True,'rawBodySaved':False}
save('syu-current-chapel-program-20261008.json',chapel)
guide_url='https://www.syu.ac.kr/brochure/2026_guide_book/data/searchwords.json';b=fetch(guide_url);g=json.loads(b)[3]
assert g['id']=='page-c2eb-c1ae'
assert '11 : 00~11 : 50' in g['text'] and '10 : 00~10 : 50' in g['text']
clock={'sourceUrl':guide_url,'viewerUrl':'https://www.syu.ac.kr/brochure/2026_guide_book/index.html','sourceSHA256':sha(b),'nativeHeading':'2026학년도 삼육대학교 부서별 안내 가이드북 / 채플 수강 신청','pageIndex':3,'pageId':g['id'],'scope':'CHAPEL ONLY; not a university-wide period map','rows':[{'grade':'1학년','nativePeriod':'화요일 8교시','startMinute':960,'endMinute':1010,'remark':'학과별 채플 (공동체활동), 교차채플 선택 안됨'},{'grade':'2학년','nativePeriod':'월요일 3교시','startMinute':660,'endMinute':710,'remark':'교차채플가능'},{'grade':'3학년','nativePeriod':'수요일 2교시','startMinute':600,'endMinute':650,'remark':'교차채플가능'}],'sourceNativeWarning':'위 내용은 학사 운영에 따라 변경될 수 있음. 별도 채플을 운영하는 학과는 학과 사정에 따라 시간과 교차채플 가능 여부가 상이함.','staffAndContactsSaved':False,'rawBodySaved':False}
save('syu-current-chapel-clock-20261008.json',clock)
cal_url='https://www.syu.ac.kr/academic/major-schedule/';b=fetch(cal_url);s=b.decode();events=[]
assert '>2026학년도<' in s
for match in re.finditer(r'<dt\b[^>]*>([^<]*)</dt>\s*<dd\b[^>]*>([^<]*)</dd>',s,re.S):
 d,n=text(match[1]),text(match[2])
 if d.startswith(('09.','10.','11.','12.')) and {'nativeDates':d,'label':n} not in events: events.append({'nativeDates':d,'label':n})
assert {'nativeDates':'09.01','label':'개강'} in events
assert {'nativeDates':'12.08 ~ 12.14','label':'기말고사(15주차)'} in events
calendar={'sourceUrl':cal_url,'sourceSHA256':sha(b),'nativeHeading':'2026학년도 학사일정','secondSemesterEvents':events,'startDate':'2026-09-01','finalExamStartDate':'2026-12-08','finalExamEndDate':'2026-12-14','termEndDateIndividuallyPublished':False,'termBoundaryNote':'개강 9월1일 / 15주차 기말고사12월8~14일 직접 게재. 종강·방학 시작 날짜는 이 공개 표에서 별도 확인되지 않았으므로 독립 학기종료일을 발명하지 않음. 12월21일 동계계절학기 시작은 정규학기 종료 증거로 사용하지 않음.','rawBodySaved':False}
save('syu-current-calendar-20261008.json',calendar)
readme=(OLD/'README.md').read_text();pdf_url=re.search(r'https://www.syu.ac.kr/wp-admin/admin-ajax.php\?action=file_download_id&t_id=255002[^\s]+',readme)[0]
b=fetch(pdf_url);assert sha(b)==sha((OLD/'syu-2026-2-all-20260907.pdf').read_bytes())
current_pdf_sha=sha(b)
closure_receipts=[];closed=set()
for phrase,expected in [('1%ec%b0%a8-',82),('2%EC%B0%A8',24)]:
 url=next(u for u in re.findall(r'https://www.syu.ac.kr/blog/[^\s]+',readme) if phrase in u)
 b=fetch(url);ids=set()
 for tab in tables(b.decode()):
  for row in tab:
   for i in range(len(row)-1):
    if row[i].isdigit() and len(row[i])<7 and re.fullmatch(r'\d{7}',row[i+1]): ids.add(row[i])
 assert len(ids)==expected,(expected,len(ids))
 closed.update(ids);closure_receipts.append({'sourceUrl':url,'sourceSHA256':sha(b),'nativeClosedLectureIds':sorted(ids),'count':len(ids)})
a=json.loads((OLD/'syu-2026-2-closure-audit.json').read_text());assert closed==set(a['unionClosedIds']) and len(closed)==106
save('syu-current-cumulative-closure-20261008.json',{'sources':closure_receipts,'unionNativeClosedIds':sorted(closed),'unionCount':106,'latestRemainingClosedIds':['886'],'rawBodySaved':False})
raw=json.loads((OLD/'syu-2026-2-public-all-rows.json').read_text());assert len(raw)==1391
wed=['2026-09-09','2026-09-16','2026-09-23','2026-09-30','2026-11-04','2026-11-11','2026-11-25']
mon=['2026-09-14','2026-09-21','2026-09-28','2026-10-12','2026-11-09','2026-11-16','2026-11-30']
# Each kept date is individually printed in the current program. Explicit exceptions are held.
for ds in wed+mon:
 d=date.fromisoformat(ds);native=f'{d.month}.{d.day}.('
 assert any(native in r['thirdYearWednesday'] or native in r['secondYearMonday'] for r in program)
courses=[];sanitized=[];credit_held=[]
for original in raw:
 r=[v or '' for v in original]; removed=[]
 for i,v in enumerate(r):
  if '@' in v or re.search(r'(?<!\d)0\d{1,2}-\d',v):
   # Keep educational prefix, discard contact fragments including clipped phone strings.
   prefix=re.split(r'\(?\s*문의\s*:|(?<!\d)0\d{1,2}-\d|[\w.+-]+@',v,maxsplit=1)[0].rstrip(' (,:')
   r[i]=prefix;removed.append(i)
 if removed: sanitized.append({'nativeLectureNumber':r[0],'sanitizedCellIndexes':removed,'reason':'Public contact/partial telephone fragment omitted; educational prefix retained'})
 ident,dept,code,title=r[0],r[1],r[4],r[5]
 eligible=title=='채플' and code=='1004903' and r[11] in ['월3','수2'] and r[12]=='대강당(메인)' and not r[14] and ident not in closed and not any(x in dept for x in excluded)
 credits=float(r[8]) if re.fullmatch(r'\d+(?:\.\d+)?',r[8]) else None
 if credits is None:credit_held.append(ident)
 dates=(mon if r[11]=='월3' else wed) if eligible else []
 start=660 if r[11]=='월3' else 600
 meetings=[{'date':ds,'weekday':date.fromisoformat(ds).isoweekday(),'startMinute':start,'endMinute':start+50,'classroom':r[12]} for ds in dates]
 note='공개 교육 원문의 강좌번호·교과목코드 보존. 숫자 분반은 별도 미공개입니다. 공개 PDF 이후 실제 SU-WINGs 변경은 확인하지 않았습니다.'
 if eligible:note+=' 공개 날짜별 예약 계획, 실제 운영/출석 미확인. 현재 2026-2 채플 프로그램에 명시한 날짜와 2026 가이드북 채플 시각(50분)만 연결했습니다. 학과별·외국인 채플은 별도 운영으로 제외합니다. 9월2·7일 정정기간, 10월5일 대체휴일, 10월7일 체육대회, 온라인/e-Class 주차 및 중간·기말고사는 일정 보류하며 e-Class 인정 기간과 추후 변경은 미확인입니다.'
 else:note+=' 전체 대학 교시 시각 미확인 또는 별도 운영/온라인/원문 잘림으로 일정 보류. 채플 시각을 일반 교과목에 적용하지 않았습니다.'
 if ident in closed:note+=' 현재 1차+최종 폐강 공고 실제 강좌번호 일치: 폐강. 일정 제외.'
 if credits is None:note+=' 원문 학점 셀에 다른 열 글자가 겹쳐 숫자 판독 보류.'
 if r[14]:note+=' 원문 교육 비고: '+r[14]
 if removed:note+=' 공개 연락처/잘린 전화번호 조각은 보관하지 않았습니다.'
 c={'sourceId':f'syu/main/2026-2/{ident}','campus':'main','academicYear':2026,'semester':'2','courseCode':code,'courseName':title,'section':'','professor':r[10],'classification':r[6],'departmentClassifications':{dept:r[6]},'credits':credits,'departmentCredits':({dept:credits} if credits is not None else {}),'departments':[dept],'departmentRemarks':{dept:note},'sourceSchedule':r[11],'sourceClassroom':r[12],'scheduleStatus':'scheduled' if eligible else 'unrecognized','schedules':meetings,'sourceEducation':{'referenceKind':'nativeLectureNumber','nativeLectureNumber':ident,'nativeSectionPublished':False,'nativePublicCells':r,'contactCellIndexesOmitted':removed,'closed':ident in closed,'currentNativeClosureCompared':True,'chapelEligibleProgramMatched':eligible,'individualCampusProof':False,'campusScope':'본교 기관 범위; 강좌별 물리 캠퍼스 증거는 별도 확인되지 않음','wholeUniversityClockConfirmed':False,'individuallyPublishedDates':eligible,'actualOperatingVerified':False}}
 if eligible:c['period']={'startDate':dates[0],'endDate':dates[-1]}
 courses.append(c)
assert len({c['sourceId'] for c in courses})==1391 and sum(bool(c['schedules']) for c in courses)==38 and sum(len(c['schedules']) for c in courses)==266
out={'schemaVersion':2,'universityId':'syu','campus':'main','campusName':'본교','institutionId':'institution:academyinfo:0000116','academicYear':2026,'semester':'2','publishedDate':'2026-09-07','sourceUrl':pdf_url,'candidateRevision':'native1391-chapel-partial-v1','sourceSHA256':current_pdf_sha,'nativeEducationRowsAcquired':1391,'wholeSchoolCourseCoverageComplete':False,'wholeOperatingVerified':False,'completionClaim':False,'courses':courses}
n='syu-main-2026-2.native1391-chapel-partial-v1.json';h=save(n,out)
audit={'file':n,'SHA256':h,'nativeCourseRows':1391,'uniqueNativeLectureNumbers':1391,'nativeCourseCodes':len({r[4] for r in raw}),'scheduledCourses':38,'individuallyDatedSlots':266,'heldCourses':1353,'closureUnion':106,'currentNativeClosedOverlap':['886'],'contactSanitization':sanitized,'unparsedCreditRows':len(credit_held),'unparsedCreditNativeIds':credit_held,'oldJulyRowsUsed':False,'clippedRoomsOrTimesGuessed':False,'sectionInvented':False,'generalClockExtrapolatedFromChapel':False,'completionClaim':False}
save('syu-current-partial-v1-audit.json',audit);print(json.dumps({k:v for k,v in audit.items() if k not in ['unparsedCreditNativeIds','contactSanitization']},ensure_ascii=False))
