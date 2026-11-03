import pathlib,requests,bs4,json,hashlib,concurrent.futures
P=pathlib.Path(__file__).parent
jobs=[('deu-door','https://door.deu.ac.kr/'),('dju-lms','https://lms.dju.ac.kr/'),('konyang-lms','https://lms.konyang.ac.kr/'),('dju-language-public','https://www.dju.ac.kr/communicationclinic/main.do'),('konyang-bio','https://primecics.konyang.ac.kr/cop/bbs/BBSMSTR_000000002223/selectBoardList.do')]
def fetch(item):
 name,url=item
 try:
  r=requests.get(url,headers={'User-Agent':'Mozilla/5.0'},timeout=30);(P/(name+'.html')).write_bytes(r.content);s=bs4.BeautifulSoup(r.content,'html.parser');(P/(name+'.txt')).write_text(s.get_text(' ',strip=True));links=[{'label':a.get_text(' ',strip=True),'url':requests.compat.urljoin(r.url,a.get('href',''))}for a in s.select('a[href]')];(P/(name+'-links.json')).write_text(json.dumps(links,ensure_ascii=False,indent=2));return {'name':name,'url':url,'responseUrl':r.url,'httpStatus':r.status_code,'bytes':len(r.content),'sha256':hashlib.sha256(r.content).hexdigest(),'title':s.title.text if s.title else '', 'newPublicCoursePaths':[a for a in links if any(v in a['label'] for v in ['강좌','강의','과목','시간표','Guest','guest'])]}
 except Exception as e:return {'name':name,'url':url,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=3)as e:rows=list(e.map(fetch,jobs))
(P/'source-ledger.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2));print(json.dumps(rows,ensure_ascii=False,indent=2))
