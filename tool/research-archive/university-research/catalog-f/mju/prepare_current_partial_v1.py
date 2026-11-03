"""Only public education cells; preserve source identities and hold unknown operations."""
from pathlib import Path
from datetime import date,timedelta
from copy import deepcopy
import io,json,re,hashlib,urllib.request,importlib.util
import pdfplumber
ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[3]
def fetch(url):return urllib.request.urlopen(url,timeout=45).read()
def save(name,obj):
 p=ROOT/name;p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n');return hashlib.sha256(p.read_bytes()).hexdigest()
def pdf_rows(body):
 out=[]
 with pdfplumber.open(io.BytesIO(body)) as doc:
  for page in doc.pages:
   for table in page.extract_tables():out.extend(table)
 return out
closure_url='https://www.mju.ac.kr/bbs/mjukr/143/180492/download.do';b=fetch(closure_url)
closures=[{'campus':r[1],'nativeLectureNumber':r[2],'courseName':r[3],'college':r[4],'department':r[5],'status':r[8],'remark':r[9]} for r in pdf_rows(b) if r[0] and r[0].isdigit()]
assert len(closures)==136
save('mju-current-final-closure-education-20261008.json',{'sourceUrl':closure_url,'sourceSHA256':hashlib.sha256(b).hexdigest(),'publishedDate':'2026-09-09','nativeHeading':'2026-2학기 최종폐강 강좌 내역','includesFirstClosureRows':any(r['remark']=='1차폐강' for r in closures),'closedCourses':closures,'staffNumbersSaved':False,'rawBodySaved':False})
closed_ids={(r['campus'],r['nativeLectureNumber']) for r in closures}
handbook='https://www.mju.ac.kr/bbs/mjukr/1725/181030/download.do';b=fetch(handbook)
s=importlib.util.spec_from_file_location('hwp',REPO/'work/university-research/catalog-g/read_skku_published_office_plan.py');h=importlib.util.module_from_spec(s);s.loader.exec_module(h);t=h.hwp_text(b)
assert '[학부·대학원] 학기 개시일, 2학기 개강' in t and 'S1xxx' in t
holiday=['2026-09-07','2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09']
calendar={'sourceUrl':handbook,'sourceSHA256':hashlib.sha256(b).hexdigest(),'version':'v1.14','nativeHeading':'2026학년도 제2학기 강의시간표 안내문 / 학사 제도 안내 자료','startDate':'2026-09-01','midtermStartDate':'2026-10-20','midtermEndDate':'2026-10-26','finalExamStartDate':'2026-12-08','finalExamEndDate':'2026-12-14','holidayMakeupStartDate':'2026-12-15','holidayMakeupEndDate':'2026-12-18','termEndDate':'2026-12-18','termEndBasis':'Published holiday makeup/exam period end; source vacation starts Dec15, so this is academic operating-end boundary, not invented per-course attendance','reservationEndDate':'2026-12-07','excludedHolidays':holiday,'holidayMakeupMandatory':True,'nativeRoomTableHeading':'[참고표 2] 수업시간표 및 강의실 안내','campusRoomMap':{'인문캠퍼스':{'S1xxx':'본관','S3xxx':'별관','S4xxx':'경상관','S5xxx':'행정동','S9xxx':'방목학술정보관','S10xxx':'MCC'}},'wholeCurrentSectionTimetableFound':False,'guideScopeProof':{'nativeIntro':'◆ 학사 제도 안내 자료 ◆','nativeCourseCodeTableColumns':['캠퍼스','구분','단과대학','학부ㆍ학과ㆍ전공','교과목코드','교과목명','학점','개설학기','비고'],'scope':'Curriculum/requirements/inventory and general period map, no actual current whole section meeting timetable. 강좌번호 occurs only in enrollment guidance and blank absence form. No course-by-course lecturer/weekday/room current whole table found.'},'rawBodySaved':False}
save('mju-current-calendar-room-guide-20261008.json',calendar)
notice='https://www.mju.ac.kr/bbs/gsca/433/234331/artclView.do';notice_body=fetch(notice);assert '미술사학과 학부, 일반대학원 강의 시간표.xlsx' in notice_body.decode()
arturl='https://www.mju.ac.kr/bbs/gsca/433/179498/download.do';b=fetch(arturl)
s=importlib.util.spec_from_file_location('xlsx',REPO/'work/university-research/catalog-f/inu/collect_current_public_education.py');x=importlib.util.module_from_spec(s);s.loader.exec_module(x);rows=x.educational_rows(b)
assert rows[0]['A']=="2026학년도 2학기 '학부 전공' 강좌배정 신청서"
arts=[]
for r in rows:
 if r.get('B')=='미술사학과':
  arts.append({'sourceRow':len(arts)+5,'department':r['B'],'courseName':r['C'],'credits':int(r['D']),'professor':r['F'],'nativeWeekdays':r['G'],'nativeStartTime':r['H'],'nativeEndTime':r['I'],'classroom':r['J'],'remark':r.get('K','')})
