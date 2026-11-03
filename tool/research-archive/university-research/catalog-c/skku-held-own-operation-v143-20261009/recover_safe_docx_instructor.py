import sys,pathlib,json,re,hashlib,io
from docx import Document
p=pathlib.Path(__file__).parent;sys.path.insert(0,str(p.parent.parent/'catalog-g'))
from audit_skku_public_operating_plans import SpacedPublic
f=p/'iks2052-01-full-education.json';d=json.load(open(f));body=SpacedPublic('KO').download(d['sourceURL']);assert hashlib.sha256(body).hexdigest()==d['sha256'];doc=Document(io.BytesIO(body));body=None;raw='\n'.join(x.text for x in doc.paragraphs);names=[]
for line in raw.splitlines():
 if re.search(r'(?i)Instructor|Professor|Lecturer',line):
  safe=re.split(r'(?i)(?:E-?mail|Phone|Tel|Contact|https?://|[A-Za-z0-9._%+-]+@|\d{2,3}[-)])',line,1)[0].strip(' ,;|')
  safe=re.sub(r'(?i)\([^)]*\)','',safe).strip()
  if len(safe)<100:names.append(safe)
d['safeEducationalInstructorRoleRecoveredBeforeContactSuppression']={'sourceRoleFragments':names,'originalRawSHAExact':True,'privateContactSaved':False};f.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(names);raw=None
