exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={
 'catholic-glocal':'https://major-convergence.catholic.ac.kr/major_convergence/curriculum-info/glocal.do',
 'ewha-2026':'https://cmsfox.ewha.ac.kr/environewha/board/notice.do?articleNo=768720&attachNo=494561&mode=download',
 'khu-all-alt':'https://www.khu.ac.kr/kor/user/contents/view.do?menuNo=200105',
 'hufs-ai-system':'https://www.hufs.ac.kr/hufs/11262/subview.do',
 'hoseo-mobility':'https://rise.hoseo.ac.kr/main/menu?bwrite_id=V76eMcCMGUxD&do=view&gc=605XOAS'}
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
