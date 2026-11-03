import urllib.request,pathlib,concurrent.futures,json
from lxml import html
S=pathlib.Path('work/course-owner-filter-20261012/agent-a-sources')
x={'hanbat-sitemap':'https://www.hanbat.ac.kr/electro/sitemap.do','changwon-guide':'https://www.changwon.ac.kr/portal/cm/cntnts/cntntsView.do?cntntsId=6630&mi=18410','hansei-main':'https://hansei.ac.kr/','catholic-colleges':'https://www.catholic.ac.kr/ko/academics/edu_undergraduate16.do','hongik-academics':'https://www.hongik.ac.kr/kr/education/university-seoul.do'}
def f(t):
 k,url=t
 try:
  q=urllib.request.urlopen(url,timeout=20);s=q.read().decode(q.headers.get_content_charset() or 'utf-8',errors='replace');(S/(k+'.html')).write_text(s);return k,url,None
 except Exception as e:return k,url,str(e)
r=list(concurrent.futures.ThreadPoolExecutor(max_workers=5).map(f,x.items()));print(r);json.dump(r,open(S/'lastfetch-index.json','w'),ensure_ascii=False,indent=2)
