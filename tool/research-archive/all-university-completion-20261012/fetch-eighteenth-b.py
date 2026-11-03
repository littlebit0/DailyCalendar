exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'pnu-shared-2026': 'https://www.pusan.ac.kr/kor/CMS/Board/Board.do?board_seq=1506371&mCode=MN095&mgr_seq=3&mode=view', 'kyonggi-classification': 'https://www.kyonggi.ac.kr/SLI/contents.do?key=2482', 'kunsan-media': 'https://www.kunsan.ac.kr/index.kunsan?menuCd=DOM_000000103003012032&sso=ok'}
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
