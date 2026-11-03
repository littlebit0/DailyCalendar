# -*- coding: utf-8 -*-
from pathlib import Path
import copy,json,hashlib
OUT=Path(__file__).resolve().parent;PRIOR=OUT.parent/'khu-empty-room-ordinary-followup-v6-20261009'
WARNING='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
audit=json.loads((PRIOR/'independent-native-clock-date-proof.json').read_text());selected={p['sourceId'] for p in audit['proofs']};assert len(selected)==41
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
proofs=[];inputs={};counts=[]
for campus in ['seoul','global']:
 p=PRIOR/f'khu-{campus}-2026-2.empty-room-research-v6-20261009.json';inputs[str(p)]=sha(p);old=json.loads(p.read_text());new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  before=copy.deepcopy(c['departmentRemarks'])
  assert all(WARNING in text for text in before.values()),c['sourceId']
  c['previousResearchDepartmentRemarks']=before
  c['departmentRemarks']={k:text.replace(WARNING,'') for k,text in before.items()}
  assert all(WARNING not in text for text in c['departmentRemarks'].values())
  compare=copy.deepcopy(c);compare['departmentRemarks']=before;compare.pop('previousResearchDepartmentRemarks');original=next(r for r in old['courses'] if r['sourceId']==c['sourceId']);assert compare==original
  proofs.append({'sourceId':c['sourceId'],'removedExactNonSchoolResearchWarning':WARNING,'previousDepartmentRemarks':before,'correctedDepartmentRemarks':c['departmentRemarks'],'schedulesBeforeAfterEqual':True,'nativeSchoolFieldsBeforeAfterEqual':True})
 originals={c['sourceId']:c for c in old['courses']};assert all(c==originals[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (OUT/f'khu-{campus}-2026-2.research-note-corrected-v7-20261009.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
 counts.append({'campus':campus,'native':len(new['courses']),'scheduled':sum(bool(c['schedules']) for c in new['courses']),'dates':sum(len(c['schedules']) for c in new['courses'])})
assert len(proofs)==41 and sum(c['native'] for c in counts)==4666 and sum(c['scheduled'] for c in counts)==1947 and sum(c['dates'] for c in counts)==36548
receipt={'sourceOnly':True,'annotationCorrectionOnly':True,'currentSourceSnapshot':'2026-10-08','changedNotes':41,'otherFullObjectsUnchanged':4625,'native':4666,'scheduledUnchanged':1947,'datesUnchanged':36548,'datasets':counts,'sourceSHA256':inputs,'proofs':proofs,'originalPreviousResearchWarningPreserved':True,'schoolNativeRestrictionRemoved':False,'sdkUsed':False,'productEdited':False,'completionClaim':False,'impossibleClaim':False}
(OUT/'independent-note-preservation-receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print('PASS: exact research-only warning removed41; previous full remarks preserved; all4666 school fields/schedules1947/36548 unchanged')
