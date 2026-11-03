import concurrent.futures, hashlib, json, pathlib, urllib.request
from html.parser import HTMLParser
P=pathlib.Path('work/all-university-completion-20261012/root-sources')
sources={
 'hanyang-seoul-current':'https://www.hanyang.ac.kr/s_college_department-info',
 'hanyang-erica-atc':'https://atc.hanyang.ac.kr/',
 'hanyang-humanities-fusion':'https://humanities.hanyang.ac.kr/-01-4-7a',
}
class Text(HTMLParser):
 def __init__(self):super().__init__();self.parts=[]
 def handle_data(self,s):
  if s.strip():self.parts.append(s.strip())
def fetch(item):
 name,url=item
 try:
  with urllib.request.urlopen(url,timeout=35) as r:data=r.read();ct=r.headers.get('Content-Type','');final=r.url
  ext='.pdf' if data.startswith(b'%PDF') else '.html'
  path=P/(name+ext);path.write_bytes(data)
  if ext=='.html':
   p=Text();p.feed(data.decode('utf-8',errors='replace'));(P/(name+'.txt')).write_text('\n'.join(p.parts))
  return {'id':name,'url':url,'finalUrl':final,'file':str(path),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'contentType':ct}
 except Exception as e:return {'id':name,'url':url,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:out=list(pool.map(fetch,sources.items()))
(P/'receipts-sixth.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(out,ensure_ascii=False))
