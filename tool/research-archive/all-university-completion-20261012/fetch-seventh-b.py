exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={
 'khu-2026':'https://haksa.khu.ac.kr/nhaksa/user/contents/view.do?menuNo=21200079',
 'hufs-official-doubles':'https://dep.hufs.ac.kr/physics/4145/subview.do',
 'cnu-2026-modules':'https://plus.cnu.ac.kr/html/kr/26file/2026_di_2010.pdf'}
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
