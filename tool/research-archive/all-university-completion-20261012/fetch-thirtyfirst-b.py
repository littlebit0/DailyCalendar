exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'kyonggi-2022-curriculum':'https://ee.kgu.ac.kr/NFUpload/nfupload_down.php?bo_idx=1&name=%EB%B6%99%EC%9E%84+2022+%EA%B5%90%EC%9C%A1%EA%B3%BC%EC%A0%95+%EC%95%88%EB%82%B4%EC%B1%85%EC%9E%90+%EC%B5%9C%EC%A2%85%EB%B3%B8.pdf&tmp_name=3422095375_696a1571.pdf&userchk=Y&userid='}
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
