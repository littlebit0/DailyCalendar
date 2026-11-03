import requests,concurrent.futures,pathlib,json,sys
from bs4 import BeautifulSoup
P=pathlib.Path(__file__).parent
def go(x):
 n,u=x
 try:
  r=requests.get(u,timeout=45,headers={'User-Agent':'Mozilla/5.0'});r.encoding=r.apparent_encoding
  (P/(n+'.html')).write_text(r.text);s=BeautifulSoup(r.text,'html.parser');(P/(n+'.txt')).write_text(s.get_text(' ',strip=True));links=[{'text':a.get_text(' ',strip=True),'url':requests.compat.urljoin(r.url,a.get('href'))} for a in s.find_all('a',href=True)];(P/(n+'-links.json')).write_text(json.dumps(links,ensure_ascii=False,indent=2));return {'name':n,'status':r.status_code,'url':r.url,'bytes':len(r.content),'links':[x for x in links if any(t in x['text'] for t in ['학사','시간표','수강','Manual','download','Download','강의'])][:30]}
 except Exception as e:return {'name':n,'error':str(e),'url':u}
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as e:
 results=list(e.map(go,json.loads(sys.argv[1]).items()))
 for x in results:print(json.dumps(x,ensure_ascii=False))
 with (P/'attempts.jsonl').open('a') as f:
  for x in results:f.write(json.dumps(x,ensure_ascii=False)+'\n')
