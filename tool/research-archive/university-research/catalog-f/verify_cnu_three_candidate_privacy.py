"""Limited registration artifact audit: education only, original source fields preserved."""
import json,re,hashlib,datetime
from pathlib import Path
R=Path(__file__).resolve().parent
sources={r['COURSE_NO']:r for r in json.loads((R/'cnu-current-catalog-education-with-public-names.json').read_text())}
files=[R/f'cnu-{c}-2026-2.three-course-checkpoint.json' for c in ('daedeok','unknown')]
files.append(R/'cnu-whole-public-course-metadata-20261008.json')
findings=[];meetings=0;courses=0
DENIED_KEYS=re.compile(r'STAFF_NO|PHONE|EMAIL|PASSWORD|TOKEN|FRAMEWORK|SESSION|MNG_NO|ACCESS_ID',re.I)
CONTACT=re.compile(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|(?<!\d)0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)|(?<!\d)\d{3}[- ]\d{4}(?!\d)|(?<!\d)\d{3}\s+\d{4}\s+\d{4}(?!\d)')
def walk(x,path):
 if isinstance(x,dict):
  for k,v in x.items():
   if DENIED_KEYS.search(k):findings.append(path+':'+k)
   walk(v,path+':'+k)
 elif isinstance(x,list):
  for i,v in enumerate(x):walk(v,path+f'[{i}]')
 elif isinstance(x,str):
  if CONTACT.search(x):findings.append(path+':contact-pattern')
  if re.search(r'https?://',x) and not path.endswith(':sourceUrl'):findings.append(path+':URL')
for f in files:
 data=json.loads(f.read_text());walk(data,f.name)
 if 'schemaVersion' not in data:continue
 for c in data['courses']:
  courses+=1;original=sources[c['sourceEducation']['courseId']]
  assert c['professor']==(original['LT_STAFF_NM'] or '')
  assert c['classification']==original['CPTN_DIV_CD_FNM']
  assert c['sourceEducation']['nativeCurriculumClassification']==original['CURI_CPTN_DIV_NM']
  assert c['sourceEducation']['restrictionOriginal']==(original['TLSN_REST_INFO_CD_NM'] or '')
  assert c['sourceEducation']['remarksOriginal']==(original['TLSN_ANNM'] or '')
  for m in c['schedules']:
   d=datetime.date.fromisoformat(m['date']);assert d.isoweekday()==m['weekday']
   assert c['period']['startDate']<=m['date']<=c['period']['endDate']
   assert m['startMinute']<m['endMinute'];meetings+=1
assert not findings,findings
assert courses==3 and meetings==60
out={'verifiedOn':'2026-10-08','candidateCourses':courses,'actualDatedMeetings':meetings,'educationOnlyPrivacyFindings':findings,'publicNamesAndOriginalCategoriesRestrictionsRemarksPreserved':True,'wholePublicMetadataRows':len(sources),'hashes':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in files},'wholeSupportClaim':False}
(R/'cnu-three-candidate-privacy-audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False))
