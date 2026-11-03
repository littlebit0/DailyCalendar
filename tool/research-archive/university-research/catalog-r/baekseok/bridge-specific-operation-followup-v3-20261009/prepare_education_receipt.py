import json,re,html,hashlib,datetime
from html.parser import HTMLParser
from pathlib import Path
R=Path(__file__).parent
URL='https://community.bu.ac.kr/dls2/9065/subview.do?enc=Zm5jdDF8QEB8JTJGYmJzJTJGZGxzMiUyRjIyMzQlMkY1OTM1OCUyRmFydGNsVmlldy5kbyUzRg%3D%3D'
b=Path('/private/tmp/bu-bridge-public.html').read_bytes();s=b.decode('utf8','replace');table=re.search(r'<table\b.*?</table>',s,re.S)[0]
class Table(HTMLParser):
 def __init__(self):super().__init__();self.rows=[];self.row=[];self.cell=None
 def handle_starttag(self,t,a):
  if t=='tr':self.row=[]
  if t in ['td','th']:self.cell=[]
 def handle_data(self,d):
  if self.cell is not None:self.cell.append(d)
 def handle_endtag(self,t):
  if t in ['td','th'] and self.cell is not None:self.row.append(re.sub(r'\s+',' ',''.join(self.cell)).strip());self.cell=None
  if t=='tr' and self.row:self.rows.append(self.row)
p=Table();p.feed(table);rows=[];department=''
for r in p.rows:
 if not r[0].isdigit():continue
 if len(r)==5:department=r[1];number,title,time,room=r[0],r[2],r[3],r[4]
 elif len(r)==4:number,title,time,room=r
 else:raise AssertionError(r)
 m=re.search(r'(2026)\s*년\s*(\d+)\s*월\s*(\d+)\s*일\s*\(([월화수목금토일])\).*?(\d{1,2}):(\d{2})\s*~\s*(\d{1,2}):(\d{2})',time)
 assert m,time
 date=f'{m[1]}-{int(m[2]):02d}-{int(m[3]):02d}'
 assert datetime.date.fromisoformat(date).isoweekday()=='월화수목금토일'.index(m[4])+1
 rows.append(dict(programNumber=number,department=department,programTitle=title,nativeOperatingTime=time,nativeRoom=room,date=date,weekday=datetime.date.fromisoformat(date).isoweekday(),startMinute=int(m[5])*60+int(m[6]),endMinute=int(m[7])*60+int(m[8]),sourceLocator='notice59358/program-row-'+number,officialCourseCodePublished=False,officialSectionPublished=False,professorPublished=False,physicalCampusVerified=False))
assert len(rows)==38
asset=Path('assets/timetable/baekseok-unknown-2026-2.json');data=json.loads(asset.read_text());links=[]
keys=[('31509','01','국제무역학원론'),('07730','02','글로벌무역실습'),('01947','01','비즈니스영어'),('02523','01','영어와영미문화'),('06770','01','영어회화'),('31318','01','일본관광콘텐츠브랜딩')]
for code,section,title in keys:
 c=next(c for c in data['courses'] if (c['courseCode'],c['section'])==(code,section))
 sourceRows=[r for r in rows if title in r['programTitle'].replace(' ','')]
 assert sourceRows,(code,title)
 nativeMatches=[x for x in data['courses'] if x['courseName'].replace(' ','').startswith(title) and x['sourceClassroom']==c['sourceClassroom'] and x['sourceSchedule']==c['sourceSchedule']]
 links.append(dict(nativeObject=c,programRows=sourceRows,potentialNativeSameTitleRoomPeriodCount=len(nativeMatches),officialJoinConfirmed=False,missingJoinFields=['official course code','native section','whole professor'],scope='Published program observation dates/HH range only; not proof of regular session end/break/whole semester',sourceClockGeneralizationAllowed=False))
receipt=dict(researchOnly=True,completionClaim=False,impossibleClaim=False,sourceUrl=URL,normalStatus=200,sourceResponseSha256=hashlib.sha256(b).hexdigest(),publishedDate='2026-09-18',sourceTitle='[자유전공학부] 2026학년도 1차 브릿지 프로그램 변경 안내',target='자유전공학부 재학생 전체',programPeriod=dict(startDate='2026-10-26',endDate='2026-11-20'),minimumRecognitionHours=6,educationalProgramRows=rows,courseSpecificPotentialCorrespondences=links,attachment=dict(actualLinkedUrl='https://community.bu.ac.kr/bbs/dls2/2234/58287/download.do',normalStatus=200,bytes=0,sha256='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',usable=False,noRetry=True),currentNativeAssetSha256=hashlib.sha256(asset.read_bytes()).hexdigest(),nativeCount=len(data['courses']),scheduledCount=sum(bool(c['schedules']) for c in data['courses']),dates=sum(len(c['schedules']) for c in data['courses']),newEligibleRegularSchedules=0,newCandidateModels=0)
(R/'current-bridge-education-and-native-comparison.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print('programrows',len(rows),'potentialjoinrows',sum(len(x['programRows']) for x in links),'new0')
