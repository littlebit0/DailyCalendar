from pathlib import Path
from bs4 import BeautifulSoup as B
from urllib.parse import urljoin
import requests,concurrent.futures
p=Path(__file__).parent
base='https://www.konyang.ac.kr'
s=B((p/'konyang-course-notice.html').read_bytes(),'html.parser')
jobs=[(f'konyang-course-image{i}.png',urljoin(base,img['src'])) for i,img in enumerate(s.select('.bbs_contents img, td img[src*="imageSrc"]'))]
jobs += [('konyang-nursing-board.html','https://mce.konyang.ac.kr/cop/bbs/BBSMSTR_000000000559/selectBoardList.do?pageIndex=1')]
def get(job):
 name,url=job
 try:
  r=requests.get(url,timeout=30);(p/name).write_bytes(r.content);print(name,r.status_code,len(r.content))
  if 'nursing-board' in name:
   d=B(r.content,'html.parser')
   for a in d.select('a'):
    if '시간표' in a.get_text():print(a.get_text(' ',strip=True),a.get('href'),a.get('onclick'))
 except Exception as e:print(name,e)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:list(ex.map(get,jobs))
