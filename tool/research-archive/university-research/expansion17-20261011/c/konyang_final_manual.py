from pathlib import Path
from bs4 import BeautifulSoup as B
from urllib.parse import urljoin
import requests,concurrent.futures
p=Path(__file__).parent
url='https://www.konyang.ac.kr/cop/bbs/BBSMSTR_000000000584/selectBoardArticle.do?nttId=290738'
r=requests.get(url,timeout=25);(p/'konyang-registration-notice.html').write_bytes(r.content);d=B(r.content,'html.parser')
print(d.get_text(' ',strip=True)[-12000:-4500])
jobs=[]
for a in d.select('a'):
 h=a.get('href','')
 if 'FileDown' in h:
  print(a.get_text(' ',strip=True),h);jobs.append((a.get_text(' ',strip=True),urljoin(url,h)))
def download(job):
 name,url=job;r=requests.get(url,timeout=25);suffix='pdf' if r.content.startswith(b'%PDF') else 'raw';n=f'konyang-manual{jobs.index(job)}.{suffix}';(p/n).write_bytes(r.content);print(n,r.status_code,len(r.content))
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:list(ex.map(download,jobs))
