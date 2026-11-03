import pathlib,json,urllib.request,concurrent.futures,hashlib
from lxml import html
D=pathlib.Path(__file__).parent/'jbnu-new-official-paths';D.mkdir(exist_ok=True)
urls={
 'current-main-registration':'https://www.jbnu.edu/web/academic/class/sub01.do',
 'current-chemical-registration':'https://che.jbnu.ac.kr/bbs/che/1175/380719/artclView.do',
 'current-career-summer':'https://www.jbnu.ac.kr/web/Board/212055/detailView.do?menu=2377',
 'legacy-political-clock':'https://pol.jbnu.ac.kr/bbs/pol/578/123023/artclView.do',
 'current-statistics-major':'https://stat.jbnu.ac.kr/bbs/stat/834/396264/artclView.do'}
def fetch(kv):
 key,url=kv
 try:
  with urllib.request.urlopen(url,timeout=20) as r:b=r.read();actual=r.url
  (D/(key+'.html')).write_bytes(b);node=html.fromstring(b,parser=html.HTMLParser(encoding='utf-8'));tx=node.text_content();(D/(key+'.txt')).write_text(tx)
  return {'key':key,'url':url,'actualUrl':actual,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'saved':str(D/(key+'.txt'))}
 except Exception as e:return {'key':key,'url':url,'error':str(e)}
rows=list(concurrent.futures.ThreadPoolExecutor(5).map(fetch,urls.items()));(D/'receipt.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2));print([(r['key'],r.get('bytes'),r.get('error')) for r in rows])
