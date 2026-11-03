from fetch import fetch,P
from urllib.parse import urlsplit,parse_qs,urlencode,urlunsplit
import json,concurrent.futures
jobs=[]
for p in P.glob('main-*-links.json'):
 for x in json.loads(p.read_text()):
  if 'selectNttList.do' in x['url'] and '공지' in x['text']:
   u=urlsplit(x['url']);q=parse_qs(u.query);q.update(searchValue=['시간표'],searchType=['sj']);jobs.append((p.stem[5:],urlunsplit((u.scheme,u.netloc,u.path,urlencode(q,doseq=True),''))));break
def go(j):
 try:
  ls=fetch('notice-search-'+j[0],j[1]);return {'url':j[1],'matches':[x for x in ls if '시간표' in x['text']]}
 except Exception as e:return {'url':j[1],'error':str(e)}
rs=list(concurrent.futures.ThreadPoolExecutor(max_workers=6).map(go,jobs));(P/'dept-notice-search-ledger.json').write_text(json.dumps(rs,ensure_ascii=False,indent=2))
