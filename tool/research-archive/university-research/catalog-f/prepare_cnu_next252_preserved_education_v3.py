"""Keep short actual public enrollment restrictions from current educational plans."""
import copy, hashlib, json
from pathlib import Path
R=Path(__file__).resolve().parent
facts={
 '1101-7019-40':'선수학습 안내: 한글 맞춤법과 국어 문법에 대한 이해.',
 '1101-3006-00':'국어학개론 수강 권장.',
 '1102-7013-00':'한국어로 진행되며 한국어 사용이 필요한 수업.',
}
name='cnu-unknown-2026-2.whole-checkpoint-next252-planned-regular240-eligibility-v2.json'
base=json.loads((R/name).read_text());out=copy.deepcopy(base)
for c in out['courses']:
 cid=c['sourceEducation']['courseId']
 if cid not in facts:continue
 src=json.loads((R/'cnu-current252-angle-recovery-recovered-education-20261008'/f'{cid}.json').read_text())
 assert c['scheduleStatus']=='scheduled'
 c['sourceEducation']['publicPlanEnrollmentFacts']={'sourceResponseSHA256':src['sourceResponseSHA256'],'shortEducationNote':facts[cid],'originalCatalogRestrictionsAlsoPreserved':True,'eligibilityNotSilentlyInferred':True}
 for dep,text in c['departmentRemarks'].items():c['departmentRemarks'][dep]=text+'\n수강 대상 안내: '+facts[cid]
for old,new in zip(base['courses'],out['courses']):
 assert old['schedules']==new['schedules']
 assert old['sourceEducation'].get('originalEducationFields')==new['sourceEducation'].get('originalEducationFields')
 if old['sourceEducation']['courseId'] not in facts:assert old==new
out['verificationScope']='Current252 public plans reread with literal educational angles preserved;41courses125educationfields restored but actual operating changes0. Three short preparation/Korean-language facts added; all original252/5405 schedules and metadata, actual12/172 unchanged.'
f=R/'cnu-unknown-2026-2.whole-checkpoint-next252-preserved-education-v3.json';f.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
a=json.loads((R/'cnu-next252-planned-regular240-eligibility-v2-candidate-audit.json').read_text());a.update(candidate=f.name,candidateSHA256=hashlib.sha256(f.read_bytes()).hexdigest(),prior252CandidateSHA256=hashlib.sha256((R/name).read_bytes()).hexdigest(),newPlanEnrollmentFacts={**json.loads((R/'cnu-next252-planned-regular240-eligibility-v2-candidate-audit.json').read_text())['newPlanEnrollmentFacts'],**facts},newBatchEnrollmentFacts=facts,enrollmentNotesChangedCourses=3,allMeetingsAndOriginalMetadataUnchangedFromPrior252=True,wholePublicPlanNotBundled=True,current252RecoveredEducationProof='cnu-current252-literal-angle-and-contact-semantic-final-audit.json')
(R/'cnu-next252-preserved-education-v3-candidate-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n')
print(f.name,a['candidateSHA256'],'252courses5405meetings3recoverededucationnotes')
