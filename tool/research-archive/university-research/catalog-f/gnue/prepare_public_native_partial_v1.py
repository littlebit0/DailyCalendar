"""Current public native teacher rows and unambiguous clocked undergraduate grid blocks."""
from pathlib import Path
from datetime import date,timedelta
import json,hashlib,re,urllib.parse
import openpyxl
ROOT=Path(__file__).resolve().parent
OLD=ROOT.parent.parent/'catalog-g'
NOTICE='https://www.gnue.ac.kr/planweb/board/view.9is?nttId=9016722&boardUid=4a9f18ab5d53940b015d539889fd0011&contentUid=4a9f18ab5c48fe8c015cec619a32112d'
URL='https://portal.gnue.ac.kr/jfile/readDownloadFile.do?fileId=1a084b9792e38&fileSeq='
def save(n,x):
 p=ROOT/n;p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n');return hashlib.sha256(p.read_bytes()).hexdigest()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
requests=json.loads((ROOT/'gnue-current-source-request-receipt-20261008.json').read_text())
assert all(r['matchesPreservedSource'] for r in requests if r['name'] in ['y12','y34'])
calendar_file=ROOT.parent.parent/'calendar-a/gnue-2026-2.html'
calendar_events=json.loads((ROOT.parent.parent/'calendar-a/gnue-events2026.json').read_text())
calendar_text=calendar_file.read_text()
assert all(s in calendar_text for s in ['2026년 09월','2학기 개강일','3학년 교육실습Ⅰ','실습 및 법정 공휴일 보강주간','2학기말 고사','동계방학'])
save('gnue-current-calendar-and-boundary-20261008.json',{'sourceUrl':'https://www.gnue.ac.kr/index.9is?contentUid=ff8080815bf1bf8b015bfb2d0b4e052f','preservedSourceFile':'../../calendar-a/gnue-2026-2.html','preservedSourceSHA256':sha(calendar_file),'liveCalendarRequestReachedExplicitWaf':True,'bypassAttempted':False,'sourceNativeEvents':[e for e in calendar_events if e['start']>='2026-09-01'],'ordinaryReservationStartDate':'2026-09-01','ordinaryReservationEndDate':'2026-12-07','academicOperatingEndDerivedDate':'2026-12-21','derivedEndBasis':'Day before source winter vacation2026-12-22; not an explicitly published term-end label','nativeCalendarLiveCurrentnessVerified':False,'campusPhysicalMappingVerified':False})
note='공개 주간 예약 계획, 실제 운영/날짜 미확인. 내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다. 교과목코드 및 개별 수강분반은 미공개로 빈 값입니다. 원문 학년/반/심화과정 집단은 수강신청 분반으로 추론하지 않습니다. 공지의 정상 공개 파일은 현재 재조회 원문과 일치하지만 공지/학사일정 CMS는 공개 방화벽 경계여서 최신 강좌 폐강 및 일정 재확인 미완료입니다. 캠퍼스는 직접 물리 근거가 없어 미확인입니다. 강의실은 원문 표기 그대로 보존합니다.'
courses=[];rows=[];excluded=[]
# Structured grades1/2 educational rows: preserve individually printed credits and process, hold unresolved A-F/front/back/rotation operating mapping.
wb=openpyxl.load_workbook(OLD/'gnue2026-2-final-y12.xlsx',data_only=True)
raw=json.loads((OLD/'gnue2026-2-final-y12-raw.json').read_text())
for sheet in wb.worksheets[:2]:
 def merged_value(r,c):
  cell=sheet.cell(r,c);v=cell.value;coord=cell.coordinate
  if v is None:
   merged=next((m for m in sheet.merged_cells.ranges if m.min_row<=r<=m.max_row and m.min_col<=c<=m.max_col),None)
   if merged:cell=sheet.cell(merged.min_row,merged.min_col);v=cell.value;coord=cell.coordinate
  return str(v).strip() if v is not None else '',coord
 grade=int(sheet.title[0]);assert sheet['B2'].value==f'2026학년도 2학기 강의 시간표({grade}학년)'
 for r in range(6,sheet.max_row+1):
  title,title_cell=merged_value(r,6);teacher=sheet.cell(r,3).value
  if not title or not teacher:continue
  values={str(c):merged_value(r,c)[0] for c in [2,4,5,6,7,8,9,10,11]}
  for c in [2,4,5,6,7,8,9,10,11]:
   v,coordinate=merged_value(r,c);anchor=sheet[coordinate]
   old_value=raw[sheet.title]['rows'][anchor.row-1][anchor.column-1]
   assert (str(old_value).strip() if old_value is not None else '')==v
  assert str(raw[sheet.title]['rows'][r-1][2]).strip()==str(teacher).strip()
  title_row=sheet[title_cell].row;assert str(raw[sheet.title]['rows'][title_row-1][5]).strip()==title
  source_id=URL+'1#sheet='+urllib.parse.quote(sheet.title,safe='')+'&row='+str(r)
  credit=re.fullmatch(r'(\d+(?:\.\d+)?)\((\d+(?:\.\d+)?)\)',values['9'])
  credits=float(credit[1]) if credit else None
  hours=float(credit[2]) if credit else None
  matrix=[{'cell':sheet.cell(r,c).coordinate,'value':str(sheet.cell(r,c).value).strip()} for c in range(12,57) if sheet.cell(r,c).value is not None and str(sheet.cell(r,c).value).strip()]
  group=f"{grade}학년 {values['2']}"
  room=values['10']+' '+values['11']
  comments=[]
  for c in range(2,57):
   nc=sheet.cell(r,c)
   if nc.comment:
    educational_text=nc.comment.text.split(':',1)[-1].strip()
    if re.fullmatch(r'[0-9\s>\-가-힣]+',educational_text):comments.append({'cell':nc.coordinate,'text':educational_text})
  raw_row={'sourceId':source_id,'sheet':sheet.title,'row':r,'grade':grade,'courseName':title,'professor':str(teacher).strip(),'nativeProcess':values['5'],'sourceCredits':credits,'sourceCreditHoursText':values['9'],'sourceTeachingHours':hours,'sourceClassroom':room,'nativeClassFront':values['7'],'nativeClassBack':values['8'],'nativeStudentGroup':group,'titleCell':title_cell,'nativeWeekdayPeriodMatrix':matrix,'nativeEducationalRoomComments':comments,'sourceCourseCode':'','sourceSection':'','status':'held'}
  rows.append(raw_row)
  held_note=note+' 1·2학년 전반/후반 및 A~F 표기는 원문 보존하며 의미·운영 연결이 미확인이라 학기 전반/후반 기간이나 개별 분반으로 만들지 않습니다. 팀티칭/선택과목·행별 강의주차와 실제50분 시각 연결은 미확인으로 날짜 변환 보류합니다. 학점은 현재 행의 원문 학점(시수) 첫 수치이며 시수와 구분했습니다.'
  if comments:held_note+=' 원문 임시 강의실 메모: '+ ' / '.join(c['text'] for c in comments)
  courses.append({'sourceId':source_id,'referenceKind':'internalDocumentLocator','academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','courseName':title,'section':'','professor':str(teacher).strip(),'credits':credits,'classification':values['5'],'departments':[group],'departmentClassifications':{},'departmentCredits':{},'departmentRemarks':{group:held_note},'sourceSchedule':' / '.join(x['cell']+'='+x['value'] for x in matrix),'sourceClassroom':room,'scheduleStatus':'unrecognized','schedules':[],'sourceEducation':{'nativePublicRow':raw_row,'referenceKind':'internalDocumentLocator','nativeGroupMeaningUnverified':True,'wholeSchoolCompletionClaim':False}})

