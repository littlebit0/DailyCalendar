exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'kangnam-2024-school-table': 'https://ks.kangnam.ac.kr/webzine/202401/a2.html', 'kyonggi-2023-rule-ee': 'https://ee.kgu.ac.kr/NFUpload/nfupload_down.php?bo_idx=1&name=%ED%95%99%EC%B9%99%EC%A0%84%EB%AC%B8%28%EA%B0%9C%EC%A0%95+2023.02.15%29.pdf&tmp_name=3422095375_7dd2d7e7.pdf&userchk=Y&userid=', 'kangnam-full-engineering': 'https://web.kangnam.ac.kr/menu/3613105ab77d66e0e866efd31fe2f767.do'}
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
