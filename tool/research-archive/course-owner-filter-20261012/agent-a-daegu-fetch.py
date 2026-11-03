import urllib.request,pathlib,concurrent.futures
S=pathlib.Path('work/course-owner-filter-20261012/agent-a-sources')
def fetch(i):
 u='https://www.daegu.ac.kr/intro/'+str(i)
 try:
  b=urllib.request.urlopen(u,timeout=15).read().decode('utf-8',errors='replace');(S/('daegu-intro-'+str(i)+'.html')).write_text(b);return(i,len(b))
 except Exception as e:return(i,str(e))
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as e:print(list(e.map(fetch,range(15))))
