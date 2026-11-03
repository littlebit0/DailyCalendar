"""Unambiguous source row blocks; observed closure and alternate-week proof precede dates."""
from pathlib import Path
from datetime import date,timedelta
import json,re,hashlib,urllib.parse
import openpyxl,pdfplumber
ROOT=Path(__file__).resolve().parent;OLD=ROOT.parent.parent/'catalog-g';Q=ROOT.parent.parent/'catalog-q'
URL='https://www.dnue.ac.kr/kor/ajx_json/UploadMgr/downloadRun.do?qcode=Qm9hcmQsMjMzNjgsWQ=='
NOTICE='https://www.dnue.ac.kr/kor/CMS/Board/Board.do?mCode=MN226&mgr_seq=30&mode=view&board_seq=18603'
def save(n,x):
 p=ROOT/n;p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n');return hashlib.sha256(p.read_bytes()).hexdigest()
def normalized(s):return re.sub(r'[^가-힣A-Za-z0-9]','',re.sub(r'\([\d,\- ]+\)','',s))
closed=[(1,'토론과시민적태도'),(1,'국제관계와통일의이해'),(1,'문화코드로읽는미국시민사'),(1,'동아시아사회의이해'),(1,'생활속의화학탐구'),(1,'생물과인간'),(1,'음악의이해(양악)'),(2,'신화와옛이야기'),(2,'기초문식성교육론'),(3,'현대대수교육'),(3,'듣기,말하기지도'),(4,'프로젝트학습론'),(4,'수학문제해결과평가'),(4,'초등교육과정론'),(4,'테크놀로지기반초등영어수업'),(4,'초등영어수업관찰및분석'),(4,'3D콘텐츠개발')]
with pdfplumber.open(Q/'dnue2026-2-credit-allocation.pdf') as pdf:
 assert len(pdf.pages)==4
 for page_number,title in closed:
  text=pdf.pages[page_number-1].extract_text()
  assert any(normalized(title) in normalized(line) and '폐강' in line for line in text.splitlines())
 reading_line=next(line for line in pdf.pages[0].extract_text().splitlines() if '독서와작문' in normalized(line))
 assert all(x in normalized(reading_line) for x in ['독서와작문3','이강엽16','이철호23','윤준채45','천해주7'])
