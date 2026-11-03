from pathlib import Path
from lxml import etree
import json,re,concurrent.futures,subprocess,hashlib,time,urllib.parse
p=Path(__file__).parent; rows=json.loads((p/'inje-native-all-public-rows.json').read_text()); targets={}
for r in rows:
 if r['reportOnclick']:targets.setdefault((r['교과목'],r['분반']),r)
(p/'report-fields').mkdir(exist_ok=True)
def run(item):
 (code,section),r=item; out=p/'report-fields'/f'{code}-{section}.json'
 if out.exists():
  old=json.loads(out.read_text())
  if urllib.parse.parse_qs(urllib.parse.urlsplit(old['sourceUrl']).query).get('CAP')==[r['reportCAP']]:return old
 # Actual visible report link and its selected CAP, then actual viewer's /rfn XML URL, same observed official template.
 path=re.search("PopupReportP\\('([^']+)'",r['reportOnclick']).group(1)
 params=dict(urllib.parse.parse_qsl(urllib.parse.urlsplit(path).query,keep_blank_values=True));params['CAP']=r['reportCAP']
 u='https://navi.inje.ac.kr/MRD/Subject/SubjB0011R_XML.aspx?'+urllib.parse.urlencode(params)
 res=subprocess.run(['curl','--max-time','18','-sS',u],capture_output=True)
 d={'code':code,'section':section,'sourceUrl':u,'returncode':res.returncode,'sha256':hashlib.sha256(res.stdout).hexdigest()}
 try:
  root=etree.fromstring(res.stdout); d['title']=root.findtext('제목');d['courseInformation']={n.tag:(n.text or '') for n in root.findall('./수업계획서/수업정보/*')};d['professorName']=root.findtext('./수업계획서/담당교수정보/담당교수명');d['professorDepartment']=root.findtext('./수업계획서/담당교수정보/담당교수소속');d['officeParent']=root.findtext('./수업계획서/수업지원조교정보/소속')
 except Exception as e:d['error']=str(e);d['bodyPrefix']=res.stdout[:180].decode(errors='replace')
 out.write_text(json.dumps(d,ensure_ascii=False,indent=2));time.sleep(.12);return d
allrows=[];items=list(targets.items())
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:
 for start in range(0,len(items),4):
  batch=list(ex.map(run,items[start:start+4]));allrows.extend(batch)
  (p/'report-progress.json').write_text(json.dumps({'totalVisibleReports':len(items),'processed':len(allrows),'errors':sum('error'in r for r in allrows),'wholeCompletion':False,'rawList':'inje-native-all-public-rows.json','fieldsDirectory':'report-fields','requestConcurrency':4,'requestDelaySeconds':.12},indent=2))
  if len(allrows)%100==0:print('processed',len(allrows),'errors',sum('error'in r for r in allrows),flush=True)
  if all('error' in d for d in batch):print('stopped consecutive failed batch',flush=True);break
(p/'inje-all-report-fields.json').write_text(json.dumps(allrows,ensure_ascii=False,indent=2));print('done',len(allrows),'errors',sum('error'in r for r in allrows),flush=True)
