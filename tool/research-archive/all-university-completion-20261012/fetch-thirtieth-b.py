exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'mju-future-college':'https://gsba.mju.ac.kr/mjukr/209/subview.do','kyonggi-program-legacy2':'https://enter.kyonggi.ac.kr/ajaxfile/CMN_SVC/FileView.do?CONTENTS_NO=1&GBN=X12&MENU_NO=160&SITE_NO=2&TYPE_CODE=C0601'}
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
