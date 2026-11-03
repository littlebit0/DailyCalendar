from fetch import fetch,P
import re,json,concurrent.futures
jobs=[]
for p in P.glob('dept-*.html'):
 s=p.read_text();m=re.search(r'location.href="([^"]+)"',s)
 if m:
  name=p.stem[5:];jobs.append((name,'https://'+name+'.sunmoon.ac.kr'+m[1]))
def go(j):
 try:
  links=fetch('full-'+j[0],j[1]);return {'url':j[1],'links':[x for x in links if any(w in x['text'] for w in ['시간표','2026','공지','수강'])]}
 except Exception as e:return {'url':j[1],'error':str(e)}
rs=list(concurrent.futures.ThreadPoolExecutor(max_workers=6).map(go,jobs));(P/'dept-full-ledger.json').write_text(json.dumps(rs,ensure_ascii=False,indent=2))
