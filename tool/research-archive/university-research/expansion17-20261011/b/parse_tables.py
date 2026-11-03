"""Official PDF table extraction. Unknown/ambiguous operating conditions remain held."""
import pathlib,re,json,itertools,hashlib,collections
import pdfplumber
P=pathlib.Path(__file__).parent
DAY={x:i+1 for i,x in enumerate('월화수목금토일')}
SGY={1:(540,590),2:(595,645),3:(650,700),4:(715,765),5:(770,820),6:(825,875),7:(880,930),8:(935,985),9:(990,1040),10:(1060,1110),11:(1110,1160),12:(1160,1210),13:(1215,1265),14:(1265,1315),15:(1315,1365)}
UHS={i:(570+(i-1)*60,620+(i-1)*60) for i in range(1,16)}
SANG={i:(500+i*60,550+i*60) for i in range(10)}
SANG.update({i:(1100+(i-10)*50,1145+(i-10)*50) for i in range(10,16)})
def clean(t):return re.sub(r'\s+',' ',t or '').strip()
def compact(t):return re.sub(r'\s+','',t or '')
def course(u,s,r,code,name,section,prof,credit,kind,dept,raw,page):
 return {'sourceId':f'{u}/main/2026/{s}/{code}/{section}','universityId':u,'campus':'main','academicYear':2026,'semester':str(s),'courseCode':code,'courseName':clean(name),'section':section,'professor':clean(prof),'credits':float(credit),'classification':kind,'departments':[dept] if dept else [],'departmentClassifications':{dept:kind} if dept else {},'schedules':[],'sourceSchedule':raw,'sourceEducation':r,'sourcePage':page,'scheduleStatus':'unrecognized'}
def merge(courses):
 d={}
 for c in courses:
  key=c['sourceId']
  if key not in d:d[key]=c;continue
  a=d[key]
  if any(a[k]!=c[k] for k in ['courseName','professor','credits','schedules']):
   a['holdReason']='Conflicting published rows for the same course/section';a['schedules']=[];a['scheduleStatus']='unrecognized';a.setdefault('duplicateRows',[]).append(c['sourceEducation'])
  a['departments']=sorted(set(a['departments']+c['departments']));a['departmentClassifications'].update(c['departmentClassifications'])
 return list(d.values())
