exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'kangwon-program-chuncheon': 'https://www.kangwon.ac.kr/ko/conts/111/web.do', 'kangwon-program-gangneung': 'https://kangwon.ac.kr/ko/conts/535/web.do', 'kangwon-program-2026': 'https://multimajor.kangwon.ac.kr/multimajor/community/data.do?articleNo=561936&mode=view', 'hanbat-program': 'https://www.hanbat.ac.kr/kor/sub05_030104.do', 'inha-bio-http': 'http://inhabioedu.com/major/requirement'}
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
