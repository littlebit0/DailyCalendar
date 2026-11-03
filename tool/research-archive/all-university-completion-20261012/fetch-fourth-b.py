exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={
 'hufs-ai-college':'https://www.hufs.ac.kr/hufs/11249/subview.do',
 'hansung-2026':'https://www.hansung.ac.kr/bbs/hansung/2127/30565/download.do',
 'kangnam-wel':'https://wel-tech.kangnam.ac.kr/menu/1d16dfcbb77bc262024bd3fa0997a12a.do',
 'inha-bio':'https://inhabioedu.com/major/requirement',
 'cau-2026-alt':'https://cse.cau.ac.kr/file/2026_haksa_guide.pdf'}
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
