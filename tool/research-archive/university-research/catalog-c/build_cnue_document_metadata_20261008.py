from pathlib import Path
import openpyxl,json,re,hashlib
p=Path('work/university-research/catalog-c/cnue-current-20261008');p.mkdir(exist_ok=True)
w=openpyxl.load_workbook('/private/tmp/cnue-current2026-2.xlsx',data_only=True)
receipt={'sourceUrl':'https://www.cnue.ac.kr/cnue/news/notice02.do?mode=download&articleNo=41702&attachNo=62495','originalSha256':hashlib.sha256(Path('/private/tmp/cnue-current2026-2.xlsx').read_bytes()).hexdigest(),'freshByteEqualPrior':Path('/private/tmp/cnue-current2026-2.xlsx').read_bytes()==Path('work/university-research/catalog-g/cnue2026-2-0826.xlsx').read_bytes(),'sheets':[]}
items=[];holds=[]
for s in w:
 cells=[];groups={}
 for row in s.iter_rows(min_row=4,max_row=48,min_col=3,max_col=14):
  for c in row:
   if c.value is None:continue
   text=str(c.value).strip();merge=next((m for m in s.merged_cells if c.coordinate in m),None)
   day=s.cell(c.row,1).value
   if day is None:
    dm=next((m for m in s.merged_cells if s.cell(c.row,1).coordinate in m),None)
    if dm:day=s.cell(dm.min_row,dm.min_col).value
   period=s.cell(c.row,2).value
   r={'cell':c.coordinate,'text':text,'merge':str(merge) if merge else '', 'rowSpan':merge.max_row-merge.min_row+1 if merge else 1,'columnSpan':merge.max_col-merge.min_col+1 if merge else 1,'weekdayLabel':str(day),'firstPeriodLabel':str(period)}
   cells.append(r)
   m=re.fullmatch(r'(.+?)\s+([^<>\s]+)<([^<>]+)>',re.sub(r'\s+',' ',text))
   if not m or any(x in text for x in ['택1','<창의','<교직','[','스키','수상','캠핑','야영','실습','졸업논문','세미나','현장']):
    holds.append({'grade':s.title,**r,'reason':'다중 선택지/별도 운영/격주·조건부/원문 불완전 항목 보류'});continue
   title,prof,room=[x.strip() for x in m.groups()]
   if '/' in prof or '/' in room:
    holds.append({'grade':s.title,**r,'reason':'복수 교수·강의실 실제 배정 미확인'});continue
   groups.setdefault((c.column,r['columnSpan'],title,prof,room),[]).append(r)
 receipt['sheets'].append({'grade':s.title,'title':s['A1'].value,'departmentHeaders':{s.cell(3,col).coordinate:str(s.cell(3,col).value) for col in range(3,15)},'groupHeaders':{s.cell(2,col).coordinate:str(s.cell(2,col).value) for col in range(1,15) if s.cell(2,col).value is not None},'cells':cells})
 for (col,span,title,prof,room),rows in groups.items():
  deps=[str(s.cell(3,k).value).strip() for k in range(col,col+span) if s.cell(3,k).value is not None]
  items.append({'sourceId':f'cnue-document62495-{s.title}-{rows[0]["cell"]}','referenceKind':'공개 문서 내부 셀 위치(공식 과목번호 아님)','canonicalSubjectCodePublished':False,'nativeSectionPublished':False,'academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','section':'','courseName':title,'professor':prof,'credits':None,'classification':'','classificationGroup':'','departments':[s.title+' '+d for d in deps],'departmentCredits':{},'departmentClassifications':{},'departmentRemarks':{},'remarks':'춘천교대 2026.8.26. 기준 공식 공개 시간표의 문서 항목입니다. 과목코드·개별 분반·학점·이수구분 미공개로 빈 코드·분반·미확인 학점 및 구분을 보존합니다. 내부 식별자는 공식 과목번호가 아닌 문서 셀 위치입니다. 열 학과·군 구분을 과목 분반으로 추정하지 않았습니다. 4학년은 7주 집중수업·임용시험 준비 휴강·잔여수업 별도 운영이며, 3학년은 11/2~13 실습으로 일반 학기 반복을 생성하지 않습니다. 현재 실제 교시 시각 및 보강·격주·집중 운영 날짜 미확인, 캠퍼스명 미공개, 최신 폐강 완전성 미확인으로 일정 저장 보류.','sourceSchedule':'; '.join(r['weekdayLabel']+' '+r['firstPeriodLabel']+'교시부터 원문rowSpan '+str(r['rowSpan']) for r in rows),'sourceClassroom':room,'scheduleStatus':'unrecognized','scheduleHoldReason':'현재 강의 교시 시각 및 실습·집중·격주 보충 운영 실제 날짜 미확인','schedules':[],'publicEducationCells':rows})
raw={'schemaVersion':2,'universityId':'cnue','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-08-28','sourceUrl':'https://www.cnue.ac.kr/cnue/news/notice02.do?mode=view&articleNo=41702','courses':items}
f='cnue-unknown-2026-2.document-metadata-only-20261008.json'
for fn,val in [('source-educational-grid.json',receipt),(f,raw),('ambiguous-and-special-cells-held.json',holds)]: (p/fn).write_text(json.dumps(val,ensure_ascii=False,indent=2)+'\n')
a={'candidate':{'file':f,'sha256':hashlib.sha256((p/f).read_bytes()).hexdigest()},'documentMetadata':len(items),'sourceCells':sum(len(s['cells']) for s in receipt['sheets']),'heldSourceCells':len(holds),'scheduled':0,'completionClaim':False,'nativeOfferingCountClaim':False}
(p/'metadata-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print(a)
