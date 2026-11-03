from pathlib import Path
from bs4 import BeautifulSoup as B
from urllib.parse import urljoin
import requests,concurrent.futures
p=Path(__file__).parent
jobs=[('foreign-index.html','https://deuhome.deu.ac.kr/lang_intro/index.do'),('guide80309.html','https://www.deu.ac.kr/www/gra-notice.do?mode=view&articleNo=80309'),('cancel344321.html','https://www.deu.ac.kr/www/gra-notice.do?mode=view&articleNo=344321')]
def get(j):
 name,url=j;r=requests.get(url,timeout=25);(p/name).write_bytes(r.content);d=B(r.content,'html.parser');print(name,r.status_code,len(r.content))
 for a in d.select('a'):
  t=a.get_text(' ',strip=True);h=a.get('href','')
  if ('mode=download' in h) or any(x in t for x in ['학사','수업','가이드','안내','교시','시간표','개설']):print(name,t[:90],h)
 if name!='foreign-index.html':print(d.select_one('.b-content-box').get_text(' ',strip=True) if d.select_one('.b-content-box')else'')
with concurrent.futures.ThreadPoolExecutor(max_workers=3)as ex:list(ex.map(get,jobs))
