"""Current public undergraduate cells: preserve native metadata, hold all unknown clocks."""
from pathlib import Path
import json,re,hashlib,urllib.parse
import openpyxl
ROOT=Path(__file__).resolve().parent;OLD=ROOT.parent.parent/'catalog-g'
URL='https://portal.snue.ac.kr/common/nttFileDownload.do?fileKey=d2b16e70a6f7ea85d8b97de0cdd5cf80&bbsId=1081'
NOTICE='https://www.snue.ac.kr/snue/na/ntt/selectNttInfo.do?bbsId=1081&mi=1280&nttSn=54288'
def save(n,x):
 p=ROOT/n;p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n');return hashlib.sha256(p.read_bytes()).hexdigest()
requests=json.loads((ROOT/'snue-current-source-request-receipt-20261008.json').read_text());assert all(v['sameAsPreservedFile'] for v in requests if v['name'] in ['grid','changes'])
wb=openpyxl.load_workbook(OLD/'snue2026-2-0908.xlsx',data_only=True)
fixture=json.loads((OLD/'snue-final-raw-sheets.json').read_text())
raw=json.loads((OLD/'snue-explicit-course-cells.json').read_text())
closures=json.loads((ROOT/'snue-current-closure-education-receipt-20261008.json').read_text());assert closures['sameAsPreservedFile']
cal=json.loads((ROOT/'snue-current-calendar-education-receipt-20261008.json').read_text())
cal['educationalEvents']=[v for v in cal['educationalEvents'] if v['nativeTitle'].startswith('[학부') or v['nativeTitle']=='[학생처] 사향축제'];save('snue-current-calendar-education-receipt-20261008.json',cal)
assert any(v['startDate']=='2026-08-31' and '개강' in v['nativeTitle'] for v in cal['educationalEvents'])
assert any(v['startDate']=='2026-12-11' and '종강' in v['nativeTitle'] for v in cal['educationalEvents'])
classes=['교양','교직','전공','심화','심자','마이크로디그리'];selected={};omitted=[]
for v in raw:
 sh=wb[v['sheet']];cell=sh[v['cell']];assert cell.value==v['value'];assert fixture[sh.title]['rows'][cell.row-1][cell.column-1]==v['value']
 parts=[p.strip() for p in v['value'].splitlines() if p.strip()]
 if not (len(parts)>=6 and re.fullmatch('[월화수목금][1-8]+',parts[0]) and re.fullmatch('[A-Z]',parts[-4]) and parts[-3] in classes):
  omitted.append({'sheet':v['sheet'],'cell':v['cell'],'reason':'not_single_explicit_native_course_fields'});continue
 # Only fields published directly in the six-line record, never codes from letters.
 title=''.join(parts[1:-4]);section,classification,teacher,room=parts[-4:]
 if not title or not room:continue
 scope_cell=next((sh.cell(cell.row,2) for _ in [0] if sh.cell(cell.row,2).value),None)
 scope=str(scope_cell.value).strip() if scope_cell else ''
 if not scope:
  scope_merge=next((m for m in sh.merged_cells.ranges if m.min_col==2 and m.min_row<=cell.row<=m.max_row),None)
  if scope_merge:scope=str(sh.cell(scope_merge.min_row,2).value or '').strip()
 merge=next((m for m in sh.merged_cells.ranges if m.min_row==cell.row and m.min_col==cell.column),None)
 if merge:assert str(merge) in fixture[sh.title]['mergedRanges']
 occ={'sheet':sh.title,'cell':cell.coordinate,'nativeCellText':v['value'],'nativeStudentScope':scope,'mergedRange':str(merge) if merge else None}
 key=v['value']
 if key in selected:selected[key]['sourceOccurrences'].append(occ);continue
 sid=URL+'#sheet='+urllib.parse.quote(sh.title,safe='')+'&cell='+cell.coordinate
 closed=[c for c in closures['closedEducationalRows'] if c['grade']==int(sh.title[0]) and c['courseName']==title and c['section']==section]
 selected[key]={'sourceId':sid,'sourceOccurrences':[occ],'grade':int(sh.title[0]),'courseName':title,'section':section,'classification':classification,'professor':teacher,'classroom':room,'nativePeriod':parts[0],'closedSourceMatches':closed,'status':'closed' if closed else 'held','holdReason':'actual_undergraduate_period_clock_unverified'}
