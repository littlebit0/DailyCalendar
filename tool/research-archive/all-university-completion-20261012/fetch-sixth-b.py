exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={
 'hufs-2026-global':'https://e-book.hufs.ac.kr/src/viewer/download.php?host=main&no=1&site=20260115_sugang_h2',
 'hufs-2026-seoul':'https://e-book.hufs.ac.kr/src/viewer/download.php?host=main&no=1&site=20260313_sugang_h1',
 'cnu-2025-program':'https://edu.cnu.ac.kr/_attach/file/editor_viewer/out/_attach/file/2025/03/rLIAMgSGQloxgWlRiLGA0.hwp.files/Sections1.html'}
r=list(concurrent.futures.ThreadPoolExecutor(8).map(get,urls.items()))
old=json.load(open(p/'receipts.json'));old.extend(r);(p/'receipts.json').write_text(json.dumps(old,ensure_ascii=False,indent=2))
from bs4 import BeautifulSoup
import fitz
for x in r:
 if 'sourceFile'not in x:continue
 f=Path(x['sourceFile'])
 if f.suffix=='.pdf': t='\n'.join(z.get_text()for z in fitz.open(f))
 else:t=BeautifulSoup(f.read_text(errors='replace'),'html.parser').get_text(' ',strip=True)
 f.with_suffix('.txt').write_text(t)
print(r)
