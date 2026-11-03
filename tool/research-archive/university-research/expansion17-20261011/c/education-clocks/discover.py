from pathlib import Path
from bs4 import BeautifulSoup as B
import requests,concurrent.futures
p=Path(__file__).parent
jobs=[('snue-home.html','https://www.snue.ac.kr/snue/main.do'),('cnue-home.html','https://www.cnue.ac.kr/cnue/index.do'),('cue-rules.html','https://www.cue.ac.kr/kor/CMS/RegulationBookMgr/list.do?mCode=MN034')]
def get(j):
 name,url=j
 try:
  r=requests.get(url,timeout=25);(p/name).write_bytes(r.content);d=B(r.content,'html.parser');print(name,r.status_code,len(r.content))
  for a in d.select('a'):
   t=a.get_text(' ',strip=True);h=a.get('href','')
   if any(x in t for x in ['시간표','규정','학사안내','시설물','수강','강의실','강의조회']):print(name,t[:100],h)
 except Exception as e:print(name,e)
with concurrent.futures.ThreadPoolExecutor(max_workers=3)as ex:list(ex.map(get,jobs))
