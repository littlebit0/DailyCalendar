import urllib.request,json,concurrent.futures
from pathlib import Path
R=Path(__file__).parent
urls={'pknu-list':'https://www.pknu.ac.kr/main/163?cd=10003','pknu-short':'https://myip.kr/SRDQG','jbnu-home':'https://www.jbnu.ac.kr','cnu-home':'https://plus.cnu.ac.kr/html/kr/'}
def get(x):
 name,url=x
 try:
  with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=40) as q:
   b=q.read(); (R/(name+'.html')).write_bytes(b)
   return {'name':name,'url':url,'finalUrl':q.url,'status':q.status,'bytes':len(b)}
 except Exception as e:return {'name':name,'url':url,'error':str(e)}
a=list(concurrent.futures.ThreadPoolExecutor(4).map(get,urls.items()));(R/'requests.json').write_text(json.dumps(a,ensure_ascii=False,indent=2));print(json.dumps(a,ensure_ascii=False))
