# -*- coding: utf-8 -*-
from pathlib import Path
import json,hashlib,re,datetime as dt,collections
O=Path(__file__).resolve().parent;R=O.parents[3]
read=lambda p:json.loads(p.read_text())
a=read(O/'independent-native-topic-clock-proof.json');n=read(O/'cnu-unknown-2026-2.native-topic-research-v11-20261009.json');b=read(R/'work/university-research/catalog-c/cnu-native-topic-versus-operation-v10-20261009/cnu-unknown-2026-2.native-topic-research-v10-20261009.json');d=read(O/'cnu-daedeok-2026-2.existing-unchanged-v11.json')
old={c['sourceId']:c for c in b['courses']};proof={p['sourceId']:p for p in a['proofs']};assert len(proof)==8
for p,h in a['sourceInputsSHA256'].items():assert hashlib.sha256((R/p).read_bytes()).hexdigest()==h,p
native=read(R/'work/university-research/catalog-c/cnu-ordinary-reservation-v2-20261008/current-public-native-educational-catalog.json');nt={c['COURSE_NO']:c for c in native}
assert len(nt)==3888
pattern=re.compile(r'([월화수목금토일])(\d{2}):(\d{2})~(\d{2}):(\d{2})\(((?:[^()]|\([^()]*\))*)\)')
for c in n['courses']:
 before=old[c['sourceId']]
 if c['sourceId'] not in proof:assert c==before;continue
 p=proof[c['sourceId']];assert p['originalCourse']==before
 restored=dict(c)
 for k in ['previousResearchDepartmentRemarks','currentPublicPlanEducation','reservationEvidence']:restored.pop(k)
 for k in ['schedules','scheduleStatus','period','departmentRemarks']:
  if k in before:restored[k]=before[k]
  else:restored.pop(k,None)
 assert restored==before
 row=nt[p['courseId']];assert row['OPEN_SBJT_NO']==c['courseCode'] and row['OPEN_DCLSS']==c['section'];assert row['OPEN_YR']=='2026' and row['OPEN_SHTM_CD']=='USR01.20' and row['OBJ_CORS_CD_NM']=='학사과정' and row['CLOSE_YN']=='0'
 slots=list(pattern.finditer(row['TMTBL_INFO']));assert slots
 expected=[]
 for s in slots:
  day=dt.date(2026,9,1)
  while day<=dt.date(2026,12,18):
   weekday='월화수목금토일'.index(s[1])+1
   if day.isoweekday()==weekday and day.isoformat() not in a['reservationExclusions']:expected.append({'date':day.isoformat(),'weekday':weekday,'startMinute':int(s[2])*60+int(s[3]),'endMinute':int(s[4])*60+int(s[5]),'classroom':s[6]})
   day+=dt.timedelta(days=1)
 assert c['schedules']==expected==p['literalDatedMeetings']
 assert c['previousResearchDepartmentRemarks']==before['departmentRemarks']
 assert all('수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.' not in s for s in c['departmentRemarks'].values())
 assert c['currentPublicPlanEducation']['header']==p['wholeCurrentOriginalEducationalPlan']['header'] and c['currentPublicPlanEducation']['weeks']==p['wholeCurrentOriginalEducationalPlan']['weeks']
allrows=n['courses']+d['courses'];assert len(allrows)==3888 and len({c['sourceId'] for c in allrows})==3888
assert {c['sourceEducation']['courseId'] for c in allrows}==set(nt)
assert sum(bool(c['schedules']) for c in allrows)==1754 and sum(len(c['schedules']) for c in allrows)==43439
assert d==read(R/'work/university-research/catalog-c/cnu-ordinary-reservation-v2-20261008/baseline-cnu-daedeok-v1.json')
assert sum(bool(c['schedules']) for c in b['courses'])+1==1746 and sum(len(c['schedules']) for c in b['courses'])+15==43281
result={'pythonExit':0,'wholeNativeUnion':3888,'priorWholeCourseObjectsPreserved':3880,'priorScheduled':1746,'priorDates':43281,'newScheduled':8,'newLiteralDates':158,'candidateScheduled':1754,'candidateDates':43439,'independentOriginalNativeTMTBLParse':True,'allSourceInputsSHA256Unchanged':True,'actualModelDriveValidation':'NOT RUN; SDK prohibited pending root grant','SDKUsed':False,'productChanged':False}
(O/'source-only-independent-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(result)
