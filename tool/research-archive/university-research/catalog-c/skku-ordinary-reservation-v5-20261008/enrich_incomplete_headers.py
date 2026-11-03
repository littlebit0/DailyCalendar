"""One spaced normal public recheck of bounded incomplete educational plans."""
import importlib.util,io,json,re,datetime
from pathlib import Path
P=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('v5',P/'recheck_incomplete_operation.py')
v4=importlib.util.module_from_spec(spec);spec.loader.exec_module(v4)
extra=re.compile(r'Course\s+(?:format|Schedule|outline)|Teaching\s+(?:Method|Plan)|COURSE\s+PLAN|Course\s+Overview|Assessment\s+Method|수\s*업\s*(?:방식|방법)|강좌\s*진행\s*방법|학습\s*내용|강의\s*내용|(?:Week|WEEK|Wk|Wks)\s*[:\t ]|강\s*의\s*계\s*획|\b(?:1\s+Introduction|1\s+Overview|Schedule|Syllabus|Term\s+Plan)\b',re.I)
v4.TABLE_START=re.compile(v4.TABLE_START.pattern+'|'+extra.pattern,re.I)
base=v4.old.pdf_evidence
def pdf(body,code,section,prof):
 r=base(body,code,section,prof)
 with v4.pdfplumber.open(io.BytesIO(body)) as doc:
  text='\n'.join(page.extract_text(layout=False) or '' for page in doc.pages)
 r['alternativeEducationalLayoutExtraction']=v4.table_education(text,code,section,prof)
 return r
v4.old.pdf_evidence=pdf
src=json.loads((P/'current-incomplete-educational-operation-recheck.json').read_text())['records']
indices=[0,1,2,8]
out=P/'header-educational-enrichment-recheck.json'
audit={'researchOnly':True,'completionClaim':False,'records':[],'targetIndices':indices,'maximumAnonymousSessions':1,'minimumRequestStartSpacingSeconds':.8,'wholeScopeRequery':False,'rawAttachmentsPersisted':False,'stopped':False,'checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat()}
client=v4.old.SpacedPublic('KO')
try:
 for i in indices:
  r=v4.collect(client,src[i]['sourceRow']);audit['records'].append(r)
  out.write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
  print('Bounded education recheck',len(audit['records']),'of',len(indices),flush=True)
except BaseException:
 v4.old.STOP_REQUESTS.set();audit['stopped']=True;audit['failure']='Normal public request or reader stopped; no retry/bypass/private diagnostic.'
 out.write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');raise SystemExit(1)
