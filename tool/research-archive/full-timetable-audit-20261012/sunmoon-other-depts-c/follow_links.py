from pathlib import Path
import urllib.request,urllib.parse,re,json,hashlib,concurrent.futures
from html.parser import HTMLParser
r=Path(__file__).parent
class P(HTMLParser):
 def __init__(self):super().__init__();self.a='';self.links=[]
 def handle_starttag(self,t,a):
  if t=='a':self.a=dict(a).get('href','')
 def handle_data(self,s):
  if any(q in s for q in ['공지','시간표','학사','자료실','수강']):self.links.append({'text':s.strip()[:100],'href':self.a})
def f(row):
 if not row.get('redirects'):return row
 host=urllib.parse.urlparse(row['url']).hostname.split('.')[0];u=urllib.parse.urljoin(row['url'],row['redirects'][0])
 visited=[]
 for stage in ['index','main']:
  try:
   rr=urllib.request.urlopen(u,timeout=15);b=rr.read();p=r/(host+'-'+stage+'.html');p.write_bytes(b);s=b.decode(errors='replace');pa=P();pa.feed(s)
   red=re.findall(r'(?:location.href|location.replace|location)\s*(?:=|\()\s*[\'"]([^\'"]+)',s)
   visited.append({'url':u,'finalUrl':rr.url,'file':str(p),'sha256':hashlib.sha256(b).hexdigest(),'links':pa.links,'redirects':red})
   if not red:break
   u=urllib.parse.urljoin(u,red[0])
  except Exception as e:visited.append({'url':u,'blocked':str(e)});break
 return {**row,'visited':visited}
o=list(concurrent.futures.ThreadPoolExecutor(8).map(f,json.loads((r/'home-ledger.json').read_text())));(r/'main-ledger.json').write_text(json.dumps(o,ensure_ascii=False,indent=2))
for a in o:
 print(a['name'],[(v.get('url'),len(v.get('links',[])),v.get('blocked')) for v in a.get('visited',[])])