def emit(u,s,cs,source,published,terms,clockurl,extra=None):
 cs=merge(cs);out={'schemaVersion':1,'universityId':u,'campus':'main','academicYear':2026,'semester':str(s),'sourceUrl':source,'publishedDate':published,'retrievedDate':'2026-10-11','periodSourceUrl':clockurl,'termPeriodEvidence':terms,'sourceRowCount':sum(1+len(c.get('duplicateRows',[])) for c in cs),'courseScheduleStatusCounts':dict(collections.Counter(c['scheduleStatus'] for c in cs)),'courses':cs,'completionClaim':False}
 if extra:out.update(extra)
 (P/f'{u}-main-2026-{s}.candidate.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(u,s,len(cs),out['courseScheduleStatusCounts'])
def sch(day,ps,room,clock):
 if not ps or any(p not in clock for p in ps):raise ValueError('Unknown period')
 # One span per contiguous native period run; preserve official gap clocks.
 runs=[]
 for p in ps:
  if runs and p==runs[-1][-1]+1:runs[-1].append(p)
  else:runs.append([p])
 return [{'weekday':DAY[day],'startMinute':clock[g[0]][0],'endMinute':clock[g[-1]][1],'classroom':room} for g in runs]
def sgy(s):
 pdf=P/f'sungkyul-{"spring" if s==1 else "fall"}-timetable.pdf';guide=P/f'sungkyul-{"spring" if s==1 else "fall"}-guide.pdf';held={}
 with pdfplumber.open(guide) as d:
  for page in d.pages:
   if '집중수업 안내' not in (page.extract_text() or ''):continue
   for table in page.extract_tables():
    if table and len(table[0])==7 and compact(table[0][3])=='과목명':
     for r in table[1:]:held[(compact(r[3]),compact(r[2]))]=clean(r[6])
 cs=[]
 with pdfplumber.open(pdf) as d:
  for pi,page in enumerate(d.pages):
   text=page.extract_text() or '';department='';top=text.splitlines()[:6]
   department=next((clean(x) for x in top if '학과' in x or '학부' in x),'')
   for table in page.extract_tables():
    for r in table:
     if len(r)!=10 or not r[2] or not re.fullmatch(r'\d{5}',compact(r[2])):continue
     r=[clean(x) for x in r];code,section=r[2],r[3];raw=r[7];c=course('sungkyul',s,r,code,r[4],section,r[6],r[5],r[1],department,raw,pi+1)
     try:
      if (compact(r[4]),section) in held:raise ValueError('Concentrated teaching dates not published: '+held[(compact(r[4]),section)])
      if not raw:raise ValueError('No published scheduled teaching time')
      if not r[8]:raise ValueError('No published classroom')
      if any(k in r[8] for k in ['온라인','원격','사이버','OCU']):raise ValueError('Online delivery dates/synchronous clock not confirmed')
      matches=list(re.finditer(r'([월화수목금토일])(\d+)(?:\s*-\s*(\d+))?',raw))
      if not matches or re.sub(r'[\s,]','',re.sub(r'([월화수목금토일])(\d+)(?:\s*-\s*(\d+))?','',raw)):raise ValueError('Unrecognized official period notation')
      # A single room denotes all meetings. Multiple room lines need explicit pairing.
      room=compact(r[8]);roomlines=[clean(x) for x in (table[table.index(r)][8] or '').splitlines()] if False else []
      if len(set(re.findall(r'(?:기|중|재|학|영|체|성|신)\d{3}',room)))>1:raise ValueError('Multiple classrooms require per-meeting mapping')
      for m in matches:c['schedules']+=sch(m[1],list(range(int(m[2]),int(m[3] or m[2])+1)),r[8],SGY)
      c['scheduleStatus']='scheduled'
     except ValueError as e:c['holdReason']=str(e);c['schedules']=[]
     cs.append(c)
 emit('sungkyul',s,cs,'https://www.sungkyul.ac.kr/bbs/skukr/96/'+('26021' if s==1 else '26976')+'/download.do','' if s==1 else '2026-08-07',{'start':'2026-03-03' if s==1 else '2026-08-31','endInclusive':'2026-06-19' if s==1 else '2026-12-18','sourceUrl':'https://www.sungkyul.ac.kr/schdulmanage/skukr/3/yearSchdul.do?year=2026'},'https://www.sungkyul.ac.kr/bbs/skukr/96/'+('25840' if s==1 else '26953')+'/download.do',{'concentratedCourseConditions':[{'courseName':k[0],'section':k[1],'remarks':v} for k,v in held.items()]})
def splits(token):
 if not token:return [[]]
 result=[]
 for n in [1,2]:
  if len(token)<n or token[0]=='0':continue
  x=int(token[:n])
  if not 1<=x<=15:continue
  for rest in splits(token[n:]):
   if not rest or rest[0]==x+1:result.append([x]+rest)
 return result
def uhs(s):
 pdf=P/f'hyupsung-{"spring" if s==1 else "fall"}-timetable.pdf';cs=[]
 with pdfplumber.open(pdf) as d:
  for pi,page in enumerate(d.pages):
   department=next((clean(x).split('(')[0] for x in (page.extract_text() or '').splitlines()[:8] if re.search(r'(학과|학부)',x) and '개설시간표' not in x), '');
   for table in page.extract_tables():
    for r in table:
     if len(r)!=10 or not r[2] or not re.fullmatch(r'\d{6}',compact(r[2])):continue
     raw=compact(r[9]);rr=[clean(x) for x in r];c=course('hyupsung',s,rr,compact(r[2]),r[4],compact(r[3]),r[8],r[5],compact(r[1]),department,clean(r[9]),pi+1)
     try:
      matches=list(re.finditer(r'([월화수목금토일])(\d+)\(([^()]*)\)',raw))
      if not matches or re.sub(r'[\s,]','',re.sub(r'([월화수목금토일])(\d+)\(([^()]*)\)','',raw)):raise ValueError('Unrecognized official period/room notation')
      hours=int(float(r[6]))+int(float(r[7]));choices=[splits(m[2]) for m in matches];options=[x for x in itertools.product(*choices) if sum(map(len,x))==hours]
      if len(options)!=1:raise ValueError('Concatenated native periods not uniquely resolved by published contact hours')
      for m,ps in zip(matches,options[0]):
       if not m[3] or any(x in m[3] for x in ['OCU','사이버','온라인','원격']):raise ValueError('Unconfirmed online teaching dates')
       c['schedules']+=sch(m[1],ps,m[3],UHS)
      c['scheduleStatus']='scheduled'
     except (ValueError,TypeError) as e:c['holdReason']=str(e);c['schedules']=[]
     cs.append(c)
 emit('hyupsung',s,cs,'https://portal.uhs.ac.kr/ctt/cust/fd?b=14&p='+('58681' if s==1 else '99107')+'&fs=1','2026-01-22' if s==1 else '2026-08-03',{'start':'2026-03-03' if s==1 else '2026-09-01','endInclusive':'2026-06-22' if s==1 else '2026-12-21','sourceUrl':'https://www.uhs.ac.kr/schdulmanage/uhs/1/yearSchdul.do?year=2026'},'https://www.uhs.ac.kr/uhs/126/subview.do')
if __name__=='__main__':
 for s in [1,2]:sgy(s);uhs(s)
