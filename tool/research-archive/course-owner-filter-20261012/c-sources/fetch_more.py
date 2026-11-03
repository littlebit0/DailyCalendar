import json,urllib.request,urllib.parse,concurrent.futures,pathlib,re,html
P=pathlib.Path('work/course-owner-filter-20261012/c-sources');jobs=[]
b=pathlib.Path('work/university-research/calendar-a/sch-home-main.html').read_text()
for url,t in re.findall(r'<a[^>]*href=[\'"]([^\'"]+)[\'"][^>]*>(.*?)</a>',b,re.S):
 col=html.unescape(re.sub('<[^>]+>','',t)).strip()
 if col.endswith('대학') and url.startswith('/sch/03/') and col not in ['단과대학']:jobs.append(('sch',col,'https://home.sch.ac.kr'+url))
for u,col,url in [('smu','all','https://www.smu.ac.kr/ko/edu/cheonan01.do'),('uos','all','https://www.uos.ac.kr/kor/html/uaInfo/major/curriculum/curriculum2023.do?identified=anonymous&menuid=2000003003004001000'),('sku','all','https://www.skuniv.ac.kr/college-of-humanities-and-social-science'),('postech','all','https://www.postech.ac.kr/kor/education/department.do'),('postech-org','all','https://www.postech.ac.kr/kor/university-introduction/organization.do'),('ulsan','아산아너스칼리지','https://cge.ulsan.ac.kr/cge/6895'),('unist','all','https://www.unist.ac.kr/unist/about/organization.do')]:jobs.append((u,col,url))
for u in ['tuk']:
 b=P.joinpath(u+'-home.html').read_text()
 for url,t in re.findall(r'<a[^>]*href=[\'"]([^\'"]+)[\'"][^>]*>(.*?)</a>',b,re.S):
  col=html.unescape(re.sub('<[^>]+>','',t)).strip()
  if len(col)<30 and col.endswith(('대학','스쿨')) and not any(w in col for w in ['교류대학','글로컬대학','학년도','단과대학','수도권대학','한국외대']):
   base={'scnu':'https://www.scnu.ac.kr/','tuk':'https://www.tukorea.ac.kr/','sunmoon':'https://lily.sunmoon.ac.kr/','yu':'https://www.yu.ac.kr/'}[u];url=urllib.parse.urljoin(base,html.unescape(url)).replace('http:','https:')
   if not url.split('/')[-1].startswith('#'):jobs.append((u,col,url))
jobs=list(dict.fromkeys(jobs))
def get(j):
 u,col,url=j;name=u+'-more-'+__import__('hashlib').sha256(url.encode()).hexdigest()[:12]+'.html'
 try:
  with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=18)as r:b=r.read().decode(errors='replace');url=r.url
  P.joinpath(name).write_text(b);return dict(university=u,college=col,sourceUrl=url,file=str(P/name),bytes=len(b))
 except Exception as e:return dict(university=u,college=col,sourceUrl=url,error=str(e))
xs=list(concurrent.futures.ThreadPoolExecutor(max_workers=10).map(get,jobs));P.joinpath('more-receipts.json').write_text(json.dumps(xs,ensure_ascii=False,indent=2));print([(r['university'],r['college'],r.get('bytes',r.get('error')))for r in xs])
