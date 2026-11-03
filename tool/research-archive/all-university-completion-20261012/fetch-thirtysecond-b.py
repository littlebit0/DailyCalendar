exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'hufs-direct-international': 'https://www.hufs.ac.kr/hufs/11234/subview.do', 'hufs-direct-ld': 'https://www.hufs.ac.kr/hufs/11235/subview.do', 'hufs-direct-lt': 'https://www.hufs.ac.kr/hufs/11236/subview.do', 'hufs-direct-kfl': 'https://www.hufs.ac.kr/hufs/11237/subview.do', 'hufs-direct-biomedical': 'https://www.hufs.ac.kr/hufs/11250/subview.do', 'hufs-direct-climate': 'https://www.hufs.ac.kr/hufs/11252/subview.do'}
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
