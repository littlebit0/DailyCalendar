import urllib.request,concurrent.futures,pathlib,re
urls={'shinhan-main':'https://www.shinhan.ac.kr/kr/index.do','calvin-extra':'https://international.calvin.ac.kr/','nuch-main':'https://www.knuh.ac.kr/main.do','jseok-extra':'http://www.jsc.ac.kr/'}
root=pathlib.Path('work/academic-region-logos-20261011')
def fetch(kv):
 k,u=kv
 try:
  d=urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=15).read().decode('utf-8','replace');(root/(k+'.html')).write_text(d)
  return k,[x for x in re.findall(r'<(?:img|link)[^>]+>',d,re.I) if re.search('logo|로고|icon',x,re.I)][:10]
 except Exception as e:return k,str(e)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
 for r in pool.map(fetch,urls.items()):print(r)
