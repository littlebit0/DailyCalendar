"""Resolve the actual relative link and parse public course operation in memory only."""
import hashlib,io,json,pathlib,re,time,urllib.parse,urllib.request
from html.parser import HTMLParser
import pdfplumber
R=pathlib.Path(__file__).resolve().parent
from skku_inline_private_education_filter import filter_education
class L(HTMLParser):
 def __init__(self):super().__init__();self.links=[]
 def handle_starttag(self,t,a):
  attrs=dict(a)
  if t=='a' and 'downloadBbsFile.do' in attrs.get('href',''):self.links.append(attrs['href'])
notice='https://www.kyonggi.ac.kr/www/selectBbsNttView.do?key=7520&bbsNo=1073&nttNo=625719'
with urllib.request.urlopen(urllib.request.Request(notice,headers={'User-Agent':'Mozilla/5.0'}),timeout=30) as r:
 assert r.status==200;p=L();p.feed(r.read(2000000).decode('utf-8'))
links=list(dict.fromkeys(p.links));assert len(links)==1
url=urllib.parse.urljoin(notice,links[0]);time.sleep(.8)
with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30) as r:
 assert r.status==200;body=r.read(12000000)
assert body.startswith(b'%PDF')
rows=[]
with pdfplumber.open(io.BytesIO(body)) as pdf:
 count=len(pdf.pages)
 for i,page in enumerate(pdf.pages):
  text=page.extract_text() or ''
  # Operating/curriculum overview only; no individual student worksheet answers.
  if re.search(r'강의계획|교과목\s*개요|수업\s*운영|집중수업|주차.*(?:활동|주제|내용)|1\s*주차',text):
   safe,m,l=filter_education(text);rows.append({'page':i+1,'educationalOperatingContext':safe,'maskedPrivateTokens':m,'privateLinesDiscarded':l})
a={'researchOnly':True,'noticeUrl':notice,'actualRawHref':links[0],'resolvedPublicAttachment':url,'status':200,'bytes':len(body),'sha256':hashlib.sha256(body).hexdigest(),'pageCount':count,'educationalOperatingPages':rows,'fullPDFOrWorkbookNotPersisted':True}
(R/'kyonggi-current-workbook-operating-evidence-20261008.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print('actualhref',links[0],'pages',count,'operatingpages',[(x['page'],x['educationalOperatingContext'][:900]) for x in rows])
