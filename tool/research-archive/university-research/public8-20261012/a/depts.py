from fetch import fetch,P
import json,concurrent.futures,urllib.parse
ls=json.load(open('work/university-research/expansion17-20261011/b/sunmoon-mgt-fall-links.json'))
urls=sorted({x['url'].split('?')[0] for x in ls if 'sunmoon.ac.kr' in x['url'] and ('main.do' in x['url'] or x['url'].count('/')<=3)})
print(urls)
def go(u):
 try:
  n='dept-'+urllib.parse.urlsplit(u).hostname.split('.')[0];links=fetch(n,u)
  return {'url':u,'links':[x for x in links if any(w in x['text'] for w in ['시간표','2026','공지','수강'])]}
 except Exception as e:return {'url':u,'error':str(e)}
rs=list(concurrent.futures.ThreadPoolExecutor(max_workers=6).map(go,urls));(P/'dept-ledger.json').write_text(json.dumps(rs,ensure_ascii=False,indent=2))
