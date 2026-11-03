import urllib.request,io,time,json,hashlib
import pdfplumber
from pathlib import Path
out=[]
urls=['https://www.gnu.ac.kr/common/nttFileDownload.do?fileKey=a31dde218924c09ca7bb32c2a1d9ec9d','https://www.gnu.ac.kr/common/nttFileDownload.do?fileKey=a7274eb0d49a992da7d6765aec8b86f9']
for url in urls:
 time.sleep(.8)
 with urllib.request.urlopen(url,timeout=40) as r:
  assert r.status==200
  b=r.read()
 assert b.startswith(b'%PDF')
 with pdfplumber.open(io.BytesIO(b)) as pdf:
  texts=[p.extract_text() or '' for p in pdf.pages[:2]]
  out.append({'sourceUrl':url,'sha256':hashlib.sha256(b).hexdigest(),'pageCount':len(pdf.pages),'firstTwoEducationalPages':texts})
Path('work/university-research/catalog-p/gnu-current-educational-pdf-header-audit-20261008.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
for x in out:print(x['pageCount'],x['firstTwoEducationalPages'][0][:1800])
