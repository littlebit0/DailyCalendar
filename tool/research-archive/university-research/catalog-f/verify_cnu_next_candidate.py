"""Audit an immutable research checkpoint against the public educational whitelist."""
import json,re,hashlib,datetime,sys
from pathlib import Path
R=Path(__file__).resolve().parent
suffix=sys.argv[1] if len(sys.argv)>1 else 'five'
files=[R/'cnu-daedeok-2026-2.whole-checkpoint.json',R/f'cnu-unknown-2026-2.whole-checkpoint-next-{suffix}.json']
sources={r['COURSE_NO']:r for r in json.loads((R/'cnu-current-catalog-education-with-public-names.json').read_text())}
findings=[];courses=[]
DENIED=re.compile(r'STAFF_NO|PHONE|EMAIL|PASSWORD|TOKEN|FRAMEWORK|SESSION|MNG_NO|ACCESS_ID',re.I)
CONTACT=re.compile(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|(?<!\d)0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)|(?<!\d)\d{3}[- ]\d{4}(?!\d)|(?<!\d)\d{3}\s+\d{4}\s+\d{4}(?!\d)')
def walk(x,path):
 if isinstance(x,dict):
  for k,v in x.items():
   if DENIED.search(k):findings.append(path+':'+k)
   walk(v,path+':'+k)
 elif isinstance(x,list):
  for i,v in enumerate(x):walk(v,path+f'[{i}]')
 elif isinstance(x,str):
  if CONTACT.search(x):findings.append(path+':contact')
  if re.search(r'https?://',x) and not path.endswith(':sourceUrl'):findings.append(path+':URL')
for f in files:
 d=json.loads(f.read_text());walk(d,f.name);courses.extend(d['courses'])
for c in courses:
 o=sources[c['sourceEducation']['courseId']]
 for key,source in [('professor','LT_STAFF_NM'),('classification','CPTN_DIV_CD_FNM')]:assert c[key]==(o[source] or '')
 
 if 'originalEducationFields' in c['sourceEducation']:
  for key,v in c['sourceEducation']['originalEducationFields'].items(): assert v==o[key]
 else:
  for key,source in [('nativeCurriculumClassification','CURI_CPTN_DIV_NM'),('restrictionOriginal','TLSN_REST_INFO_CD_NM'),('remarksOriginal','TLSN_ANNM')]:assert c['sourceEducation'][key]==(o[source] or '')
 for m in c['schedules']:
  assert datetime.date.fromisoformat(m['date']).isoweekday()==m['weekday']
  assert c['period']['startDate']<=m['date']<=c['period']['endDate']
  assert m['startMinute']<m['endMinute']
assert len(courses)==3888 and len({c['sourceEducation']['courseId'] for c in courses})==3888
assert not findings,findings
out={'verifiedOn':'2026-10-08','wholeCourses':len(courses),'scheduledCourses':sum(c['scheduleStatus']=='scheduled' for c in courses),'actualPrintedMeetings':sum(len(c['schedules']) for c in courses),'forbiddenFieldContactURLOrMeetingFindings':findings,'publicNamesAndNativeCategoriesRestrictionsRemarksPreserved':True,'hashes':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in files},'wholeSupportClaim':False}
(R/f'cnu-next-{suffix}-privacy-audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False))
