exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'pknu-english': 'https://english.pknu.ac.kr/english/3826', 'pknu-japanese': 'https://japanese.pknu.ac.kr/japanese/4336', 'pknu-business': 'https://cba.pknu.ac.kr/', 'pknu-international': 'https://icms.pknu.ac.kr/dias/3989', 'pknu-admin': 'https://icms.pknu.ac.kr/pknupasw/3150', 'kongju-2026-cancel': 'https://www.kongju.ac.kr/bbs/KNU/2132/648284/download.do', 'kongju-2026-guide': 'https://sdm.kongju.ac.kr/bbs/sdm/2106/646183/download.do', 'kangwon-disaster': 'https://www.kangwon.ac.kr/ko/conts/308/web.do'}
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
