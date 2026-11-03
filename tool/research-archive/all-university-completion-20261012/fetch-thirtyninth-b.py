exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'pknu-business-members': 'https://cba.pknu.ac.kr/cba/6505', 'pknu-trade-members': 'https://cba.pknu.ac.kr/cba/6506', 'pknu-economy': 'https://econ.pknu.ac.kr/econ/2838', 'kongju-contract': 'https://pro.kongju.ac.kr/ZD9003/11139/subview.do', 'kongju-survey': 'https://homepage.kongju.ac.kr/bbs/M02041/1892/479050/download.do'}
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
