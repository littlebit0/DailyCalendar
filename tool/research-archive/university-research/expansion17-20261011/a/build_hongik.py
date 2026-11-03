"""Official current public catalogue; native campus rules, clocks, closures, exact intensive dates."""
import pathlib,json,re,hashlib,openpyxl
from bs4 import BeautifulSoup
P=pathlib.Path(__file__).parent
def rows(path):
 doc=BeautifulSoup(path.read_text(),'html.parser')
 return [r.find_all('td',recursive=False)for r in doc.select('tr')if len(r.find_all('td',recursive=False))==14]
def txt(c):return c.get_text(' ',strip=True)
clockurl='https://edu.hongik.ac.kr/edu/0401.do?articleNo=148398&mode=view'
clocktext=BeautifulSoup((P/'hongik-clock-guide.html').read_text(),'html.parser').get_text(' ',strip=True)
slots={int(n):(int(h)*60+int(m),int(eh)*60+int(em))for n,h,m,eh,em in re.findall(r'(\d+)\((\d+):(\d+)~(\d+):(\d+)\)',clocktext)}
assert len(slots)==13
campustext=BeautifulSoup((P/'hongik-campus-code-guide.html').read_text(),'html.parser').get_text(' ',strip=True)
assert '001 - 499 : 서울캠퍼스 강좌' in campustext and '500 - 999 : 세종캠퍼스 강좌' in campustext
closed={(str(r[3]),str(r[4]))for r in list(openpyxl.load_workbook(P/'hongik-closed-seoul.xlsx',data_only=True).active.values)[2:]if r[1]==2026 and r[2]==2}
closed.update(re.findall(r'^\d+\s+(\d{6})\s+(\d+)\b',(P/'hongik-closed-sejong.txt').read_text(),re.M))
syllabi=json.loads((P/'hongik-syllabi-texts.json').read_text()) if (P/'hongik-syllabi-texts.json').exists() else {}
syllabusLedger=[]
for nativeKey,report in syllabi.items():
 ts=report['texts'];code,section=nativeKey.split('-');nativeCode=ts[ts.index('Course Code')+1];found=re.fullmatch(r'(\d{6})-\s*(\d+)',nativeCode)
 assert found and found[1]==code and int(found[2])==int(section),nativeKey
 assert ts[ts.index('Year - Semester')+1]=='2026 - 2',nativeKey
 syllabusLedger.append({'courseCodeAndSection':nativeKey,'nativeCode':nativeCode,'nativeYearSemester':'2026 - 2','httpStatus':report['status'],'file':report['file'],'sha256':hashlib.sha256((P/report['file']).read_bytes()).hexdigest(),'publishedDate':ts[ts.index('Date of Issue')+1] if 'Date of Issue'in ts else '','purpose':'intensive section proof'if nativeKey.startswith(('106603-','106611-','106612-','106829-'))else'compact12 actual native teaching hours'})
(P/'hongik-syllabus-acquisition-ledger.json').write_text(json.dumps(syllabusLedger,ensure_ascii=False,indent=2))
clockDecisions=[]
def period_options(s):
 solutions=[]
 def walk(rest,out):
  if not rest:
   if all(b==a+1 for a,b in zip(out,out[1:])):solutions.append(out)
   return
  for n in slots:
   if rest.startswith(str(n)):walk(rest[len(str(n)):],out+[n])
 walk(s,[])
 return solutions
def periods(s):
 solutions=period_options(s)
 if len(solutions)!=1:raise ValueError('ambiguous native compact periods '+s)
 return solutions[0]
def meetings(s,resolved=None):
 out=[]
 for part in s.split(',')if s else []:
  m=re.fullmatch(r'([월화수목금토일])(\d+)',part);assert m,part
  ns=resolved.pop(0) if resolved is not None else periods(m[2]);assert all(n in slots for n in ns),part
  groups=[]
  for n in ns:
   if groups and n==groups[-1][-1]+1:groups[-1].append(n)
   else:groups.append([n])
  for g in groups:out.append({'weekday':'월화수목금토일'.index(m[1])+1,'startMinute':slots[g[0]][0],'endMinute':slots[g[-1]][1],'classroom':''})
 return out
