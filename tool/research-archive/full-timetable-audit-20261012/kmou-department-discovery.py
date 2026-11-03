import urllib.request,pathlib,json,hashlib,concurrent.futures,urllib.parse
from lxml import html
D=pathlib.Path(__file__).parent/'kmou-new-department-discovery';D.mkdir(exist_ok=True)
start='https://www.kmou.ac.kr/mmt/na/ntt/selectNttInfo.do?currPage=1&mi=4938&nttSn=10370797'
with urllib.request.urlopen(start,timeout=20) as r:b=r.read()
node=html.fromstring(b,parser=html.HTMLParser(encoding='utf-8'));links=[]
for a in node.xpath('//a[@href]'):
 label=' '.join(a.text_content().split());url=urllib.parse.urljoin(start,a.get('href'));path=urllib.parse.urlparse(url).path
 if label in ['조선해양시스템공학부','해양공학과','에너지자원공학과','해양공간건축학부','해양환경학전공','해양생물공학전공·수산바이오공학전공','해양스포츠과학과','기계공학부','전자소재공학전공','전파융합공학전공','데이터사이언스전공','인공지능공학부','물류시스템공학과','환경공학과','토목공학과','해운경영학부','해사법학부','국제무역경제학부','국제관계학과','해양행정학과','해양영어영문학과','동아시아학과','교직과','경제산업학부','법무비즈니스학부'] and path.count('/')<3:links.append((label,url))
links=list(dict.fromkeys(links))
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
