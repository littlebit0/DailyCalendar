from pathlib import Path
import json,sys,re,datetime,hashlib
sys.path.insert(0,'/private/tmp/daily-catalog-xls-read');import xlrd
p=Path('work/university-research/catalog-c/ut-current-20261008');p.mkdir(exist_ok=True)
def save(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
s=xlrd.open_workbook('/private/tmp/ut-biotech.xls',formatting_info=True).sheet_by_index(0)
receipt={'sourceUrl':'https://www.ut.ac.kr/cmm/fms/FileDown.do?atchFileId=FILE_000000000290587&fileSn=0','sha256':hashlib.sha256(Path('/private/tmp/ut-biotech.xls').read_bytes()).hexdigest(),'sheet':s.name,'title':s.cell_value(0,0),'values':[s.row_values(i) for i in range(s.nrows)],'merges':s.merged_cells,'nativeDepartmentCampus':'증평캠퍼스','campusProofUrl':'https://www.ut.ac.kr/kor/sub01_04_04_02.do'};save('biotech-original-educational-grid.json',receipt)
items=[];holds=[];clockRows={4,7,10,13,16,19};excluded={'2026-09-24':'추석연휴','2026-09-25':'추석연휴','2026-10-05':'대체휴일','2026-10-09':'한글날'}
start=datetime.date(2026,9,1);end=datetime.date(2026,10,19)
for row in range(4,s.nrows):
 for col in range(3,28):
  text=s.cell_value(row,col)
  if not text:continue
  text=str(text).strip();header=s.cell_value(3,col);merge=next((list(x) for x in s.merged_cells if x[0]==row and x[2]==col),[row,row+1,col,col+1]);cell={'row':row,'column':col,'text':text,'merge':merge,'nativeStudyColumn':str(header)}
  if header=='대학원':continue
  lines=text.splitlines()
  if row not in clockRows or merge[1]-row!=3 or len(lines)!=3 or not re.fullmatch(r'\d+',lines[-1]) or '실험' in text:
   holds.append({**cell,'reason':'50분/75분 혼합 표의 시작·끝 칸 범위/방/별도 운영 미확인'});continue
  label=s.cell_value(row,28);nums=list(map(int,re.findall(r'\d+',label)))
  if len(nums)!=4:raise ValueError('clock')
  a=nums[0]*60+nums[1];b=nums[2]*60+nums[3]
  day=next(i for i,(left,right) in enumerate([(3,9),(9,15),(15,20),(20,24),(24,28)],1) if left<=col<right)
  plans=[];date=start
  while date<=end:
   if date.isoweekday()==day and date.isoformat() not in excluded:plans.append({'date':date.isoformat(),'weekday':day,'startMinute':a,'endMinute':b,'classroom':lines[2],'sourceRow':row,'sourceColumn':col,'sourceClockColumn':28,'reservationRangeOnly':True})
   date+=datetime.timedelta(days=1)
  nativeClass=str(header);cell['publishedClockText']=label;cell['weekday']=day
  items.append({'sourceId':f'ut-document290587-r{row}c{col}','referenceKind':'공개 문서 내부 셀 위치(공식 과목번호 아님)','canonicalSubjectCodePublished':False,'nativeSectionPublished':False,'academicYear':2026,'semester':'2','campus':'unknown','nativeCampusScope':'공식 소속전공 증평캠퍼스; 개별 강의 건물명 미공개','courseCode':'','section':'','courseName':lines[0],'professor':lines[1],'credits':None,'classification':'','classificationGroup':'','departments':['생명공학전공 '+nativeClass],'departmentCredits':{},'departmentClassifications':{},'departmentRemarks':{},'nativeStudyColumn':nativeClass,'sourceEducationCell':cell,'remarks':'국립한국교통대 2026-2 생명공학전공 공식 공개 시간표의 칸 예약 범위입니다. 75분 수업 열에 표시된 시작·끝(예: 09:00~10:30)을 그대로 사용하며 휴게·실제 강의 종료 시각은 미확인입니다. 75분 종료로 줄이지 않았습니다. 과목코드·개별 과목 분반·학점·이수구분 미공개(빈 코드/분반/구분 및 미확인 학점), 내부 식별자는 공식 과목번호 아닌 문서 셀입니다. 원문 열 학년·1-1/1-2 및 제목말미1/2를 과목 분반으로 추정하지 않았습니다. 소속전공의 증평캠퍼스는 공식 캠퍼스별 보건생명대학 표로 확인했으나 개별 강의 물리 캠퍼스·건물명은 미공개이므로 강의 캠퍼스 미확인으로 보존합니다. 강의실 숫자는 원문 그대로입니다. 개강9/1부터 중간고사 권장기간 전10/19까지만 예약하고 공휴일을 제외했습니다. 이후 시험·보강·변경·폐강 전체 완전성 및 개인 실제 수강은 미확인입니다. 수강지도 교수 승인 후 신청해야 하며 타학과·타학년·정원 관련은 개설학과 확인이 필요합니다.','sourceSchedule':f'{day}요일 '+label,'sourceClassroom':lines[2],'period':{'startDate':str(start),'endDate':str(end)},'scheduleStatus':'scheduled','schedules':plans})
f='ut-unknown-2026-2.published-partial-20261008.json';save(f,{'schemaVersion':2,'universityId':'ut','campus':'unknown','campusName':'강의 캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-07-22','sourceReservationRangeOnly':True,'sourceUrl':'https://www.ut.ac.kr/cop/bbs/BBSMSTR_000000000528/selectBoardArticle.do?bbsId=BBSMSTR_000000000528&nttId=1123328','courses':items})
save('held-education-cells.json',holds)
a={'candidate':{'file':f,'sha256':hashlib.sha256((p/f).read_bytes()).hexdigest()},'documentMetadata':len(items),'scheduled':len(items),'datedPlans':sum(len(x['schedules']) for x in items),'heldCells':len(holds),'excludedDates':excluded,'start':str(start),'end':str(end),'completionClaim':False,'nativeOfferingCountClaim':False,'sourceRangeOnly':True,'actualLectureEndVerified':False};save('partial-audit.json',a);print(a)
save('electri-educational-tables-held.json',{'sourceUrl':'https://www.ut.ac.kr/cmm/fms/FileDown.do?atchFileId=FILE_000000000290793&fileSn=0','sha256':hashlib.sha256(Path('/private/tmp/ut-electri.pdf').read_bytes()).hexdigest(),'tables':json.loads(Path('/private/tmp/ut-electri-tables.json').read_text()),'actualPublishedClock50And75':True,'candidateGenerated':False,'reason':'학부/대학원·50분/75분 혼합 및 반복부호·개별분반 맵 셀 좌표 시각 검증 미완료; 충주 등 개별 캠퍼스 매핑 미확인'})
