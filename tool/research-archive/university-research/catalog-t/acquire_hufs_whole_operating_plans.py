"""Read current public special-course plans; keep educational fields only."""
from html.parser import HTMLParser
import json,re,time,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parent
PRIOR=ROOT.parent/'catalogs'
class Cells(HTMLParser):
 def __init__(self):super().__init__();self.depth=0;self.buf='';self.values=[]
 def handle_starttag(self,tag,attrs):
  if tag in ['td','th']:self.depth+=1;self.buf=''
  if tag=='br' and self.depth:self.buf+='\n'
 def handle_data(self,text):
  if self.depth:self.buf+=text
 def handle_endtag(self,tag):
  if tag in ['td','th'] and self.depth:
   self.depth-=1;self.values.append(re.sub(r'[ \t\r]+',' ',self.buf).strip())
def educational_cells(cells):
 fields={}; labels={'학수번호':'identity','교과목명':'title','이수구분':'classification','학과 (Department)':'department','학점/강의시간':'creditsHours','강의시간(강의실위치)':'schedule','강의유형':'delivery','수업운영방식':'methods','기타안내 및 유의사항':'notes'}
 for i,value in enumerate(cells):
  if i+1<len(cells):
   for label,key in labels.items():
    if value.startswith(label):fields[key]=cells[i+1]
 weeks={}
 for i,value in enumerate(cells):
  if re.fullmatch(r'(?:[1-9]|1[0-6])(?:st|nd|rd|th)',value) and i+1<len(cells):weeks[value]=cells[i+1]
 fields['weekly']=weeks
 # Contact details are outside the allowlist and not kept even if embedded in a note.
 for key,value in list(fields.items()):
  if isinstance(value,str):
   value=re.sub(r'https?://[^\s<>]+',lambda m:'[수업 접속주소 제외]' if re.search(r'zoom\.us|webex\.com|(?:[?&](?:pwd|password|token)=)',m[0],re.I) else m[0],value)
   fields[key]='\n'.join(line for line in value.splitlines() if not re.search(r'@|(?:010|02|0[3-6]\d)[ -]\d{3,4}[ -]\d{4}',line))
 return fields

from concurrent.futures import ThreadPoolExecutor, as_completed
import threading
rows=json.loads((ROOT/'hufs-current-20261008/courses.json').read_text())
unique={(r['queryCampus'],r['row']['lssnCd']):r['row'] for r in rows}
out=ROOT/'hufs-public-operating-plans';out.mkdir(exist_ok=True)
manifest={'researchOnly':True,'completionClaim':False,'complete':False,'courseCount':len(unique),'processed':0,'verifiedPlans':0,'unpublished':[],'errors':[],'maxConcurrentRequests':4}
stop=threading.Event()
def acquire(pair):
 campus,key=pair
 path=out/(campus+'-'+key+'.json')
 url='https://wis.hufs.ac.kr/src08/jsp/lecture/syllabus.jsp?mode=print&ledg_year=2026&ledg_sessn=3&org_sect=A&lssn_cd='+key
 if stop.is_set():return None
 try:
  if path.exists():document=json.loads(path.read_text())
  else:
   time.sleep(.35)
   with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30) as response:body=response.read().decode('utf-8')
   parser=Cells();parser.feed(body);fields=educational_cells(parser.values)
   if not re.search(r'(?:^|\s)'+re.escape(key)+r'$',fields.get('identity','')) or '2026-2학기' not in body:raise ValueError('Current public plan header mismatch')
   document={'campus':campus,'key':key,'sourceUrl':url,'checkedDate':'2026-10-08','fields':fields}
   path.write_text(json.dumps(document,ensure_ascii=False,indent=2))
  unpublished=not document['fields'].get('methods') and not any(document['fields'].get('weekly',{}).values())
  return {'identity':campus+'/'+key,'unpublished':unpublished}
 except Exception as error:
  code=getattr(error,'code',None)
  if code in [401,403,429]:stop.set()
  return {'error':{'campus':campus,'key':key,'errorType':type(error).__name__,'httpStatus':code}}
with ThreadPoolExecutor(max_workers=4) as executor:
 futures=[executor.submit(acquire,pair) for pair in sorted(unique)]
 for future in as_completed(futures):
  result=future.result()
  if result is None:continue
  if 'error' in result:manifest['errors'].append(result['error'])
  elif result['unpublished']:manifest['unpublished'].append(result['identity'])
  else:manifest['verifiedPlans']+=1
  manifest['processed']+=1
  (ROOT/'hufs-whole-plan-acquisition-audit.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
  if manifest['processed']%100==0:print('processed',manifest['processed'],'verified',manifest['verifiedPlans'],'unpublished',len(manifest['unpublished']),'errors',len(manifest['errors']),flush=True)
manifest['complete']=manifest['processed']==len(unique) and not stop.is_set()
manifest['unpublished'].sort()
(ROOT/'hufs-whole-plan-acquisition-audit.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2));print('Complete',manifest['processed'],manifest['complete'],flush=True)
