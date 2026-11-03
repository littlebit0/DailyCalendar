"""Combine the exact disjoint reviewed checkpoints; source metadata must agree."""
from pathlib import Path
import json,hashlib,collections
P=Path(__file__).parent
FIELDS=['sourceId','sourceDepartmentCode','sourceClassificationCode','campus','academicYear','semester','courseCode','courseName','section','professor','credits','departmentCredits','departments','departmentClassifications','sourceSchedule','sourceClassroom']
def prepare():
 manifest={};counts=collections.Counter();mismatches=[];allids=set();meeting_count=0
 for campus in ['dorim','damyang','unknown']:
  base=json.loads((P/f'mokpo-{campus}-2026-2.registration-candidate.json').read_text());courses={c['sourceId']:c for c in base['courses']};added=set()
  for kind in ['semantic','eligibility']:
   path=P/f'mokpo-{campus}-2026-2.{kind}-additions.json'
   for c in json.loads(path.read_text())['courses']:
    original=courses[c['sourceId']]
    assert c['sourceId'] not in added and not original['schedules']
    for field in FIELDS:
     if c[field]!=original[field]:mismatches.append({'sourceId':c['sourceId'],'field':field})
    # The sole remarks difference removes our prior generated pending annotation.
    assert c['departmentRemarks']=={d:s.split('\n운영 검토:')[0] for d,s in original['departmentRemarks'].items()}
    courses[c['sourceId']]=c;added.add(c['sourceId'])
  base['courses']=list(courses.values());f=P/f'mokpo-{campus}-2026-2.checkpoint-next.json';f.write_text(json.dumps(base,ensure_ascii=False,indent=2)+'\n');manifest[f.name]=hashlib.sha256(f.read_bytes()).hexdigest()
  for c in base['courses']:
   assert c['sourceId'] not in allids;allids.add(c['sourceId']);counts[c['scheduleStatus']]+=1;meeting_count+=len(c['schedules'])
 assert len(allids)==1307 and not mismatches
 result={'checkedAt':'2026-10-08','productionReady':False,'completionClaim':False,'wholeScope':1307,'counts':dict(counts),'datedMeetings':meeting_count,'exactEducationalMetadataMismatches':mismatches,'remarksOnlyGeneratedPendingAnnotationRemoved':True,'candidateSha256':manifest,'originalFixed615Changed':False,'newCollectionPerformed':False,'sourceCheckpoints':['registration-candidate','semantic-additions','eligibility-additions']}
 (P/'mokpo-checkpoint-next-manifest-20261008.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');return result
if __name__=='__main__':print(prepare()['counts'])
