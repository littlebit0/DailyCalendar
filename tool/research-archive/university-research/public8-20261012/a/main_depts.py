from fetch import fetch,P
import json,concurrent.futures
jobs=[]
for p in P.glob('full-*-links.json'):
 for x in json.loads(p.read_text()):
  if '홈페이지 바로가기' in x['text'] and '/main.do' in x['url']:jobs.append((p.stem[5:-6],x['url']))
def go(j):
 try:
  links=fetch('main-'+j[0],j[1]);return {'url':j[1],'links':[x for x in links if any(w in x['text'] for w in ['시간표','2026','공지','수강'])]}
 except Exception as e:return {'url':j[1],'error':str(e)}
rs=list(concurrent.futures.ThreadPoolExecutor(max_workers=6).map(go,list(dict.fromkeys(jobs))));(P/'dept-main-ledger.json').write_text(json.dumps(rs,ensure_ascii=False,indent=2))