wb=openpyxl.load_workbook(OLD/'gnue2026-2-final-y34.xlsx',data_only=True)
raw=json.loads((OLD/'gnue2026-2-final-y34-raw.json').read_text())
for sheet in wb.worksheets:
 grade=int(sheet.title[0]);assert sheet['A2'].value=='2026학년도 제2학기'
 for offset in [0,14,28]:
  for row in sheet.iter_rows(min_row=offset+5,max_row=offset+13,min_col=3,max_col=22):
   for cell in row:
    if not cell.value:continue
    text=str(cell.value);parts=[p.strip() for p in text.splitlines() if p.strip()]
    merged=next((m for m in sheet.merged_cells.ranges if m.min_row==cell.row and m.min_col==cell.column),None)
    if len(parts)!=3 or not re.fullmatch(r'[가-힣]{2,5}',parts[1]) or any(k in text for k in ['/','학군','선택','원격','온라인']) or (merged and (merged.min_col!=merged.max_col or merged.max_row>offset+13)):
     excluded.append({'sheet':sheet.title,'cell':cell.coordinate,'nativeText':text,'reason':'Multiple/missing professor-room, choice/field trip/other-school/mixed block; not converted'})
     continue
    assert raw[sheet.title]['rows'][cell.row-1][cell.column-1]==text
    first_row=cell.row;last_row=merged.max_row if merged else first_row
    clocks=[]
    for r in range(first_row,last_row+1):
     times=re.findall(r'\d{2}:\d{2}',str(sheet.cell(r,2).value));assert len(times)==2
     assert raw[sheet.title]['rows'][r-1][1]==sheet.cell(r,2).value
     clocks.append({'cell':sheet.cell(r,2).coordinate,'period':r-offset-4,'start':times[0],'end':times[1],'nativeText':str(sheet.cell(r,2).value)})
    header_column=3+((cell.column-3)//5)*5
    group=f"{grade}학년 {sheet.cell(offset+3,header_column).value}"
    weekday='월화수목금'.index(str(sheet.cell(offset+4,cell.column).value))+1
    start=int(clocks[0]['start'][:2])*60;end=int(clocks[-1]['end'][:2])*60+50
    source_id=URL+'2#sheet='+urllib.parse.quote(sheet.title,safe='')+'&cell='+cell.coordinate
    r={'sourceId':source_id,'sheet':sheet.title,'grade':grade,'cell':cell.coordinate,'mergedRange':str(merged) if merged else None,'nativeCellText':text,'courseName':parts[0],'professor':parts[1],'sourceClassroom':parts[2],'nativeStudentGroup':group,'weekday':weekday,'startMinute':start,'endMinute':end,'clockRows':clocks,'sourceCredits':None,'sourceCourseCode':'','sourceSection':'','status':'scheduled'}
    rows.append(r)
    meetings=[];d=date(2026,9,1)
    while d<=date(2026,12,7):
     ds=d.isoformat();hold=ds in ['2026-09-24','2026-09-25','2026-10-09','2026-10-05'] or (grade==3 and '2026-10-19'<=ds<='2026-10-30')
     if d.isoweekday()==weekday and not hold:meetings.append({'date':ds,'weekday':weekday,'startMinute':start,'endMinute':end,'classroom':parts[2]})
     d+=timedelta(days=1)
    own_note=note+' 3·4학년 표에 개별학점·이수구분이 미공개로 미확인입니다. 공개50분 교시의 시작/끝만 보존하며 연속교시의 휴게시간은 포함될 수 있습니다. 기존2026-2 자체 학사일정 근거로 추석9월24~26일·한글날10월9일·12월8~14일 실습 및 법정 공휴일 보강주간·12월15~21일 기말고사는 예약 제외합니다. 10월5일은 휴일 가능일로 보수적으로 예약 보류하되 자체 원문 별도휴강 확인은 미완료입니다. 풍향대동제10월15~16일·학생독립운동기념일11월3일의 강좌별 실제 운영은 미확인입니다. 12월22일 동계방학 시작은 원문에 있으나 종강12월21일은 전날 추론이며 별도 종강 표기로 취급하지 않습니다.'
    if grade==3:own_note+=' 3학년 교육실습Ⅰ10월19~30일은 예약 제외하고 자체보강 날짜 연결은 보류합니다.'
    courses.append({'sourceId':source_id,'referenceKind':'internalDocumentLocator','academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','courseName':parts[0],'section':'','professor':parts[1],'credits':None,'classification':'','departments':[group],'departmentClassifications':{},'departmentCredits':{},'departmentRemarks':{group:own_note},'sourceSchedule':'월화수목금'[weekday-1]+' '+clocks[0]['start']+'~'+clocks[-1]['end'],'sourceClassroom':parts[2],'period':{'startDate':'2026-09-01','endDate':'2026-12-07'},'scheduleStatus':'scheduled','schedules':meetings,'sourceEducation':{'nativePublicBlock':r,'referenceKind':'internalDocumentLocator','wholeSchoolCompletionClaim':False,'campusPhysicalProof':False}})
scheduled=[c for c in courses if c['scheduleStatus']=='scheduled']
assert len(courses)==251 and len(scheduled)==118
assert len({c['sourceId'] for c in courses})==len(courses)
assert len({(c['courseName'],c['professor'],c['sourceClassroom'],c['sourceSchedule']) for c in scheduled})==len(scheduled)
save('gnue-current-native-education-source-20261008.json',{'noticeUrl':NOTICE,'sourceFiles':[{'file':'../catalog-g/'+n,'SHA256':sha(OLD/n)} for n in ['gnue2026-2-final-y12.xlsx','gnue2026-2-final-y34.xlsx']],'liveFileBytesMatched':True,'undergraduateHeadingsVerified':True,'graduateRowsUsed':False,'educationRows':rows,'excludedGridBlocks':excluded,'physicalCampusMappingVerified':False,'latestClosureCompared':False,'sourceRoomDefinitionText':wb['3학년']['A14'].value,'sourceStaffStudentContactSaved':False})
name='gnue-unknown-2026-2.native251-partial-v1.json'
dataset={'schemaVersion':2,'universityId':'gnue','institutionId':'institution:academyinfo:0000252','academicYear':2026,'semester':'2','campus':'unknown','campusName':'캠퍼스 미확인','publishedDate':'2026-09-09','sourceUrl':NOTICE,'candidateRevision':'native251-partial-v1','completionClaim':False,'courses':courses}
h=save(name,dataset)
audit={'file':name,'SHA256':h,'nativeEducationalDocumentRowsOrBlocks':len(courses),'heldNativeTeacherRows':len(courses)-len(scheduled),'scheduledUnambiguousGridBlocks':len(scheduled),'datedSlots':sum(len(c['schedules']) for c in courses),'sourceIdDuplicateCount':0,'scheduledExactTitleTeacherRoomClockDuplicateCount':0,'nativeXlsxAndPredecessorCellsIndependentCompared':True,'sourceCampusPhysicalProof':False,'latestClosureCompared':False,'liveCalendarFreshnessVerified':False,'sourceCodeSectionInvented':False,'wholeSchoolCompletionClaim':False,'productionChanged':False}
save('gnue-current-native251-partial-v1-audit.json',audit);print(audit)
