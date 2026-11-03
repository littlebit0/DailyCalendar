# coding: utf-8
from pathlib import Path
from bs4 import BeautifulSoup as B
from urllib.parse import urljoin
import json,requests,concurrent.futures,hashlib
p=Path(__file__).parent;jobs=json.loads((p/'cue-dept-board-links.json').read_text())
def get(j):
 u=j['href'].replace('http://','https://',1)
 try:
  r=requests.get(u,timeout=25);d=B(r.content,'html.parser');n='cue-board-'+str(jobs.index(j))+'.html';(p/n).write_bytes(r.content);links=[]
  for a in d.select('a[href]'):
   h=a['href'];t=a.get_text(' ',strip=True)
   if 'mode=view'in h:links.append({'title':t,'url':urljoin(u,h)})
  return {'title':j['title'],'observedURL':j['href'],'requestURL':u,'status':r.status_code,'file':n,'sha256':hashlib.sha256(r.content).hexdigest(),'articles':links}
 except Exception as e:return {'title':j['title'],'url':u,'error':type(e).__name__}
with concurrent.futures.ThreadPoolExecutor(max_workers=4)as e:out=list(e.map(get,jobs))
(p/'cue-board-receipt.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
for x in out:print(x['title'],x.get('status'),[(a['title'],a['url'])for a in x.get('articles',[])])
