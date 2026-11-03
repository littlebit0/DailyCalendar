from pathlib import Path
from bs4 import BeautifulSoup as B
import requests,concurrent.futures
p=Path(__file__).parent
jobs=[('international-courses.html','https://deuhome.deu.ac.kr/exchange/sub06_03_04.do'),('international-handbooks.html','https://deuhome.deu.ac.kr/exchange/sub06_04_01.do'),('international-resources.html','https://deuhome.deu.ac.kr/exchange/sub06_01_04.do')]
def get(j):
 name,url=j;r=requests.get(url,timeout=25);(p/name).write_bytes(r.content);d=B(r.content,'html.parser');print(name,r.status_code)
 for a in d.select('a'):
  t=a.get_text(' ',strip=True);h=a.get('href','')
  if ('mode=download'in h or 'mode=view'in h)or any(x in t for x in ['수강','학사','강의','시간표','가이드']):print(name,t[:100],h)
 print(d.get_text(' ',strip=True)[-8000:-6000])
with concurrent.futures.ThreadPoolExecutor(max_workers=3)as ex:list(ex.map(get,jobs))
