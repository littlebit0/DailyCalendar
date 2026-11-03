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
url='https://www.kyonggi.ac.kr/www/contents.do?key=8430'
with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30) as response:
 assert response.status==200;body=response.read(2000000).decode('utf-8')
class Clock(HTMLParser):
 def __init__(self):super().__init__();self.depth=0;self.parts=[]
 def handle_starttag(self,t,a):
  attrs=dict(a)
  if t=='div':
   if self.depth:self.depth+=1
   elif 'content' in attrs.get('class','').split() or 'cts8430' in attrs.get('class','').split():self.depth=1
  if self.depth and t in ['br','p','tr','td','th','h4']:self.parts.append('\n')
 def handle_endtag(self,t):
  if t=='div' and self.depth:self.depth-=1
 def handle_data(self,d):
  if self.depth:self.parts.append(d)
p=Clock();p.feed(body);text='\n'.join(x.strip() for x in ''.join(p.parts).splitlines() if x.strip())
# Select only actual instructional headings/table; no footer/contact fields.
a=text.find('1. 수원캠퍼스');b=text.find('콘텐츠 정보',a)
assert a>=0
text=text[a:b if b>=0 else len(text)]
safe,m,l=filter_education(text)
assert '17:50' in safe.replace(' ','')
(R/'kyonggi-current-official-clock-20261008.json').write_text(json.dumps({'researchOnly':True,'sourceUrl':url,'status':200,'readDate':'2026-10-08','pageLastModified':'2023-03-29','currentlyPublishedOfficialGuidance':True,'educationalClockText':safe,'maskedPrivateTokens':m,'privateLinesRemoved':l},ensure_ascii=False,indent=2)+'\n');print(safe)
