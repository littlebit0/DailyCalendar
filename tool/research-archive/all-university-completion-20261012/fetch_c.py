import json,pathlib,concurrent.futures,urllib.request,urllib.parse,sys
p=pathlib.Path('work/all-university-completion-20261012/c-sources');rpath=p.parent/'c-receipts.json';prior=json.loads(rpath.read_text())if rpath.exists()else[]
urls=json.load(sys.stdin)
def f(it):
 k,u=it;req=urllib.request.Request(urllib.parse.quote(u,safe=':/?=&%'),headers={'User-Agent':'Mozilla/5.0'})
 try:
  b=urllib.request.urlopen(req,timeout=25).read();ext='.pdf'if b[:4]==b'%PDF'else'.html';file=p/(k+ext);file.write_bytes(b);return {'id':k,'url':u,'file':str(file),'bytes':len(b)}
 except Exception as e:return {'id':k,'url':u,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=8)as e:r=list(e.map(f,urls.items()))
rpath.write_text(json.dumps(prior+r,ensure_ascii=False,indent=2));print(r)
