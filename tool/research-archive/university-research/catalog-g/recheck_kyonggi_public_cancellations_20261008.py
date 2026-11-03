"""Normal known official notices; retain only actual public cancellation fields."""
import json,pathlib,re,time,urllib.request
from html.parser import HTMLParser
R=pathlib.Path(__file__).resolve().parent
class Content(HTMLParser):
 def __init__(self):super().__init__();self.depth=0;self.items=[]
 def handle_starttag(self,tag,attrs):
  if tag=='div':
   if self.depth:self.depth+=1
   elif 'contenttext' in dict(attrs).get('class','').split():self.depth=1
  if self.depth and tag in ['br','tr']:self.items.append('\n')
 def handle_endtag(self,tag):
  if tag=='div' and self.depth:self.depth-=1
 def handle_data(self,data):
  if self.depth:self.items.append(data)
rows=[]
for number in ['625361','625587','625460']:
 url=f'https://www.kyonggi.ac.kr/www/selectBbsNttView.do?key=7520&bbsNo=1073&nttNo={number}'
 with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30) as r:
  assert r.status==200;body=r.read(2000000).decode('utf-8')
 parser=Content();parser.feed(body);text=''.join(parser.items)
 entries=[{'campus':camp,'registrationNumber':code,'educationalLine':line.strip()} for line in text.splitlines() for camp,code in re.findall(r'(수원|서울)\s+(\d{4})',line)]
 if number=='625460':
  assert '플랜트설계(1545)' in text
  entries=[{'campus':'수원','registrationNumber':'1545','educationalLine':'플랜트설계(1545) 수강인원 미달 폐강'}]
 rows.append({'sourceUrl':url,'notice':number,'entries':entries,'status':200});time.sleep(.8)
old=json.loads((R/'kyonggi-cancellation-crosscheck.json').read_text());oldkeys={(x['campus'],x['code']) for x in old};newkeys={(x['campus'],x['registrationNumber']) for r in rows for x in r['entries']};assert oldkeys==newkeys
out={'researchOnly':True,'checkedAt':'2026-10-08','samePreviouslyRecordedEducationalCancellationSet':True,'distinctCancellationRows':len(newkeys),'suwonCancellationRows':sum(c=='수원' for c,n in newkeys),'knownOfficialNoticesRechecked':rows,'doesNotClaimNoOtherUnpublishedChanges':True};(R/'kyonggi-current-public-cancellation-recheck-20261008.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print('same cancellation set',len(newkeys),'suwon',out['suwonCancellationRows'])
