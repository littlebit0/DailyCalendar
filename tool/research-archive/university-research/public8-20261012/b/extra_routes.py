import requests,bs4,pathlib,json,hashlib,concurrent.futures
P=pathlib.Path(__file__).parent
jobs=[('deu-rules','https://www.deu.ac.kr/www/rules.do'),('deu-exchange-bnue','https://lms.pknu.ac.kr/ilos/community/notice_view_form.acl?ARTL_NUM=10018567&SCH_KEY=T&SCH_TARGET=&SCH_VALUE=2%ED%95%99%EA%B8%B0&display=20&start=1'),('deu-summer-exchange','https://lms.pknu.ac.kr/ilos/community/notice_view_form.acl?ARTL_NUM=9590111&SCH_KEY=T&SCH_TARGET=&SCH_VALUE=&display=20&start=1'),('dju-exchange-pcu','https://hakgwa.pcu.ac.kr/jlac/article/college_jlac_notice/37512'),('deu-accounting-registration-search','https://accounting.deu.ac.kr/account/sub06_03.do?mode=list&srSearchKey=article_title&srSearchVal=%EC%88%98%EA%B0%95%EC%8B%A0%EC%B2%AD')]
def f(x):
 n,u=x
 try:
  r=requests.get(u,timeout=25,headers={'User-Agent':'Mozilla/5.0'});(P/(n+'.html')).write_bytes(r.content);s=bs4.BeautifulSoup(r.content,'html.parser');(P/(n+'.txt')).write_text(s.get_text(' ',strip=True)); links=[{'label':a.get_text(' ',strip=True),'url':requests.compat.urljoin(r.url,a.get('href',''))} for a in s.select('a[href]')];(P/(n+'-links.json')).write_text(json.dumps(links,ensure_ascii=False,indent=2));return dict(name=n,url=u,responseUrl=r.url,httpStatus=r.status_code,bytes=len(r.content),sha256=hashlib.sha256(r.content).hexdigest(),links=[a for a in links if any(z in a['label'] for z in ['동의','붙임','시간','학사','규정','수강'])])
 except Exception as e:return dict(name=n,url=u,error=str(e))
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex: rows=list(ex.map(f,jobs))
a=json.loads((P/'source-ledger.json').read_text());a.extend(rows);(P/'source-ledger.json').write_text(json.dumps(a,ensure_ascii=False,indent=2));print(json.dumps(rows,ensure_ascii=False,indent=2))
