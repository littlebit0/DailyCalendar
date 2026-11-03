import requests,pathlib,json,concurrent.futures
from bs4 import BeautifulSoup
P=pathlib.Path(__file__).parent
U={'sangji-search':'https://sangji.ac.kr/prog/bbsArticle/BBSMSTR_000000000041/list.do?cmsNoStr=28&searchKeyword=%EC%88%98%EA%B0%95%ED%8E%B8%EB%9E%8C','hyupsung-search':'https://www.uhs.ac.kr/portalBbs/uhs/4/list.do?srchWrd=%EC%8B%9C%EA%B0%84%ED%91%9C&srchColumn=title','sungkyul-fall-search':'https://www.sungkyul.ac.kr/bbs/skukr/96/artclList.do?srchWrd=2026-2&srchColumn=sj','hansei-eclass':'https://eclass.hansei.ac.kr/ilos/st/main/course_ing_list_form.acl','sunmoon-eclass':'https://lms1.sunmoon.ac.kr/ilos/st/main/course_ing_list_form.acl'}
def go(x):
 n,u=x
 try:
  r=requests.get(u,timeout=40);r.encoding='utf-8';(P/(n+'.html')).write_text(r.text);s=BeautifulSoup(r.text,'html.parser');(P/(n+'.txt')).write_text(s.get_text(' ',strip=True));links=[{'text':a.get_text(' ',strip=True),'url':requests.compat.urljoin(r.url,a['href']),'onclick':a.get('onclick','')} for a in s.find_all('a',href=True)];(P/(n+'-links.json')).write_text(json.dumps(links,ensure_ascii=False,indent=2));return n,r.status_code,len(r.content),[x for x in links if any(t in x['text'] for t in ['편람','시간표','2026-2'])]
 except Exception as e:return n,str(e)
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as e:
 for x in e.map(go,U.items()):print(str(x)[:2200])
