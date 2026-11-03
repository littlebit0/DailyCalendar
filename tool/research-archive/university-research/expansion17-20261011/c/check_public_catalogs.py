from pathlib import Path
from bs4 import BeautifulSoup as B
import requests,concurrent.futures,json
p=Path(__file__).parent
jobs=[(f'konyang-main-page{i}.html',f'https://www.konyang.ac.kr/cop/bbs/BBSMSTR_000000000584/selectBoardList.do?pageIndex={i}')for i in range(2,9)]
jobs += [('dju-sugang-login.html','https://sugang.dju.ac.kr/common/login.do'),('dju-portal-login.html','https://portal.dju.ac.kr/')]
def get(job):
 name,url=job
 try:
  r=requests.get(url,timeout=25);(p/name).write_bytes(r.content);d=B(r.content,'html.parser');matches=[]
  for a in d.select('a'):
   title=a.get_text(' ',strip=True)
   if ('2026' in title or '수강' in title) and any(x in title for x in ['수강신청','강의시간','시간표','개설강좌']):matches.append({'title':title,'href':a.get('href'),'onclick':a.get('onclick')})
  print(name,r.status_code,r.url,json.dumps(matches,ensure_ascii=False))
 except Exception as e:print(name,str(e))
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:list(ex.map(get,jobs))
