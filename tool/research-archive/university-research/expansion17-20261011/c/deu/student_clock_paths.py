from pathlib import Path
from bs4 import BeautifulSoup as B
import requests,concurrent.futures
p=Path(__file__).parent
jobs=[('current-dess-academic.html','https://dess.deu.ac.kr/?mid=Page13'),('current-dess-faq.html','https://dess.deu.ac.kr/?mid=Page15')]
def get(j):
 name,url=j;r=requests.get(url,timeout=25);(p/name).write_bytes(r.content);d=B(r.content,'html.parser');print(name,r.status_code)
 text=d.get_text(' ',strip=True)
 for token in ['교시','50분','강의시간','시간표','수업시간']:
  i=text.find(token)
  if i>=0:print(token,text[max(0,i-150):i+700])
 for a in d.select('a[href]'):
  t=a.get_text(' ',strip=True);h=a['href']
  if any(x in t for x in ['강의시간','시간표','수업시간','수강신청','규정']):print(t,h)
with concurrent.futures.ThreadPoolExecutor(max_workers=2)as ex:list(ex.map(get,jobs))
