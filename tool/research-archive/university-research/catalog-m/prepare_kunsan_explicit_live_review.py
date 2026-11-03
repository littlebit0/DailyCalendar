"""Resolve only literal real-time room markers; generic remote remains pending."""
from pathlib import Path
import json,copy,hashlib
from prepare_kunsan_review import parse_numeric_clock,ordinary_dates
P=Path(__file__).parent
IDS={('107053','01'),('114591','01'),('114281','01')}
def prepare():
 whole=json.loads((P/'kunsan-current-whole-normalized-review-unregistered.json').read_text());courses=[];proofs=[]
 for original in whole['courses']:
  if (original['courseCode'],original['section']) not in IDS:continue
  c=copy.deepcopy(original);clocks=parse_numeric_clock(c['sourceSchedule']);assert any(m['classroom']=='실시간강의' for m in clocks)
  c['schedules']=ordinary_dates(clocks)
  for m in c['schedules']:
   m['startMinute']=m.pop('originalStartMinute')
   m['deliveryMode']='liveOnline' if m['classroom']=='실시간강의' else 'inPerson'
  c['scheduleStatus']='scheduled';c['period']={'startDate':'2026-08-31','endDate':'2026-12-17'}
  c['remarks']=c['remarks'].replace(' / 원격·혼합 운영의 실제 동시 출석 방식 미확인','').replace('원격·혼합 운영의 실제 동시 출석 방식 미확인','')
  courses.append(c);proofs.append({'sourceId':c['sourceId'],'actualSourceSchedule':c['sourceSchedule'],'sourceMethods':c['sourceTeachingMethods'],'sourceOccurrences':c['sourceOccurrences'],'literalModeProof':'Exact 실시간강의 block means live online; each remaining explicitly printed physical room block is in person. Generic 원격강의 is not converted.','clockBlocks':clocks})
 assert len(courses)==3
 d={'schemaVersion':2,'universityId':'kunsan','campus':'unknown','campusName':'위치 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-10-08','sourceUrl':'https://www.kunsan.ac.kr/board/view.kunsan?boardId=BBS_0000009&dataSid=1384672','courses':courses}
 f=P/'kunsan-unknown-2026-2.explicit-live-mode-candidate.json';f.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
 audit={'checkedAt':'2026-10-08','productionReady':False,'completionClaim':False,'modeResolved':3,'all43GenericRemoteMixedUnresolved':True,'finalClosureScopeStillUnverified':True,'baseline797Changed':False,'candidateSha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest()},'proofs':proofs}
 (P/'kunsan-explicit-live-mode-audit-20261008.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':prepare()
