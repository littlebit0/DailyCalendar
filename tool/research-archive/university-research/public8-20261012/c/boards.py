# coding: utf-8
from pathlib import Path
from bs4 import BeautifulSoup as B
from urllib.parse import urljoin
import json,requests,concurrent.futures,hashlib,re
p=Path(__file__).parent;r=json.loads((p/'department-route-receipt.json').read_text());jobs=[]
for x in r:
 if x['school']=='cnue'and '대학원'not in x.get('title',''):
  for a in x.get('links',[]):
   if '/community/'in a['href']and a['title']in ['공지사항','자료실']:
    jobs.append(('cnue',x['title']+' '+a['title'],a['href']))
 if x['school']=='snue':
  d=B((p/x['file']).read_bytes(),'html.parser')
  for a in d.select('a[href]'):
   if a['href'].startswith('/snue/cm/cntnts/cntntsView.do')and '교육과'in a.get_text():jobs.append(('snue',a.get_text(' ',strip=True),urljoin(x['url'],a['href'])))
jobs=list(dict.fromkeys(jobs));rec=[]
def get(j):
 school,title,u=j
 try:
  resp=requests.get(u,timeout=25);d=B(resp.content,'html.parser');links=[]
  for a in d.select('a[href]'):
   t=a.get_text(' ',strip=True);h=a['href']
   if any(z in t for z in ['시간표','2026','강의','수업','매뉴얼','홈페이지','자료실'])or('http'in h and 'cnue.ac.kr'not in h and 'snue.ac.kr'not in h):
    if len(t)<140:links.append({'title':t,'href':urljoin(u,h)})
  n='route-'+str(jobs.index(j))+'.html';(p/n).write_bytes(resp.content)
  return {'school':school,'title':title,'url':u,'status':resp.status_code,'file':n,'sha256':hashlib.sha256(resp.content).hexdigest(),'links':links}
 except Exception as e:return {'school':school,'url':u,'error':type(e).__name__}
with concurrent.futures.ThreadPoolExecutor(max_workers=4)as e:rec=list(e.map(get,jobs))
(p/'department-board-receipt.json').write_text(json.dumps(rec,ensure_ascii=False,indent=2))
for x in rec:
 selected=[a for a in x.get('links',[])if any(z in a['title']for z in ['시간표','2026','강의','수업','매뉴얼'])and '#'not in a['href']]
 print(x.get('title'),x.get('status'),selected[:15])
