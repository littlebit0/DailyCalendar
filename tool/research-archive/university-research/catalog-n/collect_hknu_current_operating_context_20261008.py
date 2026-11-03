"""Normal anonymous published current semester operating rules, education only."""
import urllib.request,json,pathlib,re,time,sys
from html.parser import HTMLParser
R=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(R.parent/'catalog-g'))
from skku_inline_private_education_filter import filter_education
class Text(HTMLParser):
 def __init__(self):super().__init__();self.parts=[];self.skip=0
 def handle_starttag(self,t,a):
  if t in ['script','style']:self.skip+=1
  elif t in ['br','p','td','th','tr','h1','h2','h3','h4','li']:self.parts.append('\n')
 def handle_endtag(self,t):
  if t in ['script','style']:self.skip=max(0,self.skip-1)
 def handle_data(self,d):
  if not self.skip:self.parts.append(d)
records=[]
for kind,url in [('currentMakeup','https://www.hknu.ac.kr/bbs/hksystem/243/98107/artclView.do'),('remoteGuideline','https://cedu.hknu.ac.kr/cedu/intro/board.do')]:
 with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30) as response:
  assert response.status==200;body=response.read(2000000).decode('utf-8')
 p=Text();p.feed(body);text='\n'.join(x.strip() for x in ''.join(p.parts).splitlines() if x.strip())
 if kind=='currentMakeup':
  start=text.find('추석 등 휴업일에 따른 보강 지정일');assert start>=0
  end=text.find('첨부파일',start);text=text[start:end if end>=0 else start+3000]
 else:
  start=text.find('제1조');assert start>=0
  end=text.find('관련사이트',start);text=text[start:end if end>=0 else len(text)]
 safe,m,l=filter_education(text)
 records.append({'kind':kind,'sourceUrl':url,'status':200,'readDate':'2026-10-08','educationalOperatingText':safe,'maskedPrivateTokens':m,'privateLinesRemoved':l});time.sleep(.8)
(R/'hknu-current-operating-guidance-20261008.json').write_text(json.dumps({'researchOnly':True,'records':records},ensure_ascii=False,indent=2)+'\n');print([(x['kind'],len(x['educationalOperatingText'])) for x in records])
