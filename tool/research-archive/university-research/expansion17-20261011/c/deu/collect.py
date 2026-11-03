from pathlib import Path
from bs4 import BeautifulSoup as B
import requests,json,hashlib,concurrent.futures
p=Path(__file__).parent
jobs=[('exchange-home.html','https://deufund.deu.ac.kr/exchange/main.do'),('english-home.html','https://eng.deu.ac.kr/eng'),('current-notices.html','https://www.deu.ac.kr/www/gra-notice.do')]
def get(job):
 name,url=job
 try:
  r=requests.get(url,timeout=25);(p/name).write_bytes(r.content);d=B(r.content,'html.parser');print(name,r.status_code,len(r.content))
  for a in d.select('a'):
   text=a.get_text(' ',strip=True)
   if any(x.lower()in text.lower()for x in ['교환','외국인','수강','강의','시간표','course','exchange','international','학사안내','학사지원','학사정보','guide']):print(name,text[:120],a.get('href'))
 except Exception as e:print(name,e)
with concurrent.futures.ThreadPoolExecutor(max_workers=3)as ex:list(ex.map(get,jobs))