records={};held=[];allraw=rows(P/'hongik-current-all.html')
for cells in allraw:
 r=[txt(c)for c in cells];code,section=r[4].split('-');campus='seoul'if 1<=int(section)<=499 else 'sejong'if 500<=int(section)<=999 else None
 if campus is None:held.append({'code':r[4],'reason':'native section outside official campus rule'});continue
 if (code,section)in closed:held.append({'code':r[4],'reason':'official2026-2 closed course'});continue
 anchor=cells[5].select_one('a') or cells[5];texts=[x.strip()for x in anchor.strings if x.strip()];name=texts[0];aliases=[x[1:-1]if x.startswith('(')and x.endswith(')')else x for x in texts[1:]if x!='()'];name=re.sub(r'\s*\(\*\)$','',name).strip();dept=r[1];credit=float(r[6]);remarks=r[13];cat=r[3]
 try:parsed=meetings(r[12])
 except ValueError as error:
  report=syllabi.get(r[4],{});ts=report.get('texts',[]);hours=next((int(m[1]) for t in ts if (m:=re.search(r'학점/(\d+)시수',t))),None)
  import itertools
  choices=[period_options(part[1:]) for part in r[12].split(',')];possibilities=[x for x in itertools.product(*choices)if sum(len(v)for v in x)==hours]
  if len(possibilities)!=1:held.append({'code':r[4],'sourceSchedule':r[12],'reason':str(error),'nativeHours':hours,'matchingNativeHourSolutions':len(possibilities)});continue
  solution=possibilities[0];parsed=meetings(r[12],list(solution));clockDecisions.append({'code':r[4],'sourceSchedule':r[12],'nativeHours':hours,'periods':solution,'syllabusFile':report['file']})
 c={'sourceId':f'hongik/{campus}/2026/2/{code}/{section}','universityId':'hongik','campus':campus,'campusName':'서울캠퍼스'if campus=='seoul'else'세종캠퍼스','academicYear':2026,'semester':'2','courseCode':code,'courseName':name,'courseNameAliases':aliases,'section':section,'professor':r[11],'credits':credit,'classification':cat,'sourceSchedule':r[12],'sourceClassroom':'','scheduleStatus':'scheduled'if r[12]else'unscheduled','schedules':parsed,'departments':[dept],'departmentCredits':{dept:credit},'departmentClassifications':{dept:cat},'departmentRemarks':{dept:remarks},'remarks':remarks,'period':{'startDate':'2026-09-01','endDate':'2026-12-14'}}
 if r[4] in records:
  prior=records[r[4]];assert prior['sourceSchedule']==c['sourceSchedule']and prior['professor']==c['professor'],r[4]
  if dept not in prior['departments']:prior['departments'].append(dept)
  for field in ['departmentCredits','departmentClassifications','departmentRemarks']:prior[field].update(c[field])
 else:records[r[4]]=c
# Each official curriculum row keeps its own native classification/remarks.
for f in sorted(P.glob('hongik-group-*.html')):
 for cells in rows(f):
  r=[txt(c)for c in cells];c=records.get(r[4])
  if not c:continue
  dept=r[1];assert c['sourceSchedule']==r[12]and c['professor']==r[11],r[4]
  if dept not in c['departments']:c['departments'].append(dept)
  c['departmentCredits'][dept]=float(r[6]);c['departmentClassifications'][dept]=r[3];c['departmentRemarks'][dept]=r[13]
# Published intensive sessions: preserve native dates, never stretch to full semester.
d=BeautifulSoup((P/'hongik-intensive.html').read_text(),'html.parser').select_one('.fr-view');blocks={};current=None
for e in d.children:
 if not getattr(e,'get_text',None):continue
 text=e.get_text(' ',strip=True)
 if text.startswith('■ '):current=text[2:].split(' (')[0];blocks[current]=[]
 if e.name=='table' and current:
  blocks[current]=['2026-'+f'{int(m):02d}-{int(day):02d}'for m,day in re.findall(r'(\d+)/(\d+)\(',text)]
