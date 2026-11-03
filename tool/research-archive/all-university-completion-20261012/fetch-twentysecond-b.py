exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'nambu-handbook-encoded': 'https://www.nambu.ac.kr/upload/nambu/yoram/2023_2024_%EB%82%A8%EB%B6%80%EB%8C%80%ED%95%99%EA%B5%90_%EC%9A%94%EB%9E%8C.pdf', 'kongju-program-guide': 'https://sdm.kongju.ac.kr/bbs/sdm/2106/621376/download.do', 'ajou-rules': 'https://rules.ajou.ac.kr/IRS/rule/detail/675?S2=DESC&crntYn=Y'}
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
