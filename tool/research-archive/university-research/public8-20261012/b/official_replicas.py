import requests,bs4,pathlib,json,hashlib,concurrent.futures
P=pathlib.Path(__file__).parent
jobs=[('deu-summer-kosin','https://www.kosin.ac.kr/kr/?idx=45359&mode=view&pCode=haksa&pg=2'),('dju-summer-hanseo','https://www.hanseo.ac.kr/boardCnts/view.do?boardID=298&boardSeq=129015&lev=0&m=040101&opType=N&page=1&s=ta&searchType=null&statusYN=W'),('konyang-cyber-exchange','https://www.konyang.ac.kr/cop/bbs/BBSMSTR_000000000582/selectBoardArticle.do?kind=&mno=sitemap_02&nttId=291560&pageIndex=1&searchCnd=&searchWrd=')]
def f(x):
 n,u=x
 try:
  r=requests.get(u,timeout=30);(P/(n+'.html')).write_bytes(r.content);s=bs4.BeautifulSoup(r.content,'html.parser');(P/(n+'.txt')).write_text(s.get_text(' ',strip=True));a=[{'label':z.text.strip(),'url':requests.compat.urljoin(r.url,z['href'])}for z in s.select('a[href]')if any(v in z.text for v in ['붙임','동의','대전','계절','개설'])];(P/(n+'-links.json')).write_text(json.dumps(a,ensure_ascii=False,indent=2));return dict(name=n,url=u,responseUrl=r.url,httpStatus=r.status_code,sha256=hashlib.sha256(r.content).hexdigest(),links=a)
 except Exception as e:return dict(name=n,url=u,error=str(e))
with concurrent.futures.ThreadPoolExecutor(max_workers=3)as ex:r=list(ex.map(f,jobs))
a=json.loads((P/'source-ledger.json').read_text());a.extend(r);(P/'source-ledger.json').write_text(json.dumps(a,ensure_ascii=False,indent=2));print(json.dumps(r,ensure_ascii=False,indent=2))
