"""Keep short actual public enrollment restrictions from current educational plans."""
import copy, hashlib, json
from pathlib import Path
R=Path(__file__).resolve().parent
facts={
 '1004-7005-02':'2022년 동일 교과목 B학점 이상 취득자는 재수강 불가. 기존 파이썬 관련 교과목 수강자는 수강 불가이며 수강해도 A학점 미부여.',
 '1101-7014-00':'외국인 유학생 대상 한국어 수업.',
 '1101-7014-01':'외국인 유학생 대상이며 한국어로만 진행.',
 '1101-7015-00':'외국인 유학생 대상 한국어 수업.',
 '1102-7021-00':'영문과·영교과 학생 수강 금지.',
 '1155-7017-00':'신소재공학과 대상 분반으로 다른 학과 수강 제한.',
 '1155-7017-01':'신소재공학과 대상 분반으로 다른 학과 수강 제한.',
 '1155-7017-02':'에너지공학과 대상 분반으로 다른 학과 수강 제한.',
 '1155-7017-03':'반도체융합학과 외 학생 수강 제한.',
 '1155-7017-04':'반도체융합학과 대상 분반으로 다른 학과 수강 제한.',
 '1155-7017-05':'창의융합대학 전용 분반으로 다른 소속 수강 제한. 시간표가 맞지 않는 4학년 학생은 예외.',
 '1155-7017-06':'지질환경과학과 외 학생 수강 불가.',
 '1155-7017-07':'계획서: 농업생명과학대학 전용으로 다른 학과 수강 제한. 수강편람의 농생명융합학부 전용 표기도 유지하며 대상 범위는 학교에 확인.',
 '1155-7017-08':'계획서: 농업생명과학대학 외 학생 수강 불가. 수강편람의 농생명융합학부 전용 표기도 유지하며 대상 범위는 학교에 확인.',
}
name='cnu-unknown-2026-2.whole-checkpoint-next225-planned-regular213.json'
base=json.loads((R/name).read_text());out=copy.deepcopy(base)
for c in out['courses']:
 cid=c['sourceEducation']['courseId']
 if cid not in facts:continue
 src=json.loads((R/'cnu-proposed33-recovered-education-20261008'/f'{cid}.json').read_text())
 assert c['scheduleStatus']=='scheduled'
 c['sourceEducation']['publicPlanEnrollmentFacts']={'sourceResponseSHA256':src['sourceResponseSHA256'],'shortEducationNote':facts[cid],'originalCatalogRestrictionsAlsoPreserved':True,'eligibilityNotSilentlyInferred':True}
 for dep,text in c['departmentRemarks'].items():c['departmentRemarks'][dep]=text+'\n수강 대상 안내: '+facts[cid]
for old,new in zip(base['courses'],out['courses']):
 assert old['schedules']==new['schedules']
 assert old['sourceEducation'].get('originalEducationFields')==new['sourceEducation'].get('originalEducationFields')
 if old['sourceEducation']['courseId'] not in facts:assert old==new
out['verificationScope']='Current public33 plans add798 meetings, old192/3904 unchanged; short published plan enrollment notes preserved for14new courses; whole3888 and225/4702, actual12/172 unchanged.'
f=R/'cnu-unknown-2026-2.whole-checkpoint-next225-planned-regular213-eligibility-v2.json';f.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
a=json.loads((R/'cnu-next225-planned-regular213-candidate-audit.json').read_text());a.update(candidate=f.name,candidateSHA256=hashlib.sha256(f.read_bytes()).hexdigest(),prior225CandidateSHA256=hashlib.sha256((R/name).read_bytes()).hexdigest(),newPlanEnrollmentFacts=facts,enrollmentNotesChangedCourses=14,allMeetingsAndOriginalMetadataUnchangedFromPrior225=True,wholePublicPlanNotBundled=True,current33TokenPreservedEducationProof='cnu-proposed33-preserved-context-recovery-audit.json')
(R/'cnu-next225-planned-regular213-eligibility-v2-candidate-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n')
print(f.name,a['candidateSHA256'],'225courses4702meetings14educationnotes')
