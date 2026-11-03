"""Keep short actual public enrollment restrictions from current educational plans."""
import copy, hashlib, json
from pathlib import Path
R=Path(__file__).resolve().parent
facts={
 '1105-1009-00':'선수학습 안내: 중국어 발음과 성조 숙지.',
 '1105-1010-00':'중국어연습 이수 또는 이에 상응하는 기초 중국어 능력 필요.',
 '1105-1010-01':'중국어연습 이수 또는 이에 상응하는 기초 중국어 능력 필요.',
 '1105-7004-00':'중국어 모국어 사용자 및 중어중문학과 학생 수강 불가.',
 '1105-7004-03':'중국어에 관심 있는 학생 누구나 수강 가능.',
 '1105-2003-00':'중국문학사Ⅰ 선수 수강이 도움이 됨.',
 '1105-2020-00':'중국어 회화 2 이수 또는 이에 상응하는 중국어 능력 필요.',
 '1105-2021-00':'1학년 중국기초고문 수강이 도움이 됨.',
 '1105-2022-00':'별도 선수과목은 없으며 초급 중국어 문법·기초 회화 능력을 갖춘 학생 대상.',
 '1105-3020-00':'중국어 교과목 약 4학기 이수 또는 이에 상응하는 능력과 기본 표현을 중국어로 쓰는 능력 필요.',
 '1105-3025-00':'중어중문학과 교직과정 학생 대상. 중국어 교육에 관심 있고 중문과 2학년 과정 이수 또는 동등 실력이면 수강 가능.',
 '1105-4001-00':'중어중문학과 교직과정 학생 대상. 중국어 교육에 관심 있고 중문과 2학년 과정 이수 또는 동등 실력이면 수강 가능.',
 '1106-1008-00':'히라가나·가타카나·기초 한자 숙지 및 기초일본어·일본어 문장표현연습 1 이수 또는 동등 일본어 능력 필요.',
 '1106-2005-00':'기초일본어, 일본어문장표현연습 1·2, 일본어연습, 일본어강독 1, 현대일본어문법 선수 수강이 도움이 됨.',
 '1106-2011-00':'선수학습 안내: 일본어 초급회화 1.',
 '1106-3011-00':'기초 일본어 읽기·쓰기(한자 포함)와 중급 문법, 일본어중급회화 1 이수 또는 동등 회화 능력 필요.',
 '1106-3014-00':'별도 수강 제한 선수학습 조건 없음. 중급 이상 일본어와 높은 국어 능력이 도움이 됨.',
 '1106-4009-00':'일본어로 진행. 중급일본어회화 1·2 이수 또는 동등 중급 회화 능력 필요.',
 '1106-4005-00':'중간고사는 보고서로 대체하며 별도 실제 시험 시각을 생성하지 않음.',
}
name='cnu-unknown-2026-2.whole-checkpoint-next280-preserved-education-v4.json'
base=json.loads((R/name).read_text());out=copy.deepcopy(base)
for c in out['courses']:
 cid=c['sourceEducation']['courseId']
 if cid not in facts:continue
 src=json.loads((R/'cnu-proposed28-eastasian-angle-recovered-education-20261008'/f'{cid}.json').read_text())
 assert c['scheduleStatus']=='scheduled'
 c['sourceEducation']['publicPlanEnrollmentFacts']={'sourceResponseSHA256':src['sourceResponseSHA256'],'shortEducationNote':facts[cid],'originalCatalogRestrictionsAlsoPreserved':True,'eligibilityNotSilentlyInferred':True}
 for dep,text in c['departmentRemarks'].items():c['departmentRemarks'][dep]=text+'\n수강 대상 안내: '+facts[cid]
for old,new in zip(base['courses'],out['courses']):
 assert old['schedules']==new['schedules']
 assert old['sourceEducation'].get('originalEducationFields')==new['sourceEducation'].get('originalEducationFields')
 if old['sourceEducation']['courseId'] not in facts:assert old==new
out['verificationScope']='Current28 East Asian publicplans with all15weeklyrows and literal angles reviewed;19short preparation/target/assessment notes preserved. Existing252/5405 and actual12/172 unchanged, whole3888/280/6174; no full-school completion or actual attendance claim.'
f=R/'cnu-unknown-2026-2.whole-checkpoint-next280-preserved-education-v5.json';f.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
a=json.loads((R/'cnu-next280-preserved-education-v4-candidate-audit.json').read_text());a.update(candidate=f.name,candidateSHA256=hashlib.sha256(f.read_bytes()).hexdigest(),prior252CandidateSHA256=hashlib.sha256((R/name).read_bytes()).hexdigest(),newPlanEnrollmentFacts={**json.loads((R/'cnu-next252-preserved-education-v3-candidate-audit.json').read_text())['newPlanEnrollmentFacts'],**facts},newBatchEnrollmentFacts=facts,enrollmentNotesChangedCourses=19,allMeetingsAndOriginalMetadataUnchangedFromPrior252=True,wholePublicPlanNotBundled=True,current28RecoveredEducationProof='cnu-proposed28-eastasian-angle-preserved-context-recovery-audit.json')
(R/'cnu-next280-preserved-education-v5-candidate-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n')
print(f.name,a['candidateSHA256'],'280courses6174meetings19educationnotes')
