"""Current single-title teacher-room blocks; mixed electives and unassigned staff held."""
from pathlib import Path
from datetime import date,timedelta
import json,re,hashlib,urllib.parse
import openpyxl
ROOT=Path(__file__).resolve().parent;OLD=ROOT.parent.parent/'catalog-k'
URL='https://www.bnue.ac.kr/file/download?fileKey=20260904144256-fcb6ea65918f4a548a02c238b63b9a76'
NOTICE='https://www.bnue.ac.kr/board/detail/community01_02/44428'
def save(n,x):
 p=ROOT/n;p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n');return hashlib.sha256(p.read_bytes()).hexdigest()
f=json.loads((OLD/'bnue-public-coordinate-fixture.json').read_text());wb=openpyxl.load_workbook(OLD/'bnue-2026-2-current.xlsx',data_only=True)
requests=json.loads((ROOT/'bnue-current-source-file-calendar-receipt-20261008.json').read_text());assert all(x['sameAsPreservedSource'] for x in requests if x['name'] in ['grid','electives'])
cal=json.loads((ROOT/'bnue-current-calendar-education-receipt-20261008.json').read_text())['educationalEvents']
assert any(x['startDate']=='2026-09-01' and x['nativeTitle']=='2학기 개강' for x in cal)
assert any(x['startDate']=='2026-12-14' and x['nativeTitle']=='2학기 종강일' for x in cal)
notice=(OLD/'bnue-current-schedule-notice.html').read_text();assert '9:00~9:50' in notice and '17:00~17:50' in notice
courses=[];rows=[]
for item in f['sheets']:
 sheet=wb[item['sheet']];grade=int(sheet.title[0]);assert sheet['A1'].value==f'2026학년도 2학기 {grade}학년 시간표'
 coordinates={x['coordinate']:x for x in item['cells']}
 for row in sheet.iter_rows(min_row=5,max_row=17,min_col=2,max_col=46):
  for cell in row:
   if not cell.value:continue
   text=str(cell.value);parts=[p.strip() for p in text.splitlines() if p.strip()];merged=next((m for m in sheet.merged_cells.ranges if m.min_row==cell.row and m.min_col==cell.column),None)
   if len(parts)!=3 or not re.fullmatch(r'[가-힣]{2,5}',parts[1]) or (merged and merged.min_row!=merged.max_row) or any(k in text for k in ['/','원격','온라인','팀티칭']):continue
   assert coordinates[cell.coordinate]['value']==text
   if merged:assert str(merged) in item['mergedRanges']
   last_column=merged.max_col if merged else cell.column;day=(cell.column-2)//9
   assert (last_column-2)//9==day
   first_period=(cell.column-2)%9+1;last_period=(last_column-2)%9+1
   assert int(sheet.cell(4,cell.column).value)==first_period and int(sheet.cell(4,last_column).value)==last_period
   start=(8+first_period)*60;end=(8+last_period)*60+50
   group=f'{grade}학년 '+str(sheet.cell(cell.row,1).value).strip()
   source_id=URL+'#sheet='+urllib.parse.quote(sheet.title,safe='')+'&cell='+cell.coordinate
   native_comments=[]
   for rr in range(merged.min_row if merged else cell.row,(merged.max_row if merged else cell.row)+1):
    for cc in range(merged.min_col if merged else cell.column,last_column+1):
     nc=sheet.cell(rr,cc)
     if nc.comment:native_comments.append({'cell':nc.coordinate,'text':nc.comment.text})
   unassigned=parts[1] in ['신규','신규교수','신규강사']
   native={'sourceId':source_id,'sheet':sheet.title,'grade':grade,'cell':cell.coordinate,'nativeCellText':text,'mergedRange':str(merged) if merged else None,'courseName':parts[0],'professor':parts[1],'classroom':parts[2],'studentGroup':group,'weekday':day+1,'firstPeriod':first_period,'lastPeriod':last_period,'startMinute':start,'endMinute':end,'nativeEducationalComments':native_comments,'professorUnassignedNativeLabel':unassigned,'status':'held' if unassigned else 'scheduled'}
   rows.append(native);meetings=[];d=date(2026,9,1)
   while d<=date(2026,12,7):
    ds=d.isoformat();hold=ds in ['2026-09-02','2026-09-24','2026-09-25','2026-10-05','2026-10-09'] or (grade==2 and '2026-10-12'<=ds<='2026-10-23') or (grade==3 and '2026-11-02'<=ds<='2026-11-13')
    if not unassigned and d.isoweekday()==day+1 and not hold:meetings.append({'date':ds,'weekday':day+1,'startMinute':start,'endMinute':end,'classroom':parts[2]})
    d+=timedelta(days=1)
   note='공개 주간 예약 계획, 실제 운영/날짜 미확인. 내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다. 교과목코드·개별분반·학점·이수구분은 이 블록에 미공개로 빈 값/미확인입니다. 과목명 괄호의 문자와 학년·심화과정은 원문 그대로 보존하며 별도 수강코드/분반으로 추론하지 않습니다. 현재9월4일 전체시간표 파일은 정상 공개 재조회 원문과 일치하나 최신 선택과목 폐강은 별도 공지 조건이고 전체 강좌 폐강 대조 미완료입니다. 강의실은 원문 그대로, 캠퍼스 물리 매핑은 미확인입니다. 현재 공지의50분 교시 시각을 보존하며 연속교시 내부 휴게시간은 포함될 수 있습니다. 자체9월1일 개강·12월14일 종강,12월8~14일 기말고사에 따라 예약은12월7일까지이며 추석9월24~26일·10월5일 대체공휴일·10월9일 한글날은 제외했습니다.9월2일 개교기념일은 보수적으로 보류하되 강좌별 실제 휴강 직접 확인은 미완료입니다. A과정(윤리·국어·사회·수학·교육·초등특수유아·영어)/B과정(과학·체육·음악·미술·실과·컴퓨터) 및 타과/타학년 선택이 아닌 과목 수강 제한은 현재 선택과목 공지의 학생 범위이며 캠퍼스가 아닙니다. 선택 혼합 블록과8월5일 선택과목 개별 분반/현재9월4일 실·시각 연결은 이번 후보에서 보류했습니다.'
   if grade==2:note+=' 자체2학년 교육실습Ⅱ10월12~23일은 예약 제외하며 보강 실제 날짜는 미확인입니다.'
   if grade==3:note+=' 자체3학년 교육실습Ⅳ11월2~13일은 예약 제외하며 보강 실제 날짜는 미확인입니다.'
   if native_comments:note+=' 원문 교육용 메모: '+' / '.join(x['text'] for x in native_comments)
   if unassigned:note+=' 원문 교수란의 신규/신규교수/신규강사는 실제 확정 교수명이 아니므로 원문 미배정 상태로 보존하고 날짜 변환을 보류했습니다.'
   courses.append({'sourceId':source_id,'referenceKind':'internalDocumentLocator','academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','courseName':parts[0],'section':'','professor':parts[1],'credits':None,'classification':'','departments':[group],'departmentClassifications':{},'departmentCredits':{},'departmentRemarks':{group:note},'sourceSchedule':'월화수목금'[day]+f' {8+first_period:02}:00~{8+last_period:02}:50','sourceClassroom':parts[2],'period':{'startDate':'2026-09-01','endDate':'2026-12-07'} if not unassigned else None,'scheduleStatus':'unrecognized' if unassigned else 'scheduled','schedules':meetings,'sourceEducation':{'nativePublicBlock':native,'referenceKind':'internalDocumentLocator','wholeSchoolCompletionClaim':False,'campusPhysicalProof':False,'latestWholeClosureCompared':False}})
