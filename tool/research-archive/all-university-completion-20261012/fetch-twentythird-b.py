exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'jnu-integrated-social': 'https://hisedu.jnu.ac.kr/bbs/hisedu/2296/854019/artclView.do', 'jnu-2024-yearbook': 'https://www.jnu.ac.kr/Data/tmfiles/Down/introduction/StatisticalYearbook_2024_c.pdf', 'jeju-2025-program-rules': 'https://faculty.jejunu.ac.kr/faculty/committee/committee2.htm?act=download&no=1&page=1&seq=255242'}
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
