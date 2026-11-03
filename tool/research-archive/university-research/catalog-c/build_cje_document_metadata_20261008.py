import json,hashlib,re
from pathlib import Path
p=Path('work/university-research/catalog-c/cje-current-20261008')
source=json.loads(Path('/private/tmp/cje-current2026-2.hwp.tables.json').read_text())[0]
# Preserve only published educational tables and headings, not raw hidden controls.
receipt={'sourceFile':'2026학년도 제2학기 교육과정 시간표_260904.hwp','sourceUrl':'https://www.cje.ac.kr/web/board/fileDownload/85159.do','originalSha256':hashlib.sha256(Path('/private/tmp/cje-current2026-2.hwp').read_bytes()).hexdigest(),'freshByteEqualPrior':Path('/private/tmp/cje-current2026-2.hwp').read_bytes()==Path('work/university-research/catalog-g/cje2026-2-final0904.hwp').read_bytes(),'tables':[{ 'index':i,'cells':t['cells']} for i,t in enumerate(source['tables'])],'headings':[r['text'] for r in source['paragraphs'] if r['text']]}
(p/'original-educational-tables.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
items=[];holds=[]
for ti in [0,2,4,6]:
 t=source['tables'][ti];grade=ti//2+1;headers=[c for c in t['cells'] if c['row']==1 and c['column']>=2];groups={}
 for c in t['cells']:
  if c['row']<2 or c['column']<2 or not any(c['paragraphs']):continue
  text=' '.join(c['paragraphs']).strip();m=re.fullmatch(r'(.+?)\s*\(([^(),]+),([^(),]+)\)',text)
  if not m or any(s in text for s in ['스키','동계스포츠','실습','택1']):
   holds.append({'table':ti,'grade':grade,**c,'reason':'복수 선택지/원문 불완전 또는 별도 집중·실습 운영 미확인'});continue
  title,prof,room=[x.strip() for x in m.groups()]
  weekdaycell=next((x for x in t['cells'] if x['column']==0 and x['row']<=c['row']<x['row']+x['rowSpan']),None)
  periodcell=next((x for x in t['cells'] if x['column']==1 and x['row']==c['row']),None)
  if not weekdaycell or not periodcell:raise ValueError('grid map absent')
  day=''.join(weekdaycell['paragraphs']).strip();period=''.join(periodcell['paragraphs']).strip()
  deps=[' '.join(h['paragraphs']) for h in headers if h['column']<c['column']+c['columnSpan'] and h['column']+h['columnSpan']>c['column']]
  groups.setdefault((c['column'],c['columnSpan'],title,prof,room),[]).append({'table':ti,**c,'weekdayLabel':day,'firstPeriodLabel':period,'departments':deps})
 for (col,span,title,prof,room),cells in groups.items():
  sid=f'cje-document85159-grade{grade}-table{ti}-row{cells[0]["row"]}-column{col}'
  items.append({'sourceId':sid,'referenceKind':'문서 내부 표·셀 위치(공식 과목번호 아님)','canonicalSubjectCodePublished':False,'nativeSectionPublished':False,'academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','section':'','courseName':title,'professor':prof,'credits':None,'classification':'','classificationGroup':'','departments':[f'{grade}학년 '+x for x in cells[0]['departments']],'departmentCredits':{},'departmentClassifications':{},'departmentRemarks':{},'remarks':'청주교대 2026.9.4. 기준 공식 공개 교육과정 시간표 문서 항목입니다. 과목코드·개별 과목분반·학점·이수구분 미공개; 빈 코드·분반·미확인 학점 및 구분을 보존합니다. 제목의 A/B 등 원문 표기는 제목에 유지하며 공식 분반으로 분리하지 않았습니다. 내부 식별자는 문서 위치이며 공식 과목번호가 아닙니다. 교시1~10의 실제 시작·끝 시각 미확인으로 일정 저장 보류합니다. 공휴일·행사 보강은 해당 주 온라인, 실습 보강은 별도 주차/추가 온라인 운영을 공지하여 고정교시 일반반복으로 대체하지 않았습니다. 물리캠퍼스 및 전체 폐강 변경 미확인.','sourceSchedule':'; '.join(x['weekdayLabel']+' '+x['firstPeriodLabel']+'교시부터 원문rowSpan '+str(x['rowSpan']) for x in cells),'sourceClassroom':room,'scheduleStatus':'unrecognized','scheduleHoldReason':'현재 교시의 실제 시작/끝 시각, 실습/온라인 보강 개별 날짜·mode 미확인','schedules':[],'publicEducationCells':cells})
raw={'schemaVersion':2,'universityId':'cje','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-09-07','sourceUrl':'https://www.cje.ac.kr/web/board/brdList.do?menu_cd=000210','courses':items}
f='cje-unknown-2026-2.document-metadata-only-20261008.json';(p/f).write_text(json.dumps(raw,ensure_ascii=False,indent=2)+'\n');(p/'ambiguous-and-special-cells-held.json').write_text(json.dumps(holds,ensure_ascii=False,indent=2)+'\n')
a={'candidate':{'file':f,'sha256':hashlib.sha256((p/f).read_bytes()).hexdigest()},'documentMetadata':len(items),'heldSourceCells':len(holds),'scheduled':0,'completionClaim':False,'sourceTableCells':1728,'actualOfferingCountClaim':False,'actualClockKnown':False,'currentGuideSource':'https://www.cje.ac.kr/upload/contents/files/2026%EB%8C%80%ED%95%99%EC%83%9D%EB%90%98%EA%B8%B0.pdf','currentGuideOriginalSHA':hashlib.sha256(Path('/private/tmp/cje-guide2026.pdf').read_bytes()).hexdigest(),'currentGuideCalendarPage':7,'currentGuideAcademicPages':[27,28]}
(p/'metadata-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print(a)
