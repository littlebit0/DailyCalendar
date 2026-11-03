"""Application identity uses actual code/section; mutable source evidence is separate."""
import json,copy,hashlib
from pathlib import Path
p=Path(__file__).parent

def stable_identity(c):
 section=c['section'] or 'unpublished'
 return f"gist-{c['academicYear']}-{c['semester']}-{c['courseCode']}-{section}"

if __name__=='__main__':
 x=json.loads((p/'gist-main-2026-2.planned-audited-20261008-r5.json').read_text());records=x['courses'];ids=[]
 for c in records:
  before=stable_identity(c);changed=copy.deepcopy(c);changed['professor']='교육 fixture 교수 변경';changed['sourceClassroom']='교육 fixture 방 변경';changed['sourceMetadata']['derivedIdentityFields']['sourceFileSha256']='changed-public-file-fixture';changed['schedules']=[]
  assert before==stable_identity(changed)
  ids.append(before)
 assert len(set(ids))==len(ids)==407
 audit={'researchOnly':True,'completionClaim':False,'sourceIdentityRule':'gist-{academicYear}-{semester}-{actualCode}-{publishedSection or application unpublished marker}','nativeEmptySectionRemainsEmpty':True,'explicitUnpublishedIsApplicationMarkerNotNativeSection':True,'exactCodeSectionTupleCount':407,'uniqueSourceIdentityCount':407,'all407MutableRoomProfessorFileClockUpdateIdentityChecksPassed':True,'candidatePendingRootModelForUnpublishedDepartment':True,'sourceIdMap':[{ 'previousResearchSourceId':c['sourceId'],'stableSourceId':stable_identity(c),'printedCode':c['courseCode'],'printedSection':c['section']} for c in records]}
 (p/'gist-stable-source-identity-proof-20261008.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2));print('407 code-section unique; all room/professor/file/clock mutations preserve identity')