assert len(arts)==7
assert all(a['classroom']=='S1915' for a in arts)
assert not {a['courseName'] for a in arts}&{r['courseName'] for r in closures}
save('mju-current-art-undergraduate-education-20261008.json',{'noticeUrl':notice,'noticeSHA256':hashlib.sha256(notice_body).hexdigest(),'publishedDate':'2026-08-10','modifiedDate':'2026-09-03','sourceUrl':arturl,'sourceSHA256':hashlib.sha256(b).hexdigest(),'nativeSheet':'전공','nativeHeading':rows[0]['A'],'educationRows':arts,'excludedSheet':'대학원','excludedSheetHeading':"2026학년도2학기 '대학원' 강좌배정 신청서",'nativeCourseCodePublished':False,'nativeLectureNumberPublished':False,'nativeSectionPublished':False,'referenceKind':'internalDocumentLocator','rawBodySaved':False})
courses=[]
for r in arts:
 start=int(r['nativeStartTime'][:2])*60+int(r['nativeStartTime'][2:]);end=int(r['nativeEndTime'][:2])*60+int(r['nativeEndTime'][2:]);assert end-start==75
 days=['월화수목금토일'.index(d)+1 for d in r['nativeWeekdays'].split('/')]
 meetings=[];current=date(2026,9,1)
 while current<=date(2026,12,7):
  ds=current.isoformat()
  if current.isoweekday() in days and ds not in holiday and not '2026-10-20'<=ds<='2026-10-26':meetings.append({'date':ds,'weekday':current.isoweekday(),'startMinute':start,'endMinute':end,'classroom':r['classroom']})
  current+=timedelta(days=1)
 note='공개 주간 예약 계획, 실제 운영/날짜 미확인. 학부 전공 강좌배정 신청서의 75분 시간과 강의실을 보존했습니다. 과목코드·강좌번호·분반은 이 표에 미공개입니다. 내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다. 개강 9월 1일부터 12월 7일까지 공휴일·개교기념일과 중간고사(10월 20~26일)를 제외한 예약 계획입니다. 기말고사(12월 8~14일)와 의무 보강(12월 15~18일) 실제 운영은 보류합니다. 최종 폐강 표와 정확한 과목명은 겹치지 않지만 강좌번호 미공개로 개별 폐강 상태 확인에는 한계가 있습니다.'
 if r['remark']:note+=' 원문 비고: '+r['remark']
 courses.append({'sourceId':arturl+'#sheet=%EC%A0%84%EA%B3%B5&cell=C'+str(r['sourceRow']),'referenceKind':'internalDocumentLocator','campus':'humanities','academicYear':2026,'semester':'2','courseCode':'','courseName':r['courseName'],'section':'','professor':r['professor'],'classification':'학부 전공','departmentClassifications':{'미술사학과':'학부 전공'},'credits':r['credits'],'departmentCredits':{'미술사학과':r['credits']},'departments':['미술사학과'],'departmentRemarks':{'미술사학과':note},'sourceSchedule':r['nativeWeekdays']+' '+r['nativeStartTime']+'-'+r['nativeEndTime'],'sourceClassroom':r['classroom'],'scheduleStatus':'scheduled','schedules':meetings,'period':{'startDate':'2026-09-01','endDate':'2026-12-07'},'sourceEducation':{'referenceKind':'internalDocumentLocator','nativeCourseCodePublished':False,'nativeLectureNumberPublished':False,'nativeSectionPublished':False,'nativePublicCells':r,'publicCampusRoomJoin':'Current guide 인문캠퍼스 S1xxx=본관; source S1915','numericSectionIndividuallyPrinted':False,'operatingReviewComplete':False,'allMeetingsIndividuallyPrinted':False,'closureNativeIdentityConfirmed':False}})
