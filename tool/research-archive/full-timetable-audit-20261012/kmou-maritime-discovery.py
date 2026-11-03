import urllib.request,pathlib,json,hashlib,concurrent.futures,urllib.parse
from lxml import html
D=pathlib.Path(__file__).parent/'kmou-maritime-department-discovery';D.mkdir(exist_ok=True)
start='https://www.kmou.ac.kr/mmt/na/ntt/selectNttInfo.do?currPage=1&mi=4938&nttSn=10370797'
with urllib.request.urlopen(start,timeout=20) as r:b=r.read()
node=html.fromstring(b,parser=html.HTMLParser(encoding='utf-8'));links=[]
for a in node.xpath('//a[@href]'):
 label=' '.join(a.text_content().split());url=urllib.parse.urljoin(start,a.get('href'));path=urllib.parse.urlparse(url).path
 if label in ['항해융합학부','기관시스템공학부(2021)','해양경찰학부','해사수송과학부','기관시스템공학부','항해학부','기관공학부','해양플랜트운영학과','해사IT공학부','해사글로벌학부','선박운항과','해사인공지능·보안학부'] and path.count('/')<3:links.append((label,url))
links=[(name,url.replace('http://','https://',1)) for name,url in dict.fromkeys(links)]
def get(kv):
 label,url=kv;key=urllib.parse.urlparse(url).path.split('/')[1]
 try:
  with urllib.request.urlopen(url,timeout=18) as r:raw=r.read();actual=r.url
  (D/(key+'.html')).write_bytes(raw);n=html.fromstring(raw,parser=html.HTMLParser(encoding='utf-8'));find=[];board=[]
  for a in n.xpath('//a[@href]'):
   text=' '.join(a.text_content().split());href=urllib.parse.urljoin(actual,a.get('href'))
   if '시간표' in text or ('2026' in text and any(s in text for s in ['수강','개설','학기'])):find.append({'label':text,'url':href})
   if text in ['공지사항','학부공지','학과공지','학사공지','학과 공지사항'] and 'ntt' in href:board.append({'label':text,'url':href})
  return {'label':label,'url':url,'actualUrl':actual,'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'visibleCoursesLead':find,'observedBoards':list({x['url']:x for x in board}.values())}
 except Exception as e:return {'label':label,'url':url,'error':str(e)}
rows=list(concurrent.futures.ThreadPoolExecutor(8).map(get,links));(D/'main-receipt.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2));print('departments',len(rows));print(json.dumps([{k:r[k] for k in ['label','visibleCoursesLead','observedBoards'] if k in r} for r in rows],ensure_ascii=False,indent=2))
