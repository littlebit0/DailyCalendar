import urllib.request,pathlib,concurrent.futures,json
from lxml import html
S=pathlib.Path('work/course-owner-filter-20261012/agent-a-sources')
x={'dongguk-colleges':'https://www.dongguk.edu/page/853','dongguk-table':'https://www.dongguk.edu/eng/page/409','daegu-colleges':'https://www.daegu.ac.kr/page/1859'}
for n in [1,10,14,15,16]:x['catholic-college-'+str(n)]='https://www.catholic.ac.kr/ko/academics/edu_undergraduate'+str(n)+'.do'
def f(t):
 k,url=t
 try:
  q=urllib.request.urlopen(url,timeout=20);s=q.read().decode(q.headers.get_content_charset() or 'utf-8',errors='replace');(S/(k+'.html')).write_text(s);return k,url,None
 except Exception as e:return k,url,str(e)
r=list(concurrent.futures.ThreadPoolExecutor(max_workers=8).map(f,x.items()));print(r);json.dump(r,open(S/'fetch3-index.json','w'),ensure_ascii=False,indent=2)
