"""Unambiguous current-semester published grid blocks; no enrollment identifier invention."""
from pathlib import Path
from datetime import date,timedelta
import hashlib,json,re,urllib.parse
import openpyxl
ROOT=Path(__file__).resolve().parent;OLD=ROOT.parent.parent/'catalog-g'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(n,o):
 p=ROOT/n;p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n');return sha(p)
source='https://www.ginue.ac.kr/kor/ajx_json/UploadMgr/downloadRun.do?qcode=Qm9hcmQsNzgxOTcsWQ=='
notice='https://www.ginue.ac.kr/kor/CMS/Board/Board.do?mCode=MN125&mode=view&mgr_seq=89&board_seq=46686'
xlsx=OLD/'ginue2026-2-sixth.xlsx';wb=openpyxl.load_workbook(xlsx,data_only=True);fixture=json.loads((OLD/'ginue2026-2-grid-cell-fixture.json').read_text())
cal={'sourceUrl':'https://www.ginue.ac.kr/kor/CMS/ScheduleMgr/YearList.do?mCode=MN058','sourceMechanism':'Official web tool content, crawled6days earlier; shell live request today returned194byte blank HTML','sourceNativeEntries':[{'dates':'2026-08-31','label':'제2학기 개강일'},{'dates':'2026-09-01','label':'제2학기 개시일'},{'dates':'2026-09-24~2026-09-26','label':'추석 연휴'},{'dates':'2026-09-30~2026-10-01','label':'대동제'},{'dates':'2026-10-05','label':'개천절 대체공휴일'},{'dates':'2026-10-09','label':'한글날'},{'dates':'2026-10-12~2026-10-16','label':'가정학습주간(1주)'},{'dates':'2026-10-12~2026-10-30','label':'3학년 수업실습(3주)(3주 자체보강)'},{'dates':'2026-11-20','label':'2027학년도 수시모집 면접평가'},{'dates':'2026-12-14~2026-12-18','label':'기말고사'},{'dates':'2026-12-18','label':'제2학기 종강'}],'startDate':'2026-08-31','endDate':'2026-12-18','ordinaryReservationEndDate':'2026-12-13','sourceClockScope':'Published timetable hour cell reservation boundaries, not verified instructional minutes excluding breaks','liveFileFreshnessVerified':False,'closureNativeCompared':False,'publishedCampusNames':['인천캠퍼스','경기캠퍼스'],'rawBodySaved':False}
# Current guide corroborates exact opening/end, ignoring stale HWP retained revision text.
guide=(OLD/'ginue2026-2-guide.txt').read_text();assert '개 강 일: 2026. 8. 31.(월) [종강일: 12. 18.(금)]' in guide
cal['guideCorroboration']={'sourceFile':'../catalog-g/ginue2026-2-guide.hwp','sourceSHA256':sha(OLD/'ginue2026-2-guide.hwp'),'nativeCurrentSentence':'개 강 일: 2026. 8. 31.(월) [종강일: 12. 18.(금)]','stale2017RetainedRevisionTextNotUsed':True}
save('ginue-current-calendar-and-boundary-20261008.json',cal)
education=[];courses=[];skipped=[]
for sh,v in fixture['sheets'].items():
 ws=wb[sh];grade=v['grade'];campus='incheon' if v['campus']=='인천' else 'gyeonggi'
 for c in v['cells']:
  rg=c.get('mergedRange');parts=[p.strip() for p in c['rawText'].splitlines() if p.strip()]
  if not rg or not re.fullmatch(r'([A-Z]+)\d+:\1\d+',rg):continue
  room_indexes=[i for i,s in enumerate(parts) if re.fullmatch(r'(?:인|전|예|음|자|체)(?:\(경\))?(?:B)?\d{3}(?:\([A-Za-z]\))?',s)]
  if len(room_indexes)!=1:continue
  j=room_indexes[0]
  if any(re.match(r'(?:인|전|예|음|자|체)(?:\(경\))?(?:B)?\d{3}',x) for x in parts[:j]):continue
  if j<1 or len(parts[j+1:])!=1 or not re.fullmatch(r'[가-힣]{2,5}',parts[-1]) or any(w in c['rawText'] for w in ['원격','온라인','ROTC']):continue
  native=ws[c['cell']].value;assert native==c['rawText']
  merge=next(str(r) for r in ws.merged_cells.ranges if str(r)==rg);assert merge==rg
  clocks=c['mergedRowClocks'];assert all(x['weekday']==clocks[0]['weekday'] for x in clocks)
  for clock in clocks:
   rr=next(int(k) for k,x in v['clockRows'].items() if x==clock)
   native_clock=ws.cell(rr,2).value;assert f"{clock['start']}~{clock['end']}" in native_clock
  start=int(clocks[0]['start'][:2])*60+int(clocks[0]['start'][3:]);end=int(clocks[-1]['end'][:2])*60+int(clocks[-1]['end'][3:]);weekday='월화수목금토일'.index(clocks[0]['weekday'])+1
  title=''.join(parts[:j]);room=parts[j];teacher=parts[-1];group=c['columnHeader'];assert ws.cell(2,ws[c['cell']].column).value==group
  # Preserve independently explicit section11 only where current notice teacher/title/time match.
  section='11' if grade==4 and c['cell']=='M9' and title=='교육행정과학교경영' and teacher=='구자원' and clocks[0]['period']==7 and clocks[-1]['period']==9 else ''
  source_id=source+'#sheet='+urllib.parse.quote(sh,safe='')+'&cell='+c['cell']
  raw={'sourceId':source_id,'sheet':sh,'grade':grade,'campusNative':v['campus'],'cell':c['cell'],'mergedRange':rg,'nativeCellText':native,'nativeColumnHeader':group,'nativeTitleLineParts':parts[:j],'courseName':title,'professor':teacher,'classroom':room,'clockRows':clocks,'startMinute':start,'endMinute':end,'weekday':weekday,'section':section,'numericSectionBasis':('Current notice8/28 item1 explicitly教育행정과학교경영11반/구자원/月7-9; exact native M9:M11 agrees' if section else 'Column header 반/학과 is student-group scope, not assumed registration section')}
  education.append(raw)
  meetings=[];d=date(2026,8,31)
  while d<=date(2026,12,13):
   ds=d.isoformat();held=ds in ['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'] or '2026-10-12'<=ds<='2026-10-16' or (grade==3 and '2026-10-12'<=ds<='2026-10-30')
   # Festival/interview entries are not explicit no-class instructions: preserve source frames with unverified operation note.
   if d.isoweekday()==weekday and not held:meetings.append({'date':ds,'weekday':weekday,'startMinute':start,'endMinute':end,'classroom':room})
   d+=timedelta(days=1)
  note='공개 주간 예약 계획, 실제 운영/날짜 미확인. 내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다. 교과목코드·학점·이수구분은 이 시간표에 미공개로 빈 값/미확인입니다. 반·학과 열은 학생 집단 범위이며 명시된 개별 분반 증거 외에는 숫자 분반을 생성하지 않았습니다. 시간표의 60분 시각 칸 경계를 예약 범위로 보존했으며 휴게시간/실제 강의분수는 별도 미확인입니다. 현재2026-2 6차 시간표 원문을 보존했으나 오늘 공식 재요청은 빈 페이지여서 최신 변경/폐강 대조 미완료입니다. 가정학습10월12~16일과 기말고사12월14~18일은 예약 제외, 자체보강 실제 일정은 미확인입니다. 대동제9월30~10월1일 및 면접11월20일의 강좌별 실제 운영은 미확인입니다.'
  if grade==3:note+=' 3학년 수업실습10월12~30일 및3주 자체보강은 현재 학사일정 근거로 예약 제외합니다.'
  if section:note+=' 현재 공지의 교육행정과학교경영11반/구자원/월7~9교시 명시와 원문 셀 일치로 분반11만 보존했습니다.'
  courses.append({'sourceId':source_id,'referenceKind':'internalDocumentLocator','campus':campus,'academicYear':2026,'semester':'2','courseCode':'','courseName':title,'section':section,'professor':teacher,'classification':'','departmentClassifications':{},'credits':None,'departmentCredits':{},'departments':[group],'departmentRemarks':{group:note},'sourceSchedule':clocks[0]['weekday']+' '+clocks[0]['start']+'~'+clocks[-1]['end'],'sourceClassroom':room,'period':{'startDate':'2026-08-31','endDate':'2026-12-13'},'scheduleStatus':'scheduled','schedules':meetings,'sourceEducation':{'referenceKind':'internalDocumentLocator','nativePublicCells':raw,'courseCodeIndividuallyPrinted':False,'campusIndividuallyPrinted':True,'sourceStudentGroupIsNotOpeningDepartment':True,'wholeSchoolCourseCoverageComplete':False,'wholeOperatingVerified':False,'latestClosureCompared':False,'sourceDurationIsHourGridReservationBoundary':True}})
