exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'mju-2026-festival-guide': 'https://gsca.mju.ac.kr/bbs/mjukr/141/176202/download.do', 'mju-art-history-transfer': 'https://mju.ac.kr/mjukr/558/subview.do', 'mju-business-official-parent': 'https://majorfree.mju.ac.kr/majorfree/11206/subview.do', 'mju-global-business-parent': 'https://global.mju.ac.kr/sites/global/index.do'}
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
