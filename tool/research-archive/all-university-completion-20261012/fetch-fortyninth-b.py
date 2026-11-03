exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'nambu-main-organization': 'https://student.nambu.ac.kr/nambukr/index.do', 'nambu-2023-2024-yoram': 'https://www.nambu.ac.kr/upload/nambu/yoram/2023_2024_%EB%82%A8%EB%B6%80%EB%8C%80%ED%95%99%EA%B5%90_%EC%9A%94%EB%9E%8C.pdf', 'kangnam-ai-industrial': 'https://web.kangnam.ac.kr/html4/intro_new10_1.html', 'kangnam-engineering-current': 'https://iwc.kangnam.ac.kr/', 'knu-autonomous-organization': 'https://www.knu.ac.kr/wbbs/wbbs/contents/index.action?menu_url=edu%2Facademic03_01_15'}
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
