from pathlib import Path
import json,pdfplumber,re,hashlib,datetime
prior=Path('work/university-research/catalog-e/nsu-current-20261008');p=Path('work/university-research/catalog-e/nsu-regular-partial-20261008');p.mkdir(exist_ok=True)
def save(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def norm(t):return re.sub(r'\s+','',t or '')
clock=json.loads(Path('work/university-research/catalog-e/nsu-clock-evidence.json').read_text());save('nsu-clock-evidence.json',clock)
closures=json.loads((prior/'closure-2026-2-education.json').read_text());save('closure-education.json',closures)
inputs=json.loads((prior/'department-timetable-educational-tables.json').read_text());receipts=[];courses=[]
excluded={'2026-09-14':'기독인 연합예배 실제 일반수업 운영 미확인 보류','2026-09-24':'추석연휴','2026-09-25':'추석연휴','2026-09-29':'복음성가경연대회 실제 일반수업 운영 미확인 보류'}
start=datetime.date(2026,9,11);end=datetime.date(2026,10,2)
for entry in inputs:
 file=Path(entry['sourceFile']);page=pdfplumber.open(file).pages[entry['page']-1];table=page.find_tables()[0];extracted=table.extract();assert extracted==entry['tables'][0]
 cells=[];groups={};xs=table.rows[0].cells
 def header(c,cy):
  x=(xs[c][0]+xs[c][2])/2
  boxes=[b for b in table.cells if b[0]<x<b[2] and b[1]<cy<b[3]]
  assert len(boxes)==1,(c,cy,boxes)
  b=boxes[0];return {'bbox':list(b),'text':page.crop(b).extract_text()}
 for row in range(2,len(extracted)):
  for col in range(3,17):
   text=extracted[row][col]
   if not text:continue
   b=table.rows[row].cells[col];visual=page.crop(b).extract_text();assert norm(text)==norm(visual),(text,visual)
   cy=(b[1]+b[3])/2;gh=header(0,cy);dh=header(2,cy);day=next(k for k,v in enumerate(['월','화','수','목','금'],1) if v in norm(dh['text']));grade=norm(gh['text']);period=col-2
   parts=re.fullmatch(r'(.+?)-(\d{2})\(([^()]+)\)\((\d+)\)',norm(text));assert parts,text
   title,section,prof,room=parts.groups()
   # 교수 공백은 실제 괄호 영역 표기를 보존한다.
   profOriginal=re.findall(r'\(([^()]+)\)',text)[0].replace('\n',' ').strip()
   record={'row':row,'column':col,'text':text,'pdfBbox':list(b),'independentCropText':visual,'gradeHeader':gh,'weekdayHeader':dh,'grade':grade,'weekday':day,'period':period,'room':room,'sourceClockText':extracted[1][col]}
   cells.append(record);groups.setdefault((grade,title,section,profOriginal),[]).append(record)
 receipts.append({'department':entry['department'],'sourceNoticeId':102040 if entry['department']=='영어과' else 102924,'sourceFileName':file.name,'sourceSHA256':hashlib.sha256(file.read_bytes()).hexdigest(),'pdfPage':entry['page'],'pdfWidth':page.width,'pdfHeight':page.height,'tableBbox':list(table.bbox),'tableRows':extracted,'cells':cells})
 for (grade,title,section,prof),rows in groups.items():
  closure=[x for x in closures['rows'] if norm(x['courseName'])==title and x['section']==section and norm(x['professor'])==norm(prof)]
  special=any(x in title for x in ['현장실습','동승실습','임상실습'])
  plans=[]
  if not special and not closure:
   d=start
   while d<=end:
    if d.isoformat() not in excluded:
     for r in rows:
      if d.isoweekday()==r['weekday']:
       c=next(x for x in clock['periods'] if x['period']==r['period'])
       plans.append({'date':d.isoformat(),'weekday':d.isoweekday(),'startMinute':c['startMinutes'],'endMinute':c['endMinutes'],'classroom':r['room'],'sourceRow':r['row'],'sourceColumn':r['column']})
    d+=datetime.timedelta(days=1)
  note='남서울대 2026-2 공식 공개 학과 시간표의 초기 기간 부분 예약입니다. 원문 실제 01/02 과목 분반을 보존하며 과목코드·학점·이수구분 미공개(빈 코드/구분, 학점 미확인). 내부 식별자는 공식 과목번호 아닌 PDF 문서 셀 위치입니다. 중앙 수강편람의 실제 50분/45분 교시 시작·끝을 그대로 사용하며 각 교시 강의실을 따로 보존했습니다. 캠퍼스 명칭 미공개. 자체학기8/31개강·12/21방학과 편람16주12/19까지를 확인했으나 개별 중간/기말시험·휴일 보강·최종 변경 운영 날짜는 미공개로 전체 학기 반복을 생성하지 않습니다. 공개 수정공지9/10 이후9/11~10/2만 예약하고 추석휴일 및9/14연합예배·9/29경연대회 수업운영 불확실일을 제외했습니다. 9/7 기준 폐강 목록104행은 전체 폐강 합집합 보장이 아니며 현재 부분 문서와 정확 제목/분반/교수 매치만 확인했습니다. 개인 실제 수강 및 후반 시험·보강/집중/외부실습 계획은 미확인입니다.'
  if special:note+=' 이 원문 항목은 현장·임상·동승실습 별도 실제 운영 미확인으로 일정 저장을 보류합니다.'
  noticeId=102040 if entry['department']=='영어과' else 102924
  notice=json.loads((prior/f'notice-{noticeId}.json').read_text())
  fileReceipt=next(x for x in json.loads((prior/'acquired-file-manifest.json').read_text()) if x.get('file')==file.name)
  sourceId=f'nsu-document{102040 if entry["department"]=="영어과" else 102924}-r{rows[0]["row"]}c{rows[0]["column"]}'
  obj={'sourceId':sourceId,'sourceNoticeId':noticeId,'sourcePublishedDate':notice['registered_date'].split(' ')[0],'sourceUrl':fileReceipt['url'],'referenceKind':'공개 PDF 문서 셀 위치(공식 과목번호 아님)','canonicalSubjectCodePublished':False,'nativeSectionPublished':True,'academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','section':section,'courseName':title,'professor':prof,'credits':None,'classification':'','classificationGroup':'','departments':[entry['department']+' '+grade+'학년'],'departmentCredits':{},'departmentClassifications':{},'departmentRemarks':{},'remarks':note,'sourceSchedule':'; '.join(f'{r["weekday"]}요일 {r["period"]}교시' for r in rows),'sourceClassroom':'; '.join(dict.fromkeys(r['room'] for r in rows)),'publicEducationCells':rows,'scheduleStatus':'scheduled' if plans else 'unrecognized','schedules':plans,'closureExactTitleSectionTeacherMatches':closure}
  if plans:obj['period']={'startDate':str(start),'endDate':str(end)}
  else:obj['scheduleHoldReason']='현장·임상·동승실습 별도 운영 날짜/조건 미확인' if special else '공개 폐강 동일 제목·분반·강사 매치로 보류'
  courses.append(obj)
save('pdf-independent-coordinate-education.json',receipts)
f='nsu-unknown-2026-2.regular-partial-20261008.json';save(f,{'schemaVersion':2,'universityId':'nsu','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-09-10','sourceUrl':'https://nsu.ac.kr/?m1=home','courses':courses})
a={'candidate':{'file':f,'sha256':hashlib.sha256((p/f).read_bytes()).hexdigest()},'metadata':len(courses),'scheduled':sum(bool(c['schedules']) for c in courses),'datedPlans':sum(len(c['schedules']) for c in courses),'held':sum(not c['schedules'] for c in courses),'start':str(start),'end':str(end),'excludedDates':excluded,'completionClaim':False,'fullSemesterDatePlansClaim':False};save('partial-audit.json',a)
with pdfplumber.open('/private/tmp/nsu-current-guide.pdf') as pdf:
 calendar=''.join(norm(pdf.pages[i].extract_text()) for i in [2,3])
 for excerpt in ['31(월)2학기개강일','24(목)~26(토)추석연휴','14(월)기독인연합예배','29(화)복음성가경연대회','21(월)동계방학','16주13141516171819']:assert excerpt in calendar
 save('own-guide-clock-calendar-education.json',{'sourceUrl':clock['sourcePdf'],'sha256':hashlib.sha256(Path('/private/tmp/nsu-current-guide.pdf').read_bytes()).hexdigest(),'pdfPageCount':len(pdf.pages),'clockPage':12,'printedClockPage':10,'clockTable':pdf.pages[11].extract_tables()[0],'educationalCalendarDirectExcerpts':['31(월)2학기개강일','24(목)~26(토)추석연휴','14(월)기독인연합예배','29(화)복음성가경연대회','21(월)동계방학','16주13141516171819'],'printedCalendarPages':[1,2],'consortiumCalendarUsed':False,'midtermFinalIndividualDatesVerified':False})
print(a)
