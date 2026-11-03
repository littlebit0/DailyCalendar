import urllib.request,pathlib,concurrent.futures,json
root=pathlib.Path('work/academic-symbols-20261011/official')
urls={'kangwon-symbol':'https://www.kangwon.ac.kr/assets/ko/images/sub/symbol1.webp','kaist-emblem':'https://www.kaist.ac.kr/kr/img/content/sub01/sym_new_02.gif','knou-logo':'https://www.knou.ac.kr/sites/knou/images/logo-header25.png','unist-icon':'https://www.unist.ac.kr/_res/unist/_share/img/main/favicon.ico','pue-logo':'https://www.bnue.ac.kr/resources/custom/images/main/common/hd-logo.png','gist-icon':'https://www.gist.ac.kr/common/img/touch-icon-ios.png','ssit-ci':'https://ssit.ac.kr/static/img/ssit_ci.4408ad89.png'}
def f(kv):
 k,u=kv
 try:
  p=root/(k+'.raw');p.write_bytes(urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=15).read());return k,{'url':u,'raw':str(p)}
 except Exception as e:return k,{'url':u,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:rs=dict(pool.map(f,urls.items()))
(root/'images.json').write_text(json.dumps(rs,indent=2));print(rs)
