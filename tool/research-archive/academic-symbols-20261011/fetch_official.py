import urllib.request,pathlib,concurrent.futures,re
root=pathlib.Path('work/academic-symbols-20261011/official');root.mkdir(exist_ok=True)
urls={'kangwon':'https://www.kangwon.ac.kr/ko/conts/921/web.do','kaist':'https://www.kaist.ac.kr/kr/html/kaist/010401.html','dgist':'https://www.dgist.ac.kr','kentech':'https://www.kentech.ac.kr','knou':'https://www.knou.ac.kr/knou/191/subview.do','nuch':'https://www.knuh.ac.kr','unist':'https://www.unist.ac.kr','gist':'https://www.gist.ac.kr','pue':'https://www.bnue.ac.kr','ssit':'https://ssit.ac.kr/static/img/ssit_ci.4408ad89.png'}
def f(kv):
 k,u=kv
 try:
  p=root/(k+'.html');p.write_bytes(urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=20).read());return k,len(p.read_bytes())
 except Exception as e:return k,str(e)
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
 for r in pool.map(f,urls.items()):print(r)
