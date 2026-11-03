import pathlib,json,sys,hashlib,re
from html.parser import HTMLParser
class PublicHTML(HTMLParser):
 def __init__(self):super().__init__();self.parts=[];self.links=[];self.skip=0;self.href=None;self.label=[]
 def handle_starttag(self,t,a):
  if t in ['script','style']:self.skip+=1
  if t=='a':self.href=dict(a).get('href');self.label=[]
 def handle_endtag(self,t):
  if t in ['script','style']:self.skip=max(0,self.skip-1)
  if t=='a' and self.href:self.links.append({'title':' '.join(self.label),'href':self.href});self.href=None
 def handle_data(self,s):
  if not self.skip:self.parts.append(s)
  if self.href:self.label.append(s)
p=pathlib.Path(__file__).parent;sys.path.insert(0,str(p.parent.parent/'catalog-g'))
from audit_skku_public_operating_plans import SpacedPublic,education
client=SpacedPublic('KO');url='https://lahaye.skku.edu/physics/';result={'sourceOnly':True,'sourceURL':url,'observedParentEducationalSource':'GEDB008-44 own attachment https://lahaye.skku.edu/physics/#gp1','SDKExecuted':False,'rawBytesSaved':False}
try:
 body=client.download(url);result['rawSHA256']=hashlib.sha256(body).hexdigest();soup=PublicHTML();soup.feed(body.decode('utf-8'));body=None
 raw='\n'.join(soup.parts);safe,n=education(raw);safe=re.sub(r'https?://\S+','[connection URL suppressed]',safe);result['educationFullText']=safe;result['privacyLinesOmitted']=n
 links=[]
 for a in soup.links:
  title=a['title'];href=a['href']
  if re.search(r'lesson|plan|syllabus|general physics|2026|gp1|gp2',title+' '+href,re.I) and not re.search(r'zoom|mailto|login|signin|student|register|password|roster',href,re.I):links.append({'title':title,'observedHref':href})
 result['observedEducationalRelevantLinks']=links;result['status']='one normal professor public chain read'
except Exception as e:result['status']='stopped without retry or bypass';result['failureType']=type(e).__name__
(p/'observed-professor-public-website.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(result['status'])