assert len(courses)==165
assert len({(c['campus'],c['courseName'],c['professor'],c['sourceClassroom'],c['sourceSchedule']) for c in courses})==165
save('ginue-current-unambiguous-merged-source-20261008.json',{'sourceUrl':source,'noticeUrl':notice,'sourceSHA256':sha(xlsx),'sourceFile':'../catalog-g/ginue2026-2-sixth.xlsx','nativeNoticeSHA256':sha(OLD/'ginue-current2026-2.html'),'nativeNoticePublishedDate':'2026-08-03','nativeNoticeCurrentChangesDate':'2026-08-28','sourceCellCountBeforeSemanticSelection':1057,'unambiguousVerticalMergedBlockCount':165,'educationRows':education,'todayLiveRequestsReturnedBlankHtml':True,'blankHtmlSHA256':'e089fd08e3faa8aa2fb0bf353287dfad6f722170ce6e5ae7fd7407ab170c4a20','sourceContactStaffStudentFieldsSaved':False})
files=[]
for campus,name in [('incheon','인천캠퍼스'),('gyeonggi','경기캠퍼스')]:
 cc=[c for c in courses if c['campus']==campus];out={'schemaVersion':2,'universityId':'ginue','campus':campus,'campusName':name,'institutionId':'institution:academyinfo:0000256','academicYear':2026,'semester':'2','publishedDate':'2026-08-28','sourceUrl':notice,'candidateRevision':'merged165-partial-v1','liveFileFreshnessVerified':False,'completionClaim':False,'courses':cc}
 n=f'ginue-{campus}-2026-2.merged165-partial-v1.json';h=save(n,out);files.append({'file':n,'SHA256':h,'courses':len(cc),'datedSlots':sum(len(c['schedules']) for c in cc)})
audit={'files':files,'courses':len(courses),'uniqueDocumentLocators':len({c['sourceId'] for c in courses}),'exactTitleTeacherRoomClockDuplicateCount':0,'datedSlots':sum(len(c['schedules']) for c in courses),'actualEnrollmentCodeInvented':False,'nativeCourseCreditsInvented':False,'sourceClockReplacedWithGuessed50Minutes':False,'latestFullSchoolClosureCompared':False,'wholeSchoolCompletionClaim':False,'sourceNativeIndependentXlsxCompared':True,'productionChanged':False};save('ginue-current-merged165-partial-v1-audit.json',audit);print(audit)
