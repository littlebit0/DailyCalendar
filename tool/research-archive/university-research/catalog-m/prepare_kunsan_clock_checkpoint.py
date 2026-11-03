"""Raw educational checkpoint: original source clocks in actual model input key.
Not an app dataset: original general rows' absent department fields remain absent.
No generated department/category placeholders. Original797 file stays unchanged.
"""
from pathlib import Path
import json,copy,hashlib,collections
P=Path(__file__).parent
def prepare():
 path=P/'kunsan-current-whole-normalized-review-unregistered.json';original=json.loads(path.read_text());d=copy.deepcopy(original)
 live=json.loads((P/'kunsan-unknown-2026-2.explicit-live-mode-candidate.json').read_text())['courses'];new={c['sourceId']:c for c in live}
 corrected=0;meetings=0
 for index,c in enumerate(d['courses']):
  if c['sourceId'] in new:d['courses'][index]=copy.deepcopy(new[c['sourceId']]);continue
  if not c['schedules']:continue
  corrected+=1
  for m in c['schedules']:
   actual=m.pop('originalStartMinute');assert actual==m['startMinute']+10
   m['startMinute']=actual;meetings+=1
 d['counts']=dict(collections.Counter(c['scheduleStatus'] for c in d['courses']));d['appDatasetProjectionReady']=False;d['clockCheckpointOnly']=True;d['original797SourcePreserved']=True
 out=P/'kunsan-current-whole-clock-checkpoint-next-20261008.json';out.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
 assert corrected==797
 old={c['sourceId']:c for c in original['courses']}
 mismatches=[]
 for c in d['courses']:
  for field,value in old[c['sourceId']].items():
   if field in {'schedules','scheduleStatus','remarks'}:continue
   if c.get(field)!=value:mismatches.append({'sourceId':c['sourceId'],'field':field})
 assert not mismatches
 audit={'checkedAt':'2026-10-08','productionReady':False,'completionClaim':False,'wholeScope':1718,'exactOriginalEducationalMetadataMismatches':mismatches,'resolvedExplicitLiveMode':3,'scheduledClockRules':800,'originalScheduled797ClockFieldsCorrected':corrected,'correctedDatedMeetings':meetings,'finalClosureScopeStillUnverified':True,'appDatasetProjectionReady':False,'scheduledRowsMissingOriginalDepartmentFields':sum(not c['departments'] for c in d['courses'] if c['schedules']),'reason':'Source generic general rows have absent department/classification fields in prior normalized projection. Do not fabricate them or present raw checkpoint as whole UniversityDataset parse-ready. Raw source metadata retained for a future source-grounded projection.','candidateSha256':{out.name:hashlib.sha256(out.read_bytes()).hexdigest()},'original797SourceSha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 (P/'kunsan-clock-checkpoint-next-audit-20261008.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':prepare()