assert len(courses)==305
assert len({c['sourceId'] for c in courses})==len(courses)
assert len({(c['courseName'],c['professor'],c['sourceClassroom'],c['sourceSchedule']) for c in courses})==len(courses)
save('bnue-current-native305-source-20261008.json',{'sourceUrl':URL,'noticeUrl':NOTICE,'sourceSHA256':hashlib.sha256((OLD/'bnue-2026-2-current.xlsx').read_bytes()).hexdigest(),'liveFileBytesMatched':True,'nativeXlsxAndPredecessorCoordinateFieldsCompared':True,'educationRows':rows,'wholeSchoolCompletionClaim':False,'latestWholeClosureCompared':False,'sourceStaffStudentContactOrEnrollmentCountsSaved':False})
n='bnue-unknown-2026-2.native305-partial-v1.json';h=save(n,{'schemaVersion':2,'universityId':'bnue','institutionId':'institution:academyinfo:0000254','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-09-04','sourceUrl':NOTICE,'candidateRevision':'native305-partial-v1','termStartDate':'2026-09-01','termEndDate':'2026-12-14','completionClaim':False,'courses':courses})
audit={'file':n,'SHA256':h,'nativeDocumentBlocks':len(courses),'scheduledBlocks':sum(bool(c['schedules']) for c in courses),'heldUnassignedProfessorBlocks':sum(not c['schedules'] for c in courses),'datedSlots':sum(len(c['schedules']) for c in courses),'sourceIdDuplicateCount':0,'exactTitleTeacherRoomClockDuplicateCount':0,'wholeSchoolCompletionClaim':False,'latestWholeClosureCompared':False,'productionChanged':False};save('bnue-current-native305-partial-v1-audit.json',audit);print(audit)
