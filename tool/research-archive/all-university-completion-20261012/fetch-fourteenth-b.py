exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'cnu-2025-book': 'https://plus.cnu.ac.kr/html/kr/25file/2025_book.pdf', 'kunsan-mcd': 'https://www.kunsan.ac.kr/index.kunsan?menuCd=DOM_000000103003012000&sso=ok', 'jnu-greenbio-home': 'https://greenbio.jnu.ac.kr/greenbio/index.do', 'jnu-greenbio-2026': 'https://greenbio.jnu.ac.kr/bbs/greenbio/3467/825097/download.do'}
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
