from pathlib import Path
from bs4 import BeautifulSoup as B
import re,requests,concurrent.futures
from pypdf import PdfReader
p=Path(__file__).parent;d=B((p/'konyang-registration-notice.html').read_bytes(),'html.parser');jobs=[]
for a in d.select('a'):
 m=re.search(r"fn_egov_downFile\('([^']+)','([^']+)'",a.get('href',''))
 if m:jobs.append((m[1],m[2],a.get_text(' ',strip=True)))
def download(j):
 id,num,title=j;url=f'https://www.konyang.ac.kr/cmm/fms/FileDown.do?atchFileId={id}&fileSn={num}';r=requests.get(url,timeout=30);suffix='pdf'if r.content.startswith(b'%PDF')else'raw';f=p/f'konyang-manual{num}.{suffix}';f.write_bytes(r.content);print(title,r.status_code,len(r.content),suffix)
 if suffix=='pdf':
  reader=PdfReader(f);text='\n'.join(page.extract_text() for page in reader.pages);f.with_suffix('.txt').write_text(text)
  print(text[:2500])
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:list(ex.map(download,jobs))
