from pathlib import Path
import re,urllib.request,concurrent.futures,json,hashlib
from html.parser import HTMLParser
r=Path(__file__).parent
s=(r/'official-departments.html').read_text(errors='replace'); js=(r/'official-links.js').read_text(errors='replace')
functions={m.group(1):m.group(2) for m in re.finditer(r'function (goUrl_03\w+)\([^)]*\)\s*\{\s*window.open\("([^"]+)',js)}
rows=[]
for fn,title in re.findall(r'<a href="javascript:(goUrl_03\w+)\(\);"\s+class="ing"[^>]*>(.*?)</a>',s):
 title=re.sub('<[^>]+>','',title)
 if fn in functions and functions[fn] not in [x['url'] for x in rows]:rows.append({'name':title,'url':functions[fn]})
exclude={'cs','physical','nurs','smartcar','semiconductor','dla'}
class P(HTMLParser):
 def __init__(self):super().__init__();self.a='';self.links=[]
 def handle_starttag(self,t,a):
  if t=='a':self.a=dict(a).get('href','')
 def handle_data(self,s):
  if any(q in s for q in ['공지','시간표','학사','자료실','수강']):self.links.append({'text':s.strip()[:100],'href':self.a})
def f(row):
 host=urllib.parse.urlparse(row['url']).hostname.split('.')[0]
 if host in exclude:return {**row,'status':'previously checked - no repeat'}
 try:
  req=urllib.request.Request(row['url'],headers={'User-Agent':'Mozilla/5.0'})
  rr=urllib.request.urlopen(req,timeout=12);b=rr.read();p=r/(host+'-home.html');p.write_bytes(b);s=b.decode(errors='replace');parser=P();parser.feed(s)
  return {**row,'status':'read','finalUrl':rr.url,'file':str(p),'sha256':hashlib.sha256(b).hexdigest(),'links':parser.links,'redirects':re.findall(r'(?:location.href|location.replace|location)\s*(?:=|\()\s*[\'"]([^\'"]+)',s)}
 except Exception as e:return {**row,'status':'blocked','reason':str(e)}
o=list(concurrent.futures.ThreadPoolExecutor(8).map(f,rows));(r/'home-ledger.json').write_text(json.dumps(o,ensure_ascii=False,indent=2));print(json.dumps(o,ensure_ascii=False,indent=2))
