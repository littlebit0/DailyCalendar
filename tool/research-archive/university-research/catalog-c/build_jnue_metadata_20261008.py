from pathlib import Path
import re,json,hashlib
import openpyxl
out=Path('work/university-research/catalog-c/jnue-current-20261008')
w=openpyxl.load_workbook('/private/tmp/jnue2026-2-latest.xlsx',data_only=True)
receipt={'sourceUrl':'https://portal.jnue.kr/ext/html5fileupload/fileDownload.do?fileId=1a0c6e110e952&fileSeq=1&fileStoreDir=bbs','originalSha256':hashlib.sha256(Path('/private/tmp/jnue2026-2-latest.xlsx').read_bytes()).hexdigest(),'sheets':[]}
items=[];holds=[]
for s in w:
 cells=[];groups={}
 for row in s.iter_rows(min_row=5,max_row=114,min_col=3,max_col=14):
  for c in row:
   if c.value is None or c.row%2==0:continue
   text=str(c.value).strip(); teacher=str(s.cell(c.row+1,c.column).value or '').strip()
   merge=next((str(m) for m in s.merged_cells if c.coordinate in m),'')
   weekday=(c.row-5)//22+1;period=((c.row-5)%22)//2+1
   rec={'cell':c.coordinate,'text':text,'teacherRoomCell':s.cell(c.row+1,c.column).coordinate,'teacherRoomText':teacher,'merge':merge,'weekday':weekday,'period':period,'nativeStudyClass':str(s.cell(3,c.column).value)}
   cells.append(rec)
   if merge or '(1선' in text or '\n' in text or not teacher:
    holds.append({'grade':s.title,**rec,'reason':'선택과목 합침/복수 선택지 또는 강사·강의실 원문 불완전; 과목 분반 식별 및 clock 운영 미확인'})
    continue
   match=re.fullmatch(r'(.+?)\[([^\[\]]+)\]',teacher)
   prof=match[1].strip() if match else teacher;room=match[2].strip() if match else ''
   key=(c.column,text,prof)
   groups.setdefault(key,[]).append({**rec,'room':room,'professor':prof})
 sheet={'grade':s.title,'title':s['A1'].value,'term':s['A2'].value,'nativeStudyClassHeaders':{s.cell(3,col).coordinate:str(s.cell(3,col).value) for col in range(3,15)},'weekdayHeaders':{s.cell(r,1).coordinate:str(s.cell(r,1).value) for r in range(5,115,22)},'periodHeaders':{s.cell(r,2).coordinate:str(s.cell(r,2).value) for r in range(5,27,2)},'publishedClockLabels':{c.coordinate:str(c.value) for row in s.iter_rows(min_col=16,max_col=16) for c in row if c.value is not None},'educationCells':cells}
 receipt['sheets'].append(sheet)
 for (column,title,prof),rows in groups.items():
  locator=rows[0]['cell'];sid=f'jnue-document16121-{s.title}-{locator}'
  items.append({'sourceId':sid,'referenceKind':'문서 내부 항목 위치(공식 과목번호 아님)','canonicalSubjectCodePublished':False,'nativeSectionPublished':False,'nativeStudyClass':rows[0]['nativeStudyClass'],'academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','section':'','courseName':title,'professor':prof,'credits':None,'classification':'','classificationGroup':'','departments':[s.title+' '+rows[0]['nativeStudyClass']],'departmentCredits':{},'departmentClassifications':{},'departmentRemarks':{},'remarks':'전주교대 2026.9.15. 기준 공식 공개 문서 항목입니다. 과목코드·과목 분반·학점·이수구분이 공개되지 않아 빈 코드·분반과 미확인 구분을 유지합니다. 열 머리의 수업반은 nativeStudyClass로 별도 보존하며 과목 분반으로 추정하지 않았습니다. 내부 식별자는 문서 위치이며 공식 과목번호가 아닙니다. 9~10시 등 공개 시간대의 실제 수업 종료 시각과 휴강·보강 운영 미확인으로 일정 저장은 보류합니다. 캠퍼스명 미공개. 최신 시간표 변경 이후 범위이며 전체 폐강 완전성 미확인.','sourceSchedule':'; '.join(f"{r['weekday']}요일 {r['period']}교시" for r in rows),'sourceClassroom':' / '.join(dict.fromkeys(r['room'] for r in rows)),'schedules':[],'publicEducationCells':rows,'scheduleHoldReason':'실제 수업 종료 시각, 학년 실습 중 통상 수업 운영, 휴강 및 정확 보강일 미확인'})
raw={'schemaVersion':2,'universityId':'jnue','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-09-22','sourceUrl':'https://www.jnue.kr/portal/jnue/bbs/view.do?menuId=M0004000100010000&boardSeq=16121','courses':items}
for name,value in [('source-educational-grid.json',receipt),('merged-choice-and-incomplete-cells-held.json',holds),('jnue-unknown-2026-2.metadata-only-20261008.json',raw)]:
 (out/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
print('metadata',len(items),'heldsourcecells',len(holds),'grid',sum(len(s['educationCells']) for s in receipt['sheets']))