save('dnue-current-closure17-source-20261008.json',{'sourceUrl':'https://www.dnue.ac.kr/kor/ajx_json/UploadMgr/downloadRun.do?qcode=Qm9hcmQsMjM1MDMsWQ==','sourceSHA256':hashlib.sha256((Q/'dnue2026-2-credit-allocation.pdf').read_bytes()).hexdigest(),'publishedDate':'2026-09-10','closedNativeTitles':[{'grade':g,'page':g,'nativeCourseName':t,'nativeStatus':'폐강'} for g,t in closed],'currentReadingNativeCreditProof':{'page':1,'courseName':'독서와작문','credits':3,'classification':'교양필수','teacherStudentGroups':{'이강엽':[1,6],'이철호':[2,3],'윤준채':[4,5],'천해주':[7]},'nativeCreditRowAndMergedCategoryVisuallyVerified':True},'independentPdfTextCompared':True,'educationOnlyTitleClosureStripsVisuallyCompared':True,'sourceEnrollmentCountsSaved':False})
requests=json.loads((ROOT/'dnue-current-source-request-receipt-20261008.json').read_text());assert all(r['matchesPreservedFile'] is True for r in requests if r['name'] in ['file','allocation'])
term=json.loads((ROOT/'dnue-current-calendar-term-receipt-20261008.json').read_text());notice=next(x['educationalSourceText'] for x in term if x['name']=='notice');cal=next(x['educationalSourceText'] for x in term if x['name']=='calendar')
assert '수업일정: 2026. 9. 1.(화) ~ 12. 21.(월)' in notice
assert '홀수주 예시 : 9. 1. 화. ~ 9. 7. 월' in notice
assert all(x in cal for x in ['대체휴일','2학년 수업실습','3학년 수업실습','강의보충기간','기말고사'])
wb=openpyxl.load_workbook(OLD/'dnue2026-2-final.xlsx',data_only=True);original=json.loads((OLD/'dnue2026-2-final-raw.json').read_text());courses=[];rows=[];excluded=[]
reading={'이강엽':[1,6],'이철호':[2,3],'윤준채':[4,5],'천해주':[7]}
for sheet in wb.worksheets:
 weekday='월화수목금'.index(sheet.title)+1
 assert sheet['A2'].value=='['+sheet.title+'요일]'
 for r in range(6,62):
  grade=(r-6)//14+1;group_number=sheet.cell(r,2).value;group_name=sheet.cell(r,3).value;group=f'{grade}학년 {group_number} {group_name}'
  slots=[]
  for period in range(9):
   col=4+period*4;c=sheet.cell(r,col);m=next((m for m in sheet.merged_cells.ranges if m.min_row==r and m.min_col==col),None)
   if not c.value or not m or m.max_row!=r or m.max_col!=col+1:slots.append(None);continue
   title=str(c.value).strip();room=sheet.cell(r,col+2).value;teacher=sheet.cell(r,col+3).value
   if not room or not teacher or any(k in str(room)+str(teacher) for k in ['\n','/']):slots.append(None);continue
   room=str(room).strip();teacher=str(teacher).strip()
   if any(g==grade and normalized(t)==normalized(title) for g,t in closed):
    excluded.append({'sheet':sheet.title,'cell':c.coordinate,'grade':grade,'courseName':title,'reason':'Current2026-2 final credit allocation explicitly 폐강'});slots.append(None);continue
   times=re.findall(r'\d{2}:\d{2}',str(sheet.cell(4,col).value));assert times==[f'{period+9:02}:00',f'{period+9:02}:50']
   for off,value in [(0,title),(2,room),(3,teacher)]:assert str(original[sheet.title]['rows'][r-1][col+off-1]).strip()==value
   assert original[sheet.title]['rows'][3][col-1]==sheet.cell(4,col).value
   slots.append({'cell':c.coordinate,'period':period+1,'start':times[0],'end':times[1],'courseName':title,'professor':teacher,'classroom':room,'nativeClockHeader':sheet.cell(4,col).value})
  i=0
  while i<9:
   if slots[i] is None:i+=1;continue
   first=i;key=tuple(slots[i][k] for k in ['courseName','professor','classroom'])
   while i+1<9 and slots[i+1] and tuple(slots[i+1][k] for k in ['courseName','professor','classroom'])==key:i+=1
   block=slots[first:i+1];cell=block[0]['cell'];source_id=URL+'#sheet='+urllib.parse.quote(sheet.title,safe='')+'&cell='+cell
   start=int(block[0]['start'][:2])*60;end=int(block[-1]['end'][:2])*60+50
   parity=None
   if grade==1 and normalized(key[0])=='자연과학개론':
    if key[1] in ['임우창','신민현']:parity=1
    elif key[1] in ['최진경','박순영']:parity=0
    else:excluded.append({'sheet':sheet.title,'cell':cell,'courseName':key[0],'reason':'Alternate week faculty identity unknown'});i+=1;continue
   credit=3 if grade==1 and normalized(key[0])=='독서와작문' and group_number in reading.get(key[1],[]) else None
   classification='교양필수' if credit==3 else ''
   native={'sourceId':source_id,'sheet':sheet.title,'grade':grade,'cell':cell,'row':r,'nativeStudentGroup':group,'nativeGroupNumber':group_number,'nativeGroupName':group_name,'courseName':key[0],'professor':key[1],'classroom':key[2],'clockRows':block,'weekday':weekday,'startMinute':start,'endMinute':end,'sourceCredits':credit,'sourceClassification':classification,'alternateWeekParity':parity,'creditSourceBasis':'2026-2 credit allocation page1 독서와작문3/교양필수, exact teacher and class group' if credit else None}
   rows.append(native);meetings=[];d=date(2026,9,1)
   while d<=date(2026,12,7):
    ds=d.isoformat();week=(d-date(2026,9,1)).days//7+1
    hold=ds in ['2026-09-24','2026-09-25','2026-10-05','2026-10-09'] or (grade==2 and '2026-10-19'<=ds<='2026-10-30') or (grade==3 and '2026-11-16'<=ds<='2026-11-27')
    if d.isoweekday()==weekday and not hold and (parity is None or week%2==parity):meetings.append({'date':ds,'weekday':weekday,'startMinute':start,'endMinute':end,'classroom':key[2]})
    d+=timedelta(days=1)
   note='공개 주간 예약 계획, 실제 운영/날짜 미확인. 내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다. 코드·개별 수강분반은 미공개로 빈 값이며 학년·반·심화과정은 원문 학생집단 범위입니다. 현재2026-2 확정시간표와9월10일 배당표 원문은 정상 공개 재조회 파일과 일치합니다. 현재 배당표의 폐강17제목은 학년과 원문제목 대조해 제외했으나 학교전체 최신 강좌ID별 폐강 대조는 미완료입니다. 정확50분 교시 시각을 보존하며 연속교시 내부 휴게시간은 포함될 수 있습니다. 캠퍼스별 물리 매핑은 미확인, 실은 원문 그대로입니다. 학교수업일정은9월1일~12월21일 직접명시, 예약범위는 보충기간 전12월7일까지입니다. 자체 추석9월24~26일·대체휴일10월5일·한글날10월9일 및12월8~14일 강의보충·12월15~21일 기말고사는 예약 제외하며 실제 보강날짜는 미확인입니다. 상록대동제10월14~15일의 강좌별 실제 운영은 미확인입니다. 학점/이수구분은 현재 학년·반·교수 일치가 검증된 독서와작문만 배당표3학점/교양필수로 보존하고 나머지는 미확인입니다.'
   if grade==2:note+=' 2학년10월19~30일 수업실습Ⅰ은 제외하고10월12~16일 중1일 오리엔테이션의 강좌별 충돌·실제날짜·원격 여부는 미확인입니다.'
   if grade==3:note+=' 3학년11월16~27일 수업실습Ⅰ·Ⅱ는 예약 제외합니다.'
   if parity is not None:note+=' 1학년 자연과학개론은 현재 확정공지가9월1일~7일을 홀수주,9월8일~14일을 짝수주로 직접명시하므로 화요일부터7일 단위의 주번호를 사용했습니다. 현재 배당표의 물리/화학(임우창/신민현)은 홀수주,생물/지학(최진경/박순영)은 짝수주만 보존하고 보강주차 연결은 미확인입니다.'
   courses.append({'sourceId':source_id,'referenceKind':'internalDocumentLocator','academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','courseName':key[0],'section':'','professor':key[1],'credits':credit,'classification':classification,'departments':[group],'departmentClassifications':{},'departmentCredits':{},'departmentRemarks':{group:note},'sourceSchedule':sheet.title+' '+block[0]['start']+'~'+block[-1]['end'],'sourceClassroom':key[2],'period':{'startDate':'2026-09-01','endDate':'2026-12-07'},'scheduleStatus':'scheduled','schedules':meetings,'sourceEducation':{'nativePublicBlock':native,'referenceKind':'internalDocumentLocator','sourceStudentGroupIsNotOpeningDepartment':True,'wholeSchoolCompletionClaim':False,'latestWholeClosureCompared':False}})
   i+=1
