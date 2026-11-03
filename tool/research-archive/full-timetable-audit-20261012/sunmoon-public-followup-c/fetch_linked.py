import urllib.request,pathlib,json,hashlib,concurrent.futures
from html.parser import HTMLParser
base=pathlib.Path(__file__).parent
urls={'nurs-index':'https://nurs.sunmoon.ac.kr/nurs/index.do','physical-index':'https://physical.sunmoon.ac.kr/physical/index.do','cs-index':'https://cs.sunmoon.ac.kr/cs/index.do','lms-public-widget':'https://lms.sunmoon.ac.kr/js/front/widget.app.js?version=5.51.7'}
class P(HTMLParser):
 def __init__(self):super().__init__();self.a=None;self.out=[]
 def handle_starttag(self,t,a):
  if t=='a':self.a=[dict(a).get('href'),[]]
 def handle_data(self,d):
  if self.a:self.a[1].append(d)
 def handle_endtag(self,t):
  if t=='a' and self.a:
   s=' '.join(''.join(self.a[1]).split());h=self.a[0]
   if any(x in s for x in ['시간표','2026','수강','개설','공지']):self.out.append({'label':s,'href':h})
   self.a=None
receipts=[]
def get(k,u):
 try:
  with urllib.request.urlopen(u,timeout=20) as r:d=r.read();final=r.url;status=r.status
  f=base/(k+'.html');f.write_bytes(d);s=d.decode('utf-8',errors='replace');p=P();p.feed(s)
  return {'file':str(f),'url':u,'finalUrl':final,'status':status,'bytes':len(d),'sha256':hashlib.sha256(d).hexdigest(),'links':p.out}
 except Exception as e:return {'url':u,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:receipts=list(ex.map(lambda z:get(*z),urls.items()))
(base/'receipt-linked-pages.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2))
for r in receipts:print(json.dumps(r,ensure_ascii=False))
