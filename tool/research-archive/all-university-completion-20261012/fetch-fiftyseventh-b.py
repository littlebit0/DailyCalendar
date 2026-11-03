exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'pnu-kmed-bachelor-curriculum': 'https://kmed.pusan.ac.kr/kmed/11960/subview.do', 'pnu-kmed-2026-curriculum-rule': 'https://kmed.pusan.ac.kr/sites/kmed/file/%28%ED%98%84%ED%96%89%29%EB%B6%80%EC%82%B0%EB%8C%80%ED%95%99%EA%B5%90%20%ED%95%9C%EC%9D%98%ED%95%99%EC%A0%84%EB%AC%B8%EB%8C%80%ED%95%99%EC%9B%90%20%EA%B5%90%EC%9C%A1%EA%B3%BC%EC%A0%95%20%ED%8E%B8%EC%84%B1%20%EB%B0%8F%20%EC%9A%B4%EC%98%81%20%EC%A7%80%EC%B9%A8-%EA%B0%9C%EC%A0%95%20%EC%A0%84%EB%AC%B8%282026.05.08.%29.pdf'}
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
