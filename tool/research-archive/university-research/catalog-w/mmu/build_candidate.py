"""Use actual public grid cells as document references, never invented codes."""
import collections,datetime as dt,hashlib,json,re
from pathlib import Path
R=Path(__file__).parent
read=lambda f:json.loads((R/f).read_text())
source=read('current-grid-education.json');closed=read('closure-candidate-education.json')['rows'];cal=read('current-calendar-education.json')['rows'];clock=read('current-clock-education.json')
assert [x for x in cal if x['title']=='제2학기 중간시험'][0]['frdt']=='2026-10-26'
assert [x for x in cal if x['title']=='제2학기 학기말시험'][0]['frdt']=='2026-12-14'
clocks={}
for p,t in enumerate(clock['rows'][1][1:],1):
 a,b=t.split(' ~ ')
 minute=lambda t:int(t[:2])*60+int(t[3:])
 clocks[p]=(minute(a),minute(b));assert clocks[p][1]-clocks[p][0]==50
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
dates=[];day=dt.date(2026,9,1)
while day<=dt.date(2026,12,13):
 if day.isoformat() not in holidays and not dt.date(2026,10,26)<=day<=dt.date(2026,10,30): dates.append(day)
 day+=dt.timedelta(days=1)
result=[];holds=[]
for row in source['rows']:
 groups=collections.defaultdict(list)
 for s in row['slots']:groups[s['courseName']].append(s)
 for title,slots in groups.items():
  professors=list(dict.fromkeys(s['professor'] for s in slots));closedRows=[x for x in closed if all(str(x[k]).strip()==str(row[k]).strip() for k in ['department','yearLevel','classGroup']) and str(x['courseName']).strip()==title and str(x['professor']).strip() in professors]
  id=f"{source['url']}#sheet=%EC%9E%90%EB%A3%8C&row={row['sourceRow']}&column={slots[0]['sourceColumn']}"
  hold=''
  if closedRows:hold='공식 폐강 예정 목록과 일치하여 최종 개설 여부 확인 전 일정 생성을 보류합니다.'
  if any(int(s['period'][1:]) not in clocks for s in slots):hold='공개 자료의 0교시 실제 시각을 확인하지 못했습니다.'
  if any(not s['room'] or not s['professor'] for s in slots):hold='공개 강의실 또는 담당교수 정보가 없습니다.'
  if row['department'].strip()=='모듈형과정':hold='모듈형 과정의 개별 운영 날짜를 확인하지 못했습니다.'
  if any(t in title for t in ['승선실습','현장실습','인턴']):hold='실습 현장의 개별 운영 날짜와 장소를 확인하지 못했습니다.'
  meetings=[]
  if not hold:
   for s in slots:
    weekday='월화수목금토'.index(s['period'][0])+1;a,b=clocks[int(s['period'][1:])]
    for d in dates:
     if d.weekday()+1==weekday:meetings.append({'weekday':weekday,'startMinute':a,'endMinute':b,'classroom':s['room'],'date':d.isoformat()})
  dept=str(row['department']).strip()
  note=f"공개 시간표의 소속 {dept}, 대상 {row['yearLevel']}학년 {row['classGroup']}반입니다. 학년 반 편성은 과목의 공식 분반으로 확정하지 않았습니다. 과목코드·과목별 분반·학점·이수구분은 미공개입니다. 내부 참조는 실제 공개 문서 위치이며 수강신청 코드가 아닙니다. 공개 예약 계획, 실제 운영/출석 미확인. 원문 교시와 강의실·교수: "+'; '.join(f"{s['period']} {s['sourceRoomProfessor']}" for s in slots)
  note+=' 중간시험 10/26~30, 학기말시험12/14~18 및 공휴일은 일반 예약에서 제외하며 개별 시험/보강은 미확인입니다. 최종 폐강·학사행정 변경 미확인. '+hold
  if title in ['명작고전읽기','테니스']:note+=' 현재 수강신청 안내: 1학년만 신청 가능.'
  if dept=='해양경찰학부' and title=='리더십및팀워크':note+=' 현재 수강신청 안내: A반(A반,B반 수강 가능), B반(B반,C반 수강 가능).'
  result.append({'sourceId':id,'campus':'unknown','academicYear':2026,'semester':'2','courseCode':'','courseName':title,'section':'','professor':', '.join(professors),'credits':None,'classification':'','departmentCredits':{},'departmentClassifications':{dept:''},'departments':[dept],'departmentRemarks':{dept:note},'sourceSchedule':','.join(s['period'] for s in slots),'sourceClassroom':' / '.join(dict.fromkeys(s['room'] for s in slots)),'scheduleStatus':'scheduled' if meetings else 'unrecognized','period':{'startDate':'2026-09-01','endDate':'2026-12-18'},'schedules':meetings,'referenceKind':'internalDocumentLocator','sourceEducation':{'sourceRow':row['sourceRow'],'department':row['department'],'yearLevel':row['yearLevel'],'classGroup':row['classGroup'],'slots':slots,'closureCandidates':closedRows},'actualAttendanceConfirmed':False,'heldReason':hold})
  if hold:holds.append({'sourceId':id,'reason':hold})
assert len(result)==634
assert len({c['sourceId'] for c in result})==634
text=json.dumps(result,ensure_ascii=False)
assert not re.search(r'\b\d{2,3}[-)]\d{3,4}-\d{4}\b|[\w.+-]+@[\w.-]+\.[a-z]{2,}',text)
d={'schemaVersion':2,'universityId':'mmu','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-08-31','sourceUrl':'https://www.mmu.ac.kr/main/board/302/1/read/89163','researchOnly':True,'wholeOperatingVerified':False,'completionClaim':False,'courses':result}
p=R/'mmu-unknown-2026-2.published-grid-partial-v1.json';p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
audit={'candidate':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'courses':len(result),'scheduled':sum(bool(c['schedules']) for c in result),'meetings':sum(len(c['schedules']) for c in result),'held':holds,'completionClaim':False};(R/'candidate-audit-v1.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print({k:v for k,v in audit.items() if k!='held'})
