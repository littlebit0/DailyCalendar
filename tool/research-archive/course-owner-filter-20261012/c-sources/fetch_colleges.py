exec(open('work/course-owner-filter-20261012/c-sources/fetch_homes.py').read().split('rs=list')[0].split('def get')[0])
import re,html,urllib.parse
rs=json.load(open(P/'home-receipts.json'));jobs=[]
for r in rs:
 if r['university']not in ['pnu','sookmyung','syu']:continue
 b=pathlib.Path(r['file']).read_text();seen=set()
 for url,txt in re.findall(r'<a\b[^>]*href=[\'"]([^\'"]+)[\'"][^>]*>(.*?)</a>',b,re.S):
  col=html.unescape(re.sub('<[^>]+>','',txt)).strip()
  if not re.fullmatch(r'[가-힣·A-Za-z ()&-]{1,30}대학',col)or col=='단과대학':continue
  url=urllib.parse.urljoin(r['sourceUrl'],html.unescape(url)).replace('http:','https:')
  if (col,url)in seen:continue
  seen.add((col,url));jobs.append((r['university'],col,url))
for u,url in [('swu','https://www.swu.ac.kr/swu/553/subview.do'),('sungkyul','https://www.sungkyul.ac.kr/sites/skukr/index.do'),('sungkyul-table','https://www.sungkyul.ac.kr/global/10073/subview.do')]:jobs.append((u,'all',url))
def get(j):
 u,col,url=j;name=u+'-'+str(len(col))+str(sum(map(ord,col)))+'.html'
 try:
  b=urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=20).read().decode(errors='replace');P.joinpath(name).write_text(b);return dict(university=u,college=col,sourceUrl=url,file=str(P/name),bytes=len(b))
 except Exception as e:return dict(university=u,college=col,sourceUrl=url,error=str(e))
xs=list(concurrent.futures.ThreadPoolExecutor(max_workers=8).map(get,jobs));P.joinpath('college-receipts.json').write_text(json.dumps(xs,ensure_ascii=False,indent=2));print([(r['university'],r['college'],r.get('bytes',r.get('error')))for r in xs])
