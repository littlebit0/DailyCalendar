"""Normal official public boot; cookies remain memory-only."""
import urllib.request,http.cookiejar,pathlib,json
BASE='https://knuin.knu.ac.kr'
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
ROOT=pathlib.Path(__file__).parent
class PublicClient:
 def __init__(self):
  self.op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
  self.get('/public/stddm/lectPlnInqr.knu')
 def get(self,path):
  req=urllib.request.Request(BASE+path,headers={'User-Agent':UA,'Referer':'https://www.knu.ac.kr/' if path=='/public/stddm/lectPlnInqr.knu' else BASE+'/public/stddm/lectPlnInqr.knu','Accept':'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'})
  return self.op.open(req,timeout=30).read()
 def post(self,path,search):
  req=urllib.request.Request(BASE+path,data=json.dumps({'search':search}).encode(),headers={'User-Agent':UA,'Referer':BASE+'/public/stddm/lectPlnInqr.knu','Content-Type':'application/json','Accept':'application/json, text/javascript, */*; q=0.01','X-Requested-With':'XMLHttpRequest'})
  return json.loads(self.op.open(req,timeout=30).read())
if __name__=='__main__':
 c=PublicClient()
 paths=[('/javascript.wq?q=/bootloader','knu-published-bootloader.js'),('/websquare/javascriptPluginAll.wq?w2xType=5&postfix=NS4wXzQuNDU3NEIuMjAyMjAxMDcuMTgyOTMzXw==MS44&compression=true','knu-published-websquare-plugins.js'),('/js/com_stddm.js?postfix=2026_10_07','knu-published-com-stddm.js')]
 for p,n in paths:
  b=c.get(p);(ROOT/n).write_bytes(b);print(n,len(b))
