exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'pcu-program-list': 'https://hakgwa.pcu.ac.kr/conv', 'nsu-program-list': 'https://cvgm.nsu.ac.kr/', 'hyupsung-program-list': 'https://www.uhs.ac.kr/uhs/3842/subview.do', 'kwangwoon-program-list': 'https://www.kw.ac.kr/ko/life/notice.jsp?BoardMode=view&DUID=50495&searchKey=1&searchVal=&srCategoryId=&tpage=1', 'kau-micro': 'https://kau.ac.kr/kaulife/acdnoti.php?code=s1201&mode=read&page=23&searchkey=&searchvalue=&seq=8695'}
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
