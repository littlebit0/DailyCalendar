exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'jbnu-college-176': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=176', 'jbnu-college-224': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=224', 'jbnu-college-178': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=178', 'jbnu-college-189': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=189', 'jbnu-college-203': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=203', 'jbnu-college-239': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=239', 'jbnu-college-219': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=219', 'jbnu-college-169': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=169', 'jbnu-college-514': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=514', 'jbnu-college-214': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=214', 'jbnu-college-504': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=504', 'jbnu-college-230': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=230', 'jbnu-college-212': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=212', 'jbnu-college-506': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=506', 'jbnu-college-223': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=223', 'jbnu-college-1095': 'https://www.jbnu.ac.kr/web/unvr/university.do?unq=1095'}
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