assert len({c['sourceId'] for c in courses})==len(courses)
assert len({(c['courseName'],c['professor'],c['sourceClassroom'],c['sourceSchedule']) for c in courses})==len(courses)
save('dnue-current-unambiguous-source-20261008.json',{'sourceUrl':URL,'noticeUrl':NOTICE,'sourceSHA256':hashlib.sha256((OLD/'dnue2026-2-final.xlsx').read_bytes()).hexdigest(),'liveOriginalFileMatched':True,'nativeXlsxAndPredecessorCoordinateFieldsCompared':True,'educationRows':rows,'excludedSourceBlocks':excluded,'wholeSchoolOperatingComplete':False,'latestWholeClosureCompared':False,'sourceStaffStudentContactSaved':False})
n='dnue-unknown-2026-2.public-blocks-partial-v1.json';h=save(n,{'schemaVersion':2,'universityId':'dnue','institutionId':'institution:academyinfo:0000253','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-08-10','sourceUrl':NOTICE,'candidateRevision':'public-blocks-partial-v1','termStartDate':'2026-09-01','termEndDate':'2026-12-21','completionClaim':False,'courses':courses})
audit={'file':n,'SHA256':h,'courses':len(courses),'datedSlots':sum(len(c['schedules']) for c in courses),'alternateWeekBlocks':sum(r['alternateWeekParity'] is not None for r in rows),'exactCurrentCreditClassificationBlocks':sum(r['sourceCredits'] is not None for r in rows),'excludedClosedGridSlots':sum('폐강' in r['reason'] for r in excluded),'sourceIdDuplicateCount':0,'exactTitleTeacherRoomClockDuplicateCount':0,'wholeSchoolCompletionClaim':False,'latestWholeClosureCompared':False,'productionChanged':False};save('dnue-current-public-blocks-partial-v1-audit.json',audit);print(audit)
