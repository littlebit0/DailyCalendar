"""Actual published medical dated grid, no title-to-official-code attribution."""
import collections,datetime,hashlib,json,pathlib,re,sys
sys.path.insert(0,'/private/tmp/daily-catalog-xls-read');import xlrd
D=pathlib.Path(__file__).parent/'jbnu-current-20261008'
def write(f,x):(D/f).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
raw=pathlib.Path('/private/tmp/jbnu-current-med.xls');w=xlrd.open_workbook(raw,formatting_info=True)
normalize=lambda s:re.sub(r'\s+','',s)
room={1:'의과대학 4호관 3강의실',2:'의과대학 4호관 2강의실',3:'의과대학 4호관 2강의실',4:'의과대학 4호관 1강의실'}
courses=[];receipts=[];unmatched=[];excluded=[]
for grade,name in enumerate(['2026학년도 2학기(1학년)','2학년','3학년','4학년'],1):
 s=w.sheet_by_name(name);subjects=[];clock={}
 for c in range(3,13):
  t=str(s.cell_value(0,c));m=re.fullmatch(r'(\d+)교시\s*(\d{1,2}):(\d{2})~(\d{1,2}):(\d{2})',t)
  assert m,(name,c,t)
  clock[c]={'sourceHeaderCell':xlrd.formula.cellname(0,c),'sourceText':t,'nativePeriod':int(m[1]),'startMinute':int(m[2])*60+int(m[3]),'endMinute':int(m[4])*60+int(m[5])}
 for r in range(1,20):
  title=str(s.cell_value(r,14)).strip();credit=s.cell_value(r,16)
  if title and isinstance(credit,(int,float)) and '합계' not in title:
   subjects.append({'row':r+1,'courseName':title,'professor':str(s.cell_value(r,15)).strip(),'credits':credit,'theoryHours':s.cell_value(r,18),'practiceHours':s.cell_value(r,19),'nativeRemark':str(s.cell_value(r,21)).strip(),'nativeClassificationAggregate':'전필합계'})
 assert any(str(s.cell_value(r,14)).strip()=='전필합계' for r in range(1,20))
 notes=[str(s.cell_value(r,14)).strip() for r in range(1,min(24,s.nrows)) if str(s.cell_value(r,14)).strip().startswith(('※','-'))]
 byname={normalize(e['courseName']):e for e in subjects};cells=collections.defaultdict(list)
 for r in range(1,s.nrows):
  dcell=s.cell(r,1)
  if dcell.ctype not in [xlrd.XL_CELL_NUMBER,xlrd.XL_CELL_DATE]:continue
  try:day=xlrd.xldate_as_datetime(dcell.value,w.datemode).date()
  except ValueError:continue
  if day.year not in [2026,2027]:continue
  printed=str(s.cell_value(r,2)).strip()
  if printed not in list('월화수목금토일'):continue
  assert printed=='월화수목금토일'[day.weekday()]
  for c,h in clock.items():
   sourceRow,sourceColumn=r,c;value=str(s.cell_value(r,c)).strip();merged=False
   if not value:
    for r1,r2,c1,c2 in s.merged_cells:
     if r1<=r<r2 and c1<=c<c2:
      value=str(s.cell_value(r1,c1)).strip();sourceRow,sourceColumn=r1,c1;merged=bool(value);break
   if not value:continue
   norm=normalize(value);key=next((k for k in sorted(byname,key=len,reverse=True) if norm==k or norm.startswith(k+'-') or norm.startswith(k+'(')),None)
   if not key:
    # Educational unmatched text only; no contacts or roster information is stored.
    if not re.search('@|[0-9]{3}-[0-9]{3,4}-[0-9]{4}',value):unmatched.append({'sheet':name,'cell':xlrd.formula.cellname(r,c),'date':str(day),'sourceText':value})
    continue
   xf=w.xf_list[s.cell_xf_index(sourceRow,sourceColumn)];rgb=w.colour_map.get(xf.background.pattern_colour_index)
   e={'cell':xlrd.formula.cellname(r,c),'sourceCell':xlrd.formula.cellname(sourceRow,sourceColumn),'sourceText':value,'declaredMergedCellInherited':merged,'date':str(day),'weekday':day.isoweekday(),'printedWeekday':printed,'nativePeriod':h['nativePeriod'],'originalStartMinute':h['startMinute'],'originalEndMinute':h['endMinute'],'fillRgb':list(rgb) if rgb else None}
   cells[key].append(e)
 for e in subjects:
  key=normalize(e['courseName']);src=cells[key];reasons=[]
  if '문제바탕학습' in e['courseName']:reasons.append('published17:00start overrides17:30 grid; exact end not published')
  clinical=grade==3 and '실습' in e['courseName']
  if clinical:reasons.append('clinical rotation site/room not published per course; grade room applies Friday lecture only')
  plans=[]
  for m in src:
   reason=''
   if m['fillRgb']==[255,0,0]:reason='source says red fill is formative assessment'
   if m['fillRgb']==[255,128,128]:reason='pink/red assessment distinction not resolved; preserve as held cell'
   if re.search('시험|평가|퀴즈',m['sourceText']):reason='explicit assessment cell'
   if reason:excluded.append({'sheet':name,'courseName':e['courseName'],**m,'reason':reason});continue
   if not reasons:plans.append({'date':m['date'],'weekday':m['weekday'],'startMinute':m['originalStartMinute'],'endMinute':m['originalEndMinute'],'classroom':room[grade],'sourceCell':m['cell']})
  if not plans and not reasons:reasons.append('no unambiguous nonassessment dated lecture cells')
  sourceId=f'jbnu-med-document357005-grade{grade}-summaryrow{e["row"]}'
  # Scope is the exact printed dated plan bounds, never fixed institutional regular-term dates.
  bounds=sorted({m['date'] for m in src});period={'startDate':bounds[0],'endDate':bounds[-1]} if bounds else {'startDate':'2026-09-01','endDate':'2027-01-01'}
  remark='2026-08-19 공식 의학과 최종 시간표의 날짜별 계획입니다. 원문에 과목코드·분반이 없어 빈값을 보존했습니다. 문서 내부 식별자는 앱 자료 추적용이며 공식 과목번호가 아닙니다. 전체 대학·실시간 변경 완전성 미확인. 실제 날짜·숫자교시 clock 사용, 대학A/B교시로 변환하지 않았습니다. 빨간 형성평가 및 구분미확인 분홍cell은 수업 일정에서 제외했습니다. 학년별 공식 강의실배정 사용; 물리캠퍼스는 해당 자료에 미공개입니다. 원문비고: '+e['nativeRemark']+'; 학년별주의: '+'; '.join(notes)
  if grade in [1,2]:remark+='; 안내문 종강예정2027.12.31(목)은 연도/요일 불일치 원문으로 유지하며 정정하지 않았습니다. 저장기간은 각 과목의 명시된 datedcell 계획범위입니다.'
  if reasons:remark+='; 일정미생성: '+'; '.join(reasons)
  c={'sourceId':sourceId,'referenceKind':'문서 내부 항목 위치(공식 과목번호 아님)','canonicalSubjectCodePublished':False,'nativeSectionPublished':False,'academicYear':2026,'semester':'2','campus':'unknown','nativeCampus':'unknown','courseCode':'','section':'','courseName':e['courseName'],'professor':e['professor'],'credits':e['credits'],'classification':'전필','classificationGroup':'전공','departments':['의학과 '+str(grade)+'학년'],'departmentCredits':{'의학과 '+str(grade)+'학년':e['credits']},'departmentClassifications':{},'departmentRemarks':{},'remarks':remark,'sourceSchedule':e['nativeRemark'],'sourceClassroom':room[grade] if not clinical else '', 'scheduleStatus':'scheduled' if plans else 'unrecognized','period':period,'schedules':plans,'publishedDocumentMetadata':e,'publicDatedCells':src,'sourceGrade':grade,'holds':reasons}
  courses.append(c)
 receipts.append({'sheet':name,'grade':grade,'sourceClockHeader':list(clock.values()),'subjects':subjects,'notes':notes,'sourceDateBounds':sorted({x['date'] for rs in cells.values() for x in rs})})
