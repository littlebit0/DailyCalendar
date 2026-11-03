exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'inu-huss-virtual-2026': 'https://global.inu.ac.kr/bbs/inu/2808/377085/download', 'inu-huss-create-2025': 'https://global.inu.ac.kr/bbs/inu/2808/373714/download', 'pknu-independent-liberal': 'https://www.pknu.ac.kr/main/463', 'pknu-liberal-system': 'https://icms.pknu.ac.kr/college/6984'}
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
