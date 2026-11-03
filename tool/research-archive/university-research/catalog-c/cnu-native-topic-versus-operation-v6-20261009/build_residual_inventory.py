# -*- coding: utf-8 -*-
from pathlib import Path
import json,hashlib,collections
O=Path(__file__).resolve().parent;R=O.parents[3];read=lambda p:json.loads(p.read_text())
a=read(O/'candidate-audit.json');tri=read(R/'work/university-research/catalog-c/cnu-ordinary-reservation-v3-20261009/existing-source-semantic-triage.json');oldproof=read(R/'work/university-research/catalog-c/cnu-ordinary-reservation-v3-20261009/candidate-audit.json');done={p['courseId'] for p in oldproof['proofs']}
for v in (4,5):done.update(p['courseId'] for p in read(R/f'work/university-research/catalog-c/cnu-native-topic-versus-operation-v{v}-20261009/independent-native-topic-clock-proof.json')['proofs'])
approved={p['courseId'] for p in a['proofs']};held={'1282-1017-00':'Fullalternativebodyexplicit 화상수업 예정임; native24slots/week have no individualcourseblockdate proof. No generalsemester appointments invented.','1361-2010-00':'WholeheaderREF_CTNTexplicit -팀티칭/-비대면강의; earliertriage only flagged clinicaltopic. Actualremote allocation remainsunknown, cannot approveordinaryphysical source despite topic falsepositive.','1361-4034-00':'Familyassessment is academic topic, but source2/2/0 versus8nativehourblocks/week requires currentindividualsemester operatingblock corroboration. Hold pending precise block applicability, not title/credits alone.'};overlap={p['courseId'] for p in oldproof['heldAfterJoin']};rows=[]
for d in tri['decisions']:
 if d['courseId'] in done:continue
 path=Path(d['sourcePlanFile']);content=read(path);assert hashlib.sha256(path.read_bytes()).hexdigest()==d['sourcePlanSHA256']
 decision='approvedIndividualFullPlan' if d['courseId'] in approved else 'heldIndividualFullPlan' if d['courseId'] in held else 'previousKnownNativeClockOverlapHeld' if d['courseId'] in overlap else 'notYetIndividuallyAdjudicated'
 rows.append({'courseId':d['courseId'],'sourceId':d['sourceId'],'sourcePlanFile':str(path.relative_to(R)),'sourcePlanSHA256':d['sourcePlanSHA256'],'wholeEducationalHeader':content['header'],'wholeEducationalWeeks':content['weeks'],'allContentLoadedAndSHAValidated':True,'semanticDecision':decision,'heldReason':held.get(d['courseId']),'originalTriage':d})
assert len(rows)==554
out={'scope':554,'sourceFilesLoadedAndSHAValidated':554,'fullContextManuallyAdjudicated':20,'approved':17,'reviewedHeld':3,'priorKnownClockOverlapHeld':2,'notYetIndividuallyAdjudicated':532,'notBlanketApproval':True,'rows':rows};(O/'all554-source-content-inventory-and-review-progress.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in out.items() if k!='rows'})
