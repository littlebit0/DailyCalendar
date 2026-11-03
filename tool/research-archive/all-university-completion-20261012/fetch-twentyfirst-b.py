exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'kmou-programs': 'https://www.kmou.ac.kr/data/2026_jungsi_2.pdf', 'mmu-programs': 'https://mobility.mmu.ac.kr/admission/contents/naval', 'nambu-handbook': 'https://www.nambu.ac.kr/upload/nambu/yoram/2023_2024_남부대학교_요람.pdf', 'kaist-minor-systems': 'https://rule.kaist.ac.kr/lmxdata/attach/2025/6/upload_3911770074483888424_p8.pdf', 'koreatech-programs': 'https://portal.koreatech.ac.kr/ctt/bb/bulletin?a=fd&b=16&fs=1&p=1473'}
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
