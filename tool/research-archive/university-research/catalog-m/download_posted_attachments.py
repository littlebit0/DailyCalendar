"""Only actual attachment links present in the saved official notices."""
import pathlib,urllib.request,urllib.parse,html,re,json,concurrent.futures
from html.parser import HTMLParser
P=pathlib.Path(__file__).parent
class Links(HTMLParser):
 def __init__(self):super().__init__();self.rows=[];self.cur=None
 def handle_starttag(self,t,a):
  if t=='a':self.cur=dict(a);self.cur['text']=''
 def handle_data(self,s):
  if self.cur is not None:self.cur['text']+=s
 def handle_endtag(self,t):
  if t=='a' and self.cur is not None:self.rows.append(self.cur);self.cur=None
jobs=[]
for f,base,school in [('kunsan-current-coursebook.html','https://www.kunsan.ac.kr','kunsan'),('kumoh-current-registration.html','https://edu.kumoh.ac.kr/ko/sub06_01_01_01.do','kumoh'),('mokpo-current-registration.html','https://mnusdm.mokpo.ac.kr','mokpo')]:
 h=Links();h.feed((P/f).read_text());i=0
 for a in h.rows:
  href=a.get('href','');label=a.get('title') or ' '.join(a['text'].split())
  if not ('download' in href or 'mode=download' in href) or not re.search(r'\.(pdf|xlsx)$',label,re.I):continue
  if school=='mokpo' and not ('개설 목록표' in label):continue
  i+=1;ext=re.search(r'\.(pdf|xlsx)$',label,re.I)[1];jobs.append({'school':school,'label':label,'url':urllib.parse.urljoin(base,href),'file':school+'-2026-2-attachment-'+str(i)+'.'+ext})
def fetch(j):
 try:
  b=urllib.request.urlopen(urllib.request.Request(j['url'],headers={'User-Agent':'Mozilla/5.0'}),timeout=30).read();(P/j['file']).write_bytes(b);return {**j,'bytes':len(b),'magic':b[:4].hex()}
 except Exception as e:return {**j,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:out=list(pool.map(fetch,jobs))
(P/'posted-attachment-manifest.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
for j in out:print(j['file'],j['label'],j.get('bytes'),j.get('error',''))
