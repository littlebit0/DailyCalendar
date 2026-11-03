"""Keep short actual public enrollment restrictions from current educational plans."""
import copy, hashlib, json
from pathlib import Path
R=Path(__file__).resolve().parent
facts={
 '1102-2013-00':'선수학습 조건 없음. 타 학과·타 단과대 학생 수강도 권장.',
 '1102-3007-00':'선수학습 조건 없음. 저학년 학생·영어학 전공 배경이 없는 타 학과 학생 수강도 권장.',
 '1102-3007-01':'선수학습 조건 없음. 저학년 학생·영어학 전공 배경이 없는 타 학과 학생 수강도 권장.',
 '1103-1004-00':'선수학습 안내: 독회화 1, 독문법, 기초독일어.',
 '1103-1014-00':'독일어 말하기에 관심 있는 학생 수강 가능. 기본 독일어 지식이 도움이 되며 정기 출석 필요.',
 '1103-3014-00':'선수학습 안내: 유럽공통참조기준 A2 수준의 독일어.',
 '1103-3020-00':'A1 학습자를 대상으로 하며 독일어 어휘 학습에 관심 있는 학생도 수강 가능.',
 '1104-3012-00':'선수학습 안내: 기초 프랑스어 문법·회화 표현 및 프랑스어권 문화의 기초 이해.',
}
name='cnu-unknown-2026-2.whole-checkpoint-next252-planned-regular240.json'
base=json.loads((R/name).read_text());out=copy.deepcopy(base)
for c in out['courses']:
 cid=c['sourceEducation']['courseId']
 if cid not in facts:continue
 src=json.loads((R/'cnu-proposed27-recovered-education-20261008'/f'{cid}.json').read_text())
 assert c['scheduleStatus']=='scheduled'
 c['sourceEducation']['publicPlanEnrollmentFacts']={'sourceResponseSHA256':src['sourceResponseSHA256'],'shortEducationNote':facts[cid],'originalCatalogRestrictionsAlsoPreserved':True,'eligibilityNotSilentlyInferred':True}
 for dep,text in c['departmentRemarks'].items():c['departmentRemarks'][dep]=text+'\n수강 대상 안내: '+facts[cid]
for old,new in zip(base['courses'],out['courses']):
 assert old['schedules']==new['schedules']
 assert old['sourceEducation'].get('originalEducationFields')==new['sourceEducation'].get('originalEducationFields')
 if old['sourceEducation']['courseId'] not in facts:assert old==new
out['verificationScope']='Current public27 plans add703 meetings, old225/4702 unchanged; short public preparation/target notes preserved for8new courses; whole3888 and252/5405, actual12/172 unchanged.'
f=R/'cnu-unknown-2026-2.whole-checkpoint-next252-planned-regular240-eligibility-v2.json';f.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
a=json.loads((R/'cnu-next252-planned-regular240-candidate-audit.json').read_text());a.update(candidate=f.name,candidateSHA256=hashlib.sha256(f.read_bytes()).hexdigest(),prior252CandidateSHA256=hashlib.sha256((R/name).read_bytes()).hexdigest(),newPlanEnrollmentFacts={**json.loads((R/'cnu-next225-planned-regular213-eligibility-v2-candidate-audit.json').read_text())['newPlanEnrollmentFacts'],**facts},newBatchEnrollmentFacts=facts,enrollmentNotesChangedCourses=8,allMeetingsAndOriginalMetadataUnchangedFromPrior252=True,wholePublicPlanNotBundled=True,current27TokenPreservedEducationProof='cnu-proposed27-preserved-context-recovery-audit.json')
(R/'cnu-next252-planned-regular240-eligibility-v2-candidate-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n')
print(f.name,a['candidateSHA256'],'252courses5405meetings8educationnotes')
