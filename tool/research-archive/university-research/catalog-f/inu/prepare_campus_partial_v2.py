from pathlib import Path
import json,re,hashlib,urllib.request,io
from collections import Counter
from pypdf import PdfReader
ROOT=Path(__file__).resolve().parent
handbook='https://www.inu.ac.kr/bbs/ite/373/391037/download'
b=urllib.request.urlopen(handbook).read();t=PdfReader(io.BytesIO(b)).pages[20].extract_text();t=t[t.index('강의실 및 건물코드'):]
assert 'NA미래관' in t and 'NC미추홀타워 별관 A동' in t
numbers=['04','05','07','08','09','11','12','13','14','15','16','19','20','21','22','23','27','28','29','41']
mapping={n:'송도캠퍼스' for n in numbers};mapping.update({n:'미추홀캠퍼스' for n in ['NA','NB','NC','ND']})
receipt={'sourceUrl':handbook,'sourceSHA256':hashlib.sha256(b).hexdigest(),'pdfPage':21,'printedPage':42,'nativeTableHeading':'강의실 및 건물코드','nativeTableText':t,'campusMapReceipt':'inu-current-public-campus-buildings-20261008.json','joinBasis':'Current handbook room-prefix→building and current official campus map tab→same building; no department-footer inference','roomBuildingCampusMap':mapping,'rawBodySaved':False}
p=ROOT/'inu-current-room-campus-join-20261008.json';p.write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
prior=ROOT/'inu-main-2026-2.whole2437-partial-dated-v1.json';out=json.loads(prior.read_text());count=Counter()
for c in out['courses']:
 groups=re.findall(r'\[([^\[\]]+)\]',c['sourceSchedule']);rooms=[g.split(':',1)[0] for g in groups]
 prefixes=[room.split('-',1)[0] for room in rooms]
 names=sorted({mapping[p] for p in prefixes if p in mapping})
 complete=bool(prefixes) and all(p in mapping for p in prefixes)
 c['sourceEducation']['publicRoomCampusNames']=names
 c['sourceEducation']['publicRoomCampusMappingComplete']=complete
 c['sourceEducation']['publicRoomCampusEvidence']='inu-current-room-campus-join-20261008.json'
 c['sourceEducation']['physicalCampusIndividuallyPrinted']=False
 c['sourceEducation']['physicalCampusJoinedFromOfficialRoomCode']=complete
 if complete:
  count['mappedCourses']+=1;count['multipleCampuses' if len(names)>1 else names[0]]+=1
  for department,note in c['departmentRemarks'].items():c['departmentRemarks'][department]=note+' 강의실 코드와 공식 건물·캠퍼스 지도 대조: '+', '.join(names)+'.'
 else:count['unresolvedCourses']+=1
out['candidateRevision']='whole2437-partial-dated-v2'
p=ROOT/'inu-main-2026-2.whole2437-partial-dated-v2.json';p.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
audit={'candidateSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'priorV1SHA256':hashlib.sha256(prior.read_bytes()).hexdigest(),'roomCampusMappingCounts':dict(count),'nativeRows':2437,'scheduledCourses':1663,'datedSlots':51330,'allSchedulesExactlyPreserved':True,'numericSectionDefinitionConfirmed':False,'firstClosureCumulativeConfirmed':False,'completionClaim':False}
assert all(a['schedules']==b['schedules'] for a,b in zip(json.loads(prior.read_text())['courses'],out['courses']))
(ROOT/'inu-current-partial-v2-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print(audit)
