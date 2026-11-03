import requests,pathlib,bs4,json,hashlib,concurrent.futures
P=pathlib.Path(__file__).parent
jobs=[('dju-lms-main','https://lms.dju.ac.kr/home/mainHome/Form/main'),('konyang-lms-main','https://lms.konyang.ac.kr/main/MainView.dunet'),('konyang-course-policy','https://www.konyang.ac.kr/kor/sub06_01_04_01.do'),('konyang-medit','https://www.konyang.ac.kr/kor/sub03_05_02_01.do'),('konyang-physio','https://www.konyang.ac.kr/kor/sub03_04_07_01.do'),('konyang-bioeng','https://www.konyang.ac.kr/kor/sub03_05_05_01.do'),('dju-current-english','https://www.dju.ac.kr/communicationclinic/na/ntt/selectNttInfo.do?nttSn=553925&mi=3353&bbsId=1647')]
def f(job):
 name,u=job
 try:
  r=requests.get(u,headers={'User-Agent':'Mozilla/5.0'},timeout=30);(P/(name+'.html')).write_bytes(r.content);s=bs4.BeautifulSoup(r.content,'html.parser');(P/(name+'.txt')).write_text(s.get_text(' ',strip=True));links=[{'label':a.get_text(' ',strip=True),'url':requests.compat.urljoin(r.url,a.get('href',''))}for a in s.select('a[href]')];(P/(name+'-links.json')).write_text(json.dumps(links,ensure_ascii=False,indent=2));return {'name':name,'url':u,'responseUrl':r.url,'httpStatus':r.status_code,'bytes':len(r.content),'sha256':hashlib.sha256(r.content).hexdigest(),'publicLinks':[x for x in links if any(v in x['label'] for v in ['홈페이지','강의','강좌','과목','시간표','공개','Guest'])]}
 except Exception as e:return {'name':name,'url':u,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=3)as e:r=list(e.map(f,jobs))
p=P/'source-ledger.json';j=json.loads(p.read_text())+r;p.write_text(json.dumps(j,ensure_ascii=False,indent=2));print(json.dumps(r,ensure_ascii=False,indent=2))