online_url='https://www.mju.ac.kr/bbs/mjukr/143/179821/download.do';b=fetch(online_url);raw=pdf_rows(b);remote=[]
keys=['academicYear','semester','nativeLectureNumber','nativeCourseCode','courseName','publishedClosureFlag','courseType','NPType','excludedEnrollmentCount','internetType','professor','campus','college','department','nativeTimeAccount','commonClassFlag','weekday1','nativeTime1','classroom1','weekday2','nativeTime2','classroom2','remark']
for row in raw:
 if row[0]!='2026':continue
 r={k:(v or '').replace('\n','') for k,v in zip(keys,row) if k!='excludedEnrollmentCount'};remote.append(r)
assert len(remote)==93 and len({(r['campus'],r['nativeLectureNumber']) for r in remote})==93
save('mju-current-online-education-20261008.json',{'noticeUrl':'https://www.mju.ac.kr/bbs/mjukr/143/234634/artclView.do','sourceUrl':online_url,'sourceSHA256':hashlib.sha256(b).hexdigest(),'nativeColumns':[k for k in keys if k!='excludedEnrollmentCount'],'educationRows':remote,'nativeTimeAccountIsNotAssumedCredits':True,'actualOperatingMeetingsConfirmed':False,'rawBodySaved':False})
for r in remote:
 campus={'인문':'humanities','자연':'natural'}[r['campus']];closed=(r['campus'],r['nativeLectureNumber']) in closed_ids
 department=r['department'];note='현재 공개 온라인·블렌디드 교육 목록. 실제 주별 영상/대면 운영 날짜와 방식 미확인으로 일정 보류. 강좌번호: '+r['nativeLectureNumber']+'. 숫자 분반은 별도 미공개입니다. 시간계정은 학점으로 가정하지 않았습니다. 원문 수업 방식: '+r['internetType']+'. 원문 비고: '+r['remark']
 if closed:note+=' 2026년 9월 9일 최종 폐강 목록에서 실제 강좌번호 일치: 폐강.'
 courses.append({'sourceId':'mju/'+campus+'/2026-2/'+r['nativeLectureNumber'],'referenceKind':'nativeLectureNumber','campus':campus,'academicYear':2026,'semester':'2','courseCode':r['nativeCourseCode'],'courseName':r['courseName'],'section':'','professor':r['professor'],'classification':'강좌유형: '+r['courseType']+('; N/P유형: '+r['NPType'] if r['NPType'] else ''),'departmentClassifications':{},'credits':None,'departmentCredits':{},'departments':[department],'departmentRemarks':{department:note},'sourceSchedule':r['weekday1']+' '+r['nativeTime1']+'; '+r['weekday2']+' '+r['nativeTime2'],'sourceClassroom':r['classroom1']+'; '+r['classroom2'],'scheduleStatus':'unrecognized','schedules':[],'sourceEducation':{'referenceKind':'nativeLectureNumber','nativeLectureNumber':r['nativeLectureNumber'],'nativeCourseCodePublished':True,'nativeSectionPublished':False,'nativePublicCells':r,'sourceCampusIndividuallyPrinted':True,'closureNativeIdentityConfirmed':True,'closed':closed,'actualOperatingMeetingsConfirmed':False,'operatingReviewComplete':False}})
files=[]
for campus,name in [('humanities','인문캠퍼스'),('natural','자연캠퍼스')]:
 selected=[c for c in courses if c['campus']==campus]
 out={'schemaVersion':2,'universityId':'mju','campus':campus,'campusName':name,'institutionId':'institution:academyinfo:0000109','academicYear':2026,'semester':'2','publishedDate':'2026-09-03','sourceUrl':notice,'candidateRevision':'art-online-partial-v1','wholeSchoolCourseCoverageComplete':False,'wholeOperatingVerified':False,'completionClaim':False,'courses':selected}
 filename='mju-'+campus+'-2026-2.art-online-partial-v1.json';sha=save(filename,out);files.append({'file':filename,'SHA256':sha,'sourceCourses':len(selected),'scheduledCourses':sum(bool(c['schedules']) for c in selected),'datedSlots':sum(len(c['schedules']) for c in selected)})
audit={'files':files,'sourceCourses':len(courses),'artUndergraduateRows':7,'onlinePublicRows':93,'graduateRowsExcluded':True,'uniqueSourceIds':len({c['sourceId'] for c in courses}),'finalClosureRows':136,'nativeClosedOnlineOverlap':[r['nativeLectureNumber'] for r in remote if (r['campus'],r['nativeLectureNumber']) in closed_ids],'artNativeClosureCheckLimitedByMissingLectureNumber':True,'completionClaim':False}
save('mju-current-partial-v1-audit.json',audit);print(audit)