expected={'반도체공학(2)':'월678,금678','아날로그IC설계':'화345,목678','전기전자재료':'월789,수789','집적회로설계':'화678,목678'}
intensive=[];regularDecisions=[]
intensiveSections={'106603-1','106611-3','106612-3','106829-1'}
for key,c in list(records.items()):
 if c['campus']!='seoul'or c['courseName']not in expected:continue
 report=syllabi.get(key,{});ts=report.get('texts',[]);joined=' '.join(ts)
 if key not in intensiveSections:
  # The published per-section syllabus specifies all15weeks, with native3hours/week.
  # The8/5 generic notice omits section identifiers; it cannot override regular sections.
  assert 'Week' in ts and all(str(w)in ts for w in range(1,16)),key
  assert not any(x in joined for x in ['몰입형','집중이수','intensively']),key
  assert c['sourceSchedule'] in ts and '3학점/3시수 (3/0)' in ts,key
  regularDecisions.append({'code':key,'syllabusFile':report['file'],'reason':'native section-specific15week full syllabus, currentweekly3hour timetable matches; unlike intensive3section'})
  continue
 dates=blocks.get(c['courseName']);assert dates,c['courseName'];normal=meetings(expected[c['courseName']])
 # Each dated intensive schedule appears in its own official per-section syllabus.
 # Its header is the administrative weekly-hour template, actual schedule differs.
 assert any(x in joined for x in ['몰입형','집중이수','intensively']),key
 for date in dates:
  m,day=map(int,date.split('-')[1:]);assert f'{m}/{day}' in joined,key
 import datetime
 c['schedules']=[{**m,'date':date}for date in dates for m in normal if datetime.date.fromisoformat(date).isoweekday()==m['weekday']];assert len(c['schedules'])==15
 c['period']={'startDate':min(dates),'endDate':max(dates)};c['sourceSchedule']+='; 분반별 공식 집중이수제 '+expected[c['courseName']]+'; 날짜 '+','.join(dates);c['sourceSyllabusFile']=report['file'];intensive.append(key)
(P/'hongik-intensive-decisions.json').write_text(json.dumps({'datedIntensiveSections':intensive,'regularSections':regularDecisions},ensure_ascii=False,indent=2))
sha=hashlib.sha256((P/'hongik-current-all.html').read_bytes()).hexdigest()
for campus in ['seoul','sejong']:
 courses=[c for c in records.values()if c['campus']==campus]
 out={'schemaVersion':1,'universityId':'hongik','campus':campus,'campusName':'서울캠퍼스'if campus=='seoul'else'세종캠퍼스','academicYear':2026,'semester':'2','sourceUrl':'https://cn.hongik.ac.kr/app/timetable/','collectedDate':'2026-10-12','publishedDate':'','publishedDateUnavailable':True,'sourceSha256':sha,'sourceRowCount':len(allraw),'courses':courses,'heldRows':held,'nativePeriodClocks':slots,'periodEvidence':{'start':'2026-09-01','end':'2026-12-14','sourceUrl':'https://www.hongik.ac.kr/sso/APICipher.jsp','basis':'Official calendar native2026-2개강/종강; intensive dated classes retain their exact published bounds'},'clockSourceUrl':clockurl,'campusSourceUrl':'https://www.hongik.ac.kr/kr/newscenter/notice.do?articleNo=145568&mode=view','intensiveSourceUrl':'https://ee.hongik.ac.kr/ee/0501.do?articleNo=154871&mode=view','coverage':'Current native all-course search +92official campus curriculum queries; closed lists excluded. Source room unpublished, left blank.'}
 (P/f'hongik-{campus}-2026-2.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(campus,len(courses),sum(len(c['schedules'])for c in courses),'held',len(held),'intensive',intensive)
(P/'hongik-period-decisions.json').write_text(json.dumps(clockDecisions,ensure_ascii=False,indent=2))
print('resolved compact12',len(clockDecisions))
print('categories',sorted({v for c in records.values()for v in c['departmentClassifications'].values()}))
