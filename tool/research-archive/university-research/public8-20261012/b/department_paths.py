import requests,pathlib,bs4,json,hashlib,concurrent.futures
P=pathlib.Path(__file__).parent
jobs=[('konyang-mie-department','https://mie.konyang.ac.kr/'),('konyang-physio-department','https://kypt.konyang.ac.kr/'),('konyang-pharm-department','https://pharm.konyang.ac.kr/'),('dju-mgmt-department','https://www.dju.ac.kr/business/main.do')]
def f(job):
 name,u=job
 try:
  r=requests.get(u,headers={'User-Agent':'Mozilla/5.0'},timeout=30);(P/(name+'.html')).write_bytes(r.content);s=bs4.BeautifulSoup(r.content,'html.parser');(P/(name+'.txt')).write_text(s.get_text(' ',strip=True));links=[{'label':a.get_text(' ',strip=True),'url':requests.compat.urljoin(r.url,a.get('href',''))}for a in s.select('a[href]')];(P/(name+'-links.json')).write_text(json.dumps(links,ensure_ascii=False,indent=2));return {'name':name,'url':u,'responseUrl':r.url,'httpStatus':r.status_code,'bytes':len(r.content),'sha256':hashlib.sha256(r.content).hexdigest(),'publicLinks':[x for x in links if any(v in x['label'] for v in ['시간표','수강','공지사항'])]}
 except Exception as e:return {'name':name,'url':u,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=3)as e:r=list(e.map(f,jobs))
p=P/'source-ledger.json';p.write_text(json.dumps(json.loads(p.read_text())+r,ensure_ascii=False,indent=2));print(json.dumps(r,ensure_ascii=False,indent=2))
