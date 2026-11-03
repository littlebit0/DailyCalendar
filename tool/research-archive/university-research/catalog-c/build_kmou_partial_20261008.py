from pathlib import Path
import json,re,datetime,hashlib,openpyxl
p=Path('work/university-research/catalog-c/kmou-current-20261008');p.mkdir(exist_ok=True)
def save(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
tables=json.loads(Path('/private/tmp/kmou-eee2026-2-tables.json').read_text());save('source-educational-tables.json',{'sourceUrl':'https://www.kmou.ac.kr/common/nttFileDownload.do?fileKey=3efe931e53f4baefff96b42ae00c0a36','sha256':hashlib.sha256(Path('/private/tmp/kmou-eee2026-2.pdf').read_bytes()).hexdigest(),'tables':tables,'visualVerified':True,'afternoonNotation':'교시5~10은 원문 순서 12:00 다음 1:00~6:50의 오후 12시간 표기; 13~18시로 변환'})
closures=[]
for r in list(openpyxl.load_workbook('/private/tmp/kmou-closure-final.xlsx',data_only=True).active.values)[4:]:
 if r[2] and r[3]:closures.append({'classification':r[1],'courseCode':str(r[2]),'courseName':r[3],'section':str(r[5]),'creditsTheoryPractice':r[6],'department':r[7],'professor':r[8]})
save('closure-education.json',{'sourceUrl':'https://www.kmou.ac.kr/common/nttFileDownload.do?fileKey=d129361bf948e138f8562631edd3d12e','sourceSha256':hashlib.sha256(Path('/private/tmp/kmou-closure-final.xlsx').read_bytes()).hexdigest(),'courses':closures})
items=[];held=[]
excluded={'2026-09-24':'추석연휴','2026-09-25':'추석','2026-10-05':'개천절 대체휴일','2026-10-09':'한글날'}
start=datetime.date(2026,9,15);end=datetime.date(2026,10,19)
for grade,table in enumerate(tables,1):
 groups={}
 for period,row in enumerate(table[1:],1):
  for weekday,text in enumerate(row[1:],1):
   if not text:continue
   r={'table':grade-1,'row':period,'column':weekday,'text':text,'clockText':row[0]}
   lines=text.splitlines()
   if len(lines)<3 or not re.fullmatch(r'B1-\d+',lines[-1]) or any(x in text for x in ['실습','선형대수학','(선택)','교수님별']):
    held.append({**r,'reason':'강사·강의실·분반·별도 운영 조건 불완전/복수/특수활동 원문 항목 보류'});continue
   title=''.join(lines[:-2]);prof=lines[-2].strip();room=lines[-1]
   if lines[-2]=='로미정':
    # 원문 시각 확인: 줄바꿈이 제목 '디지털논리회로'와 '미정'을 같은 추출행에 붙임.
    title+='로';prof='미정'
   groups.setdefault((title,prof),[]).append({**r,'room':room,'professor':prof,'weekday':weekday,'period':period})
 for (title,prof),cells in groups.items():
  match=[c for c in closures if re.sub(r'\s+','',c['courseName'])==re.sub(r'\s+','',title)]
  plans=[]
  if not match:
   day=start
   while day<=end:
    if day.isoformat() not in excluded:
     for r in cells:
      if day.isoweekday()==r['weekday']:
       nums=list(map(int,re.findall(r'\d+',r['clockText'])))[1:];a=nums[0]*60+nums[1];b=nums[2]*60+nums[3]
       if r['period']>=5:a+=720;b+=720
       plans.append({'date':day.isoformat(),'weekday':day.isoweekday(),'startMinute':a,'endMinute':b,'classroom':r['room'],'sourceTable':r['table'],'sourceRow':r['row'],'sourceColumn':r['column']})
    day+=datetime.timedelta(days=1)
  sourceId=f'kmou-document3efe931e-table{grade}-r{cells[0]["row"]}c{cells[0]["column"]}'
  items.append({'sourceId':sourceId,'referenceKind':'공개 문서 표 셀 내부 위치(공식 과목번호 아님)','canonicalSubjectCodePublished':False,'nativeSectionPublished':False,'academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','section':'','courseName':title,'professor':prof,'credits':None,'classification':'','classificationGroup':'','departments':[f'전기전자공학전공 {grade}학년'],'departmentCredits':{},'departmentClassifications':{},'departmentRemarks':{},'publicEducationCells':cells,'remarks':'국립한국해양대 전기전자공학전공 2026-2 공식 공개 확인용 시간표 기준 부분 예약입니다. 최종 시간·장소는 종합정보시스템 확인이 필요하고 강의실 등 변경 가능성을 원문이 안내합니다. 과목코드·개별 분반·학점·구분 미공개(빈 코드/분반/구분, 학점 미확인), 내부 식별자는 공식 과목번호 아닌 문서 표 위치입니다. 캠퍼스 명칭 미공개. 최종 폐강 공지 후 9/15부터 중간시험 전 10/19까지만 공개 요일·교시 시작/끝·방을 보존합니다. 법정 휴일 제외, 중간시험·보강·후반 변경 및 별도 실습 계획은 예약하지 않았습니다. 원문 미정 강사는 미정 그대로이며 개인 실제 수강·최종 변경 확인은 수행하지 않았습니다.','sourceSchedule':'; '.join(f'{r["weekday"]}요일 {r["clockText"]}' for r in cells),'sourceClassroom':'; '.join(dict.fromkeys(r['room'] for r in cells)),'period':{'startDate':str(start),'endDate':str(end)},'scheduleStatus':'scheduled' if plans else 'unrecognized','schedules':plans,'closureTitleMatches':match})
f='kmou-unknown-2026-2.published-partial-20261008.json';save(f,{'schemaVersion':2,'universityId':'kmou','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-07-24','sourceUrl':'https://www.kmou.ac.kr/eee/na/ntt/selectNttInfo.do?currPage=1&mi=146&nttSn=10377209','courses':items})
save('held-educational-cells.json',held)
a={'candidate':{'file':f,'sha256':hashlib.sha256((p/f).read_bytes()).hexdigest()},'metadata':len(items),'scheduled':sum(bool(c['schedules']) for c in items),'datedPlans':sum(len(c['schedules']) for c in items),'heldCells':len(held),'finalClosureRows':len(closures),'start':str(start),'end':str(end),'excludedDates':excluded,'completionClaim':False,'nativeOfferingCountClaim':False,'currentCatalogAssetBeforeResearch':False};save('partial-audit.json',a);print(a)
