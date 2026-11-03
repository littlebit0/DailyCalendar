"""Public ENG buttons only. Pause own active collector while serial backfill runs."""
import subprocess,os,signal,json,time,re,urllib.parse,xml.etree.ElementTree as ET
from pathlib import Path
p=Path(__file__).parent;main=p/'pknu-all-syllabus-batch.py';matches=[int(line.split(None,1)[0]) for line in subprocess.check_output(['ps','-eo','pid,args'],text=True).splitlines() if line.rstrip().endswith(' work/university-research/catalog-f/pknu-all-syllabus-batch.py')]
if len(matches)>1:raise SystemExit('Duplicate collector processes: investigate before public requests')
pid=matches[0] if matches else None
labels=[('교과목명',['Course Title']),('학수번호',['Course','Number']),('분반',['Class Number']),('개설학(부)과',['Department/','Division']),('개설학년',['Academic','Year']),('학점-이론-실습',['Credit-Lecture-','Practice']),('강의시간',['Class Time']),('강의실',['Classroom']),('강의형태',['On/Off-Line','Option']),('_stop',['Instructor'])]
def english(raw,r):
 texts=[x.text or '' for x in ET.fromstring(raw).iter('TL')];ts=[t.strip() for t in texts];loc=[]
 for key,seq in labels:
  for i in range(len(ts)-len(seq)+1):
   if ts[i:i+len(seq)]==seq:loc.append((i,key,len(seq)));break
 loc.sort();fields={};runs={}
 for j,(i,key,n) in enumerate(loc):
  if key=='_stop':break
  if j+1>=len(loc):raise ValueError('Missing academic header privacy boundary')
  vals=texts[i+n:loc[j+1][0]];fields[key]=(', ' if key=='강의실' else ' ').join(vals).strip();runs[key]=vals
 if fields.get('학수번호')!=r['COURSE_NO'] or fields.get('분반')!=r['DCLSS_NO']:raise ValueError('English exact identity mismatch')
 if not any('2026' in t and '2nd Semester' in t for t in texts[:4]):raise ValueError('English actual term header mismatch')
 evidence=[t for t in texts if re.search(r'intensive|accelerated|block[ -]teaching|prerequisite|restriction|not eligible|only for|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*[ .]+\d{1,2}|20\d{2}[-/.]\d{1,2}[-/.]\d{1,2}',t,re.I) and not re.search(r'@|\b0\d{1,2}[- ]\d{3,4}[- ]\d{4}\b|office hours|phone|contact',t,re.I)]
 return {'identity':r['COURSE_NO']+'-'+r['DCLSS_NO'],'year':'2026','semester':'2','fields':fields,'fieldTextRuns':runs,'parserVersion':2,'sourceLanguage':'en','periodRestrictionEvidence':evidence, 'periodRestrictionAudit':'All English MML text runs lexically scanned for explicit dates/intensive/restriction; does not establish absence of every possible exception','source':'official-public-ENG-button-embed-opcode700-MML','verifiedAt':time.strftime('%Y-%m-%dT%H:%M:%S%z'),'rawBodyStored':False}
if pid is not None:os.kill(pid,signal.SIGSTOP)
results=[]
try:
 exec(main.read_text().split('# Reuse four')[0]);read(entry);time.sleep(.5)
 for r in rows:
  if r.get('KOR_YN')=='Y' or r.get('ENG_YN')!='Y':continue
  ident=r['COURSE_NO']+'-'+r['DCLSS_NO'];dst=p/'pknu-current-syllabus'/(ident+'.json')
  if dst.exists() and 'pending' not in json.loads(dst.read_text()).get('periodRestrictionAudit',''):results.append({'identity':ident,'cached':True});continue
  failed=None
  for attempt in range(2):
   try:
    enc=lambda x:urllib.parse.quote(urllib.parse.quote(x,safe=''),safe='')
    params={'YY':'2026','SHTM_CD':'U0003002','IN_PARAM':"('%s','%s','%s','U0253002')"%(r['COURSE_NO'],r['DCLSS_NO'],r['STAFF_NO']),'_CLIENT_USER_INFO':{},'_PROG_INFO':{'PGM_PATH':'uni::cour/open/LtPdocInq.xfdl','MENU_ID':'U020913','MENU_NM':'강의계획서조회'}}
    report={'reportPath':enc('uni/cour/open/LtPdocMngtPrn.mrd'),'reportParam':enc(json.dumps(params,ensure_ascii=False,separators=(',',':'))),'reportOption':enc('{"ds":"uni"}'),'beforeDraw':'','afterDraw':'','sessionId':next((c.value for c in jar if c.name=='JSESSIONID'),'')}
    h=read('https://reporting.pknu.ac.kr/ReportingServer/embed',{'report':json.dumps(report,separators=(',',':')),'key':''}).decode();time.sleep(.5)
    a=re.search(r"viewer.openFile\('([^']*)','([^']*)',option\)",h);decoder.stdin.write(json.dumps({'path':a[1],'param':a[2]})+'\n');decoder.stdin.flush();d=json.loads(decoder.stdout.readline())
    raw=read('https://reporting.pknu.ac.kr/ReportingServer/service',{'opcode':'700','mrd_path':d['path'],'mrd_param':d['param'],'mrd_plain_param':'','mrd_data':'','runtime_param':'','mmlVersion':'0','protocol':'sync'})
    value=english(raw,r);dst.write_text(json.dumps(value,ensure_ascii=False,indent=2));results.append({'identity':ident,'verified':True,'fields':value['fields']});failed=None;print(ident,'verified',flush=True);break
   except urllib.error.HTTPError as e:
    failed={'identity':ident,'type':'HTTPError','status':e.code}
    if e.code in [401,403,429]:raise SystemExit('Stop on access/rate limit; no bypass')
   except Exception as e:failed={'identity':ident,'type':type(e).__name__,'message':str(e)[:180]}
   if failed and attempt==0:time.sleep(5)
  if failed:results.append(failed)
  time.sleep(.75)
finally:
 try:decoder.terminate()
 except:pass
 if pid is not None:os.kill(pid,signal.SIGCONT)
 (p/'pknu-english-syllabus-backfill-audit.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
