exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
from bs4 import BeautifulSoup
s=BeautifulSoup(Path('work/course-owner-filter-20261012/agent-a-sources/ewha-official-home.html').read_text(),'html.parser')
urls={}
for x in s.find_all('a'):
 h=x.get('href','');t=x.get_text(' ',strip=True)
 if h.startswith('/ewha/academics/')and h.endswith('.do')and t.endswith('대학')and'대학원'not in t:urls['ewha-'+h.split('/')[-1].replace('.do','')]='https://www.ewha.ac.kr'+h
r=list(concurrent.futures.ThreadPoolExecutor(8).map(get,urls.items()))
old=json.load(open(p/'receipts.json'));old.extend(r);(p/'receipts.json').write_text(json.dumps(old,ensure_ascii=False,indent=2))
for x in r:
 if 'sourceFile'in x:Path(x['sourceFile']).with_suffix('.txt').write_text(BeautifulSoup(Path(x['sourceFile']).read_text(errors='replace'),'html.parser').get_text(' ',strip=True))
print(r)