write('medical-document-educational-receipt.json',{'noticeUrl':'https://med.jbnu.ac.kr/bbs/med/1901/398340/artclView.do','documentUrl':'https://med.jbnu.ac.kr/bbs/med/1901/357005/download.do','originalSha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'sourceSheets':receipts,'classroomAssignment':room,'classroomSource':'same current official notice section2, per grade; third-grade Friday5~10 lecture room only','rawRetained':False,'nativeCodeOrSectionPublished':False,'studentCountsAndPersonalGroupsExcluded':True})
write('medical-held-assessment-cells.json',excluded);write('medical-unmatched-education-cells.json',unmatched)
f='jbnu-unknown-medical-document-2026-2.published-partial-20261008.json';write(f,{'schemaVersion':2,'universityId':'jbnu','campus':'unknown','campusName':'캠퍼스 미확인(의학과 공개 문서)','academicYear':2026,'semester':'2','publishedDate':'2026-08-19','sourceUrl':'https://med.jbnu.ac.kr/bbs/med/1901/398340/artclView.do','courses':courses})
write('medical-candidate-audit.json',{'completionClaim':False,'candidate':{'file':f,'sha256':hashlib.sha256((D/f).read_bytes()).hexdigest()},'classes':len(courses),'scheduledClasses':sum(bool(c['schedules']) for c in courses),'datedPlans':sum(len(c['schedules']) for c in courses),'sourceDatedCells':sum(len(c['publicDatedCells']) for c in courses),'assessmentOrAmbiguousCellsExcluded':len(excluded),'unmatchedCells':len(unmatched),'holds':[{'sourceId':c['sourceId'],'title':c['courseName'],'reasons':c['holds']} for c in courses if not c['schedules']],'officialCodeInvented':False,'titleJoinToNativeCatalog':False,'productionChanged':False})
print(json.loads((D/'medical-candidate-audit.json').read_text())|{'holds':'see audit'})
