import sys,pathlib,json,re,hashlib
p=pathlib.Path(__file__).parent;sys.path.insert(0,str(p.parent.parent/'catalog-g'))
from audit_skku_public_operating_plans import SpacedPublic
from read_skku_published_office_plan import hwp_text
f=p/'spt4004-41-full-education.json';d=json.load(open(f));body=SpacedPublic('KO').download(d['sourceURL']);assert hashlib.sha256(body).hexdigest()==d['sha256'];raw=hwp_text(body);body=None;roleblock=raw.split('▣ 강의담당자',1)[1].split('▣ 강의 장소',1)[0];names=[]
for line in roleblock.splitlines():
 match=re.match(r'^\s*([가-힣]{2,4})(?:\s|\(|$)',line)
 if match and match[1] not in ['교수','성명','연락처','이메일','강의담당']:names.append(match[1])
d['ownPrintedEducationalInstructorNames']=names;d['safeEducationalInstructorRoleRecoveredBeforeContactSuppression']={'role':'▣ 강의담당자','KoreanNameLiterals':names,'originalRawSHAExact':True,'contactMixedSourceLineNotSaved':True};f.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');raw=None;roleblock=None;print('Safe educational role names:',names)
