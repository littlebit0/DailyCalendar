exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'kookmin-current-college-guide':'https://www.kookmin.ac.kr/comm/menu/user/9c61b37c77c0897a4e49f02d7c8cdc78/content/index.do','korea-current-colleges':'https://www.korea.ac.kr/ko/418/subview.do','korea-degree-2025':'https://policies.korea.ac.kr/lmxdata/attach/2025/3/upload_3768724357901710596_p0.pdf','knu-degree-2019':'https://en.knu.ac.kr/~eng/download/2019_guide1_ko.pdf','pnu-admission-2024':'https://go.pusan.ac.kr/down/mojib/RF%280%29_230530193029.pdf','pnu-contract-power-regulation':'https://medicine.pusan.ac.kr/bbs/medicine/1891/1080832/artclView.do?layout=unknown'}
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