rows=list(selected.values());courses=[]
for r in rows:
 groups=list(dict.fromkeys(v['sheet']+' / '+v['nativeStudentScope'] for v in r['sourceOccurrences']))
 note='현재 공개 학부 교시의 실제 시각은 미확인하여 날짜·시각·기간 변환을 보류했습니다. 내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다. 과목코드는 미공개로 빈 값이며 분반은 원문 문자 그대로 보존합니다. 학점은 이 표에 미공개입니다. 원문 교양/교직/전공/심화/심자/마이크로디그리 표기를 그대로 보존하며 축약어의 위계를 발명하지 않습니다. A/B군과 학년·학과는 학생 범위이며 물리 캠퍼스 증거가 없어 campus unknown입니다. 자체 학부 8월31일 개강·12월11일 종강,2·3학년10월26일~11월6일 실습을 확인했으나 현재 실제 clock 없이는 예약을 생성하지 않습니다. 목요일7·8교시는 현장 역량강화 프로그램 활동 시간으로 정규수업 없음이 현재 수강신청 안내문에 명시됩니다. 여러 시트의 동일 원문은 sourceOccurrences로 보존했습니다. 과목별 최신 전체 폐강 대조 및 실제 운영 날짜는 미확인입니다.'
 if r['closedSourceMatches']:note+=' 현재8월24일 학부 폐강3개 중 해당 과목·문자분반이9월8일 표에 남아 있어 폐강으로 보류했습니다.'
 if r['professor'] in ['신규','신규강사','신규교수']:note+=' 교수란의 원문 미배정 표기는 실제 확정 교수명이 아닙니다.'
 if len({v['nativeCellText'] for v in r['sourceOccurrences']})!=1:raise AssertionError('source dedup drift')
 courses.append({'sourceId':r['sourceId'],'referenceKind':'internalDocumentLocator','academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','courseName':r['courseName'],'section':r['section'],'professor':r['professor'],'credits':None,'classification':r['classification'],'departments':groups,'departmentClassifications':{},'departmentCredits':{},'departmentRemarks':{g:note for g in groups},'sourceSchedule':r['nativePeriod'],'sourceClassroom':r['classroom'],'period':None,'scheduleStatus':'unrecognized','schedules':[],'sourceEducation':{'nativePublicBlock':r,'referenceKind':'internalDocumentLocator','wholeSchoolCompletionClaim':False,'actualClockVerified':False,'latestWholeClosureCompared':False}})
assert len({c['sourceId'] for c in courses})==len(courses)
save('snue-current-native-education-source-20261008.json',{'sourceUrl':URL,'sourceSHA256':hashlib.sha256((OLD/'snue2026-2-0908.xlsx').read_bytes()).hexdigest(),'liveFileBytesMatched':True,'educationRows':rows,'omittedDocumentCells':omitted,'totalPredecessorExplicitCells':len(raw),'wholeSchoolCompletionClaim':False,'privateCountsOrContactsSaved':False})
n='snue-unknown-2026-2.native-held-partial-v1.json';sha=save(n,{'schemaVersion':2,'universityId':'snue','institutionId':'institution:academyinfo:0000255','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-09-08','sourceUrl':NOTICE,'candidateRevision':'native-held-partial-v1','termStartDate':'2026-08-31','termEndDate':'2026-12-11','completionClaim':False,'courses':courses})
audit={'file':n,'SHA256':sha,'nativeDocumentBlocks':len(courses),'rawSelectedOccurrences':sum(len(r['sourceOccurrences']) for r in rows),'scheduledBlocks':0,'datedSlots':0,'closedBlocks':sum(bool(r['closedSourceMatches']) for r in rows),'actualClockVerified':False,'eligibleScheduleThreeModeDriveVerified':False,'wholeSchoolCompletionClaim':False,'latestWholeClosureCompared':False,'productionChanged':False};save('snue-current-native-held-partial-v1-audit.json',audit);print(audit)
