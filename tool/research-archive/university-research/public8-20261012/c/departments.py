# coding: utf-8
from pathlib import Path
from bs4 import BeautifulSoup as B
from urllib.parse import urljoin,urlparse
import requests,concurrent.futures,json,hashlib
p=Path(__file__).parent; prior=Path('work/university-research/expansion17-20261011/c/education-clocks');jobs=[]
for school,filename,base in [('cnue','cnue-home.html','https://www.cnue.ac.kr'),('cue','cue-rules.html','https://www.cue.ac.kr')]:
 d=B((prior/filename).read_bytes(),'html.parser')
 for a in d.select('a[href]'):
  h=a['href'];t=a.get_text(' ',strip=True)
  if (school=='cnue' and '교육' in t and h.startswith('/')and h.count('/')==2 and '?'not in h)or(school=='cue'and'/UnivOrganMgr/view.do' in h):
   u=urljoin(base,h);jobs.append((school,t,u))
jobs.append(('snue','undergraduate','https://www.snue.ac.kr/snue/cm/cntnts/cntntsView.do?mi=3006&cntntsId=3000'));jobs=list(dict.fromkeys(jobs));receipts=[]
def go(j):
 s,t,u=j;n=s+'-dept-'+str(jobs.index(j))+'.html'
 try:
  r=requests.get(u,timeout=25);(p/n).write_bytes(r.content);d=B(r.content,'html.parser');links=[]
  for a in d.select('a[href]'):
   h=a['href'];text=a.get_text(' ',strip=True)
   if any(x in text for x in ['공지','자료','홈페이지','시간표','수업','강의','게시판']):links.append({'title':text[:100],'href':urljoin(u,h)})
  return {'school':s,'title':t,'url':u,'status':r.status_code,'file':n,'bytes':len(r.content),'sha256':hashlib.sha256(r.content).hexdigest(),'links':links}
 except Exception as e:return {'school':s,'url':u,'error':type(e).__name__}
with concurrent.futures.ThreadPoolExecutor(max_workers=4)as ex:receipts=list(ex.map(go,jobs))
(p/'department-route-receipt.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2))
for r in receipts:
 print(r['school'],r.get('title'),r.get('status'),[(a['title'],a['href'])for a in r.get('links',[])if '/cnue/'not in a['href'] and '/kor/'not in a['href'] or '시간표'in a['title']])
