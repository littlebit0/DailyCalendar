exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'ajou-bio-system': 'https://ebiz.ajou.ac.kr/kr/ajou/news.do?articleNo=363603&mode=view', 'jnu-nextcomm-system': 'https://jnu.nccoss.kr/www/', 'cnu-2025-hwp': 'https://edu.cnu.ac.kr/_attach/file/2025/03/rLIAMgSGQloxgWlRiLGA0.hwp', 'ajou-ai-program': 'https://abiotech.ajou.ac.kr/kr/ajou/notice.do?articleNo=375961&mode=view'}
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
