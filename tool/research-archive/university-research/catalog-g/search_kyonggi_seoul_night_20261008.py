"""Submit the already observed ordinary public search form; educational links only."""
import json,pathlib,re,time,urllib.parse,urllib.request
from html.parser import HTMLParser
R=pathlib.Path(__file__).resolve().parent
from skku_inline_private_education_filter import filter_education
fields=json.loads((R.parent/'catalog-s'/'kyonggi-current-published-search-requests.json').read_text())[0]['publishedFields']
class Links(HTMLParser):
 def __init__(self):super().__init__();self.href=None;self.text=[];self.rows=[]
 def handle_starttag(self,t,a):
  if t=='a':self.href=dict(a).get('href');self.text=[]
 def handle_data(self,d):
  if self.href:self.text.append(d)
 def handle_endtag(self,t):
  if t=='a' and self.href:
   if 'nttNo=' in self.href:
    safe,m,l=filter_education(' '.join(''.join(self.text).split()));self.rows.append({'url':urllib.parse.urljoin('https://www.kyonggi.ac.kr',self.href),'title':safe})
   self.href=None
results=[]
for keyword in ['2026-2 관광문화대학 시간표','2026-2 서울캠퍼스 시간표','2026-2 야간 시간표']:
 params=dict(fields,kwd=keyword);req=urllib.request.Request('https://www.kyonggi.ac.kr/search/search.do',data=urllib.parse.urlencode(params).encode(),headers={'User-Agent':'Mozilla/5.0','Content-Type':'application/x-www-form-urlencoded'})
 with urllib.request.urlopen(req,timeout=30) as response:
  assert response.status==200;body=response.read(2000000).decode('utf-8')
 p=Links();p.feed(body);rows=list({(x['url'],x['title']):x for x in p.rows}.values())
 results.append({'keyword':keyword,'actualPublishedFormFields':params,'status':200,'publishedNoticeLinks':rows});time.sleep(.8)
(R/'kyonggi-seoul-night-current-search-20261008.json').write_text(json.dumps({'researchOnly':True,'requests':results,'noMissingHitImpossibleClaim':True},ensure_ascii=False,indent=2)+'\n');print(json.dumps([{'keyword':x['keyword'],'links':x['publishedNoticeLinks']} for x in results],ensure_ascii=False))
