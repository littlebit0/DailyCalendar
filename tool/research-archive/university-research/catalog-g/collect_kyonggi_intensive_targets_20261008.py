"""Known public course notices, whitelist actual education and published attachments."""
import json,pathlib,urllib.request,urllib.parse,time
from html.parser import HTMLParser
R=pathlib.Path(__file__).resolve().parent
from skku_inline_private_education_filter import filter_education
class Notice(HTMLParser):
 def __init__(self):super().__init__();self.depth=0;self.parts=[];self.links=[]
 def handle_starttag(self,t,a):
  attrs=dict(a)
  if t=='div':
   if self.depth:self.depth+=1
   elif 'contenttext' in attrs.get('class','').split():self.depth=1
  if self.depth and t in ['br','p','tr']:self.parts.append('\n')
  if t=='a' and 'downloadBbsFile.do' in attrs.get('href',''):self.links.append(attrs['href'])
 def handle_endtag(self,t):
  if t=='div' and self.depth:self.depth-=1
 def handle_data(self,d):
  if self.depth:self.parts.append(d)
rows=[]
for number in ['625809','625720','626310']:
 url=f'https://www.kyonggi.ac.kr/www/selectBbsNttView.do?key=7520&bbsNo=1073&nttNo={number}'
 with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30) as response:
  assert response.status==200;body=response.read(2000000).decode('utf-8')
 p=Notice();p.feed(body);text,m,l=filter_education('\n'.join(x.strip() for x in ''.join(p.parts).splitlines() if x.strip()))
 rows.append({'notice':number,'sourceUrl':url,'status':200,'educationalText':text,'actualPublicAttachments':list(dict.fromkeys(urllib.parse.urljoin(url,x) for x in p.links)),'maskedPrivateTokens':m,'privateLinesRemoved':l});time.sleep(.8)
(R/'kyonggi-current-intensive-target-context-20261008.json').write_text(json.dumps({'researchOnly':True,'notRegistrationApproval':True,'records':rows},ensure_ascii=False,indent=2)+'\n');print(json.dumps(rows,ensure_ascii=False))
