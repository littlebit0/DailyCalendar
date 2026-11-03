"""Separate exact reviewed155 additions, leaving frozen615 candidate untouched."""
from pathlib import Path
import json,copy,datetime,hashlib
P=Path(__file__).parent
def prepare(kind='semantic'):
 semantics=json.loads((P/('mokpo-additional-semantic-dispositions-20261008.json' if kind=='semantic' else 'mokpo-eligibility-semantic-dispositions-20261008.json')).read_text())
 expected=155 if kind=='semantic' else 19
 accepted={(r['courseCode'],r['section']) for r in semantics['courses'] if r['state']=='supplementaryOrdinaryCandidate'}
 clock={(r['courseCode'],r['section']):r for r in json.loads((P/'mokpo-current-whole-time-review-unregistered.json').read_text())['courses']}
 holiday=set(json.loads((P/'mokpo-registration-candidate-audit-20261008.json').read_text())['excludedRegularClosureDates'])
 counts={};hashes={};ids=[];meetings=0
 for campus in ['dorim','damyang','unknown']:
  base=json.loads((P/f'mokpo-{campus}-2026-2.registration-candidate.json').read_text());additions=[]
  for original in base['courses']:
   key=(original['courseCode'],original['section'])
   if key not in accepted:continue
   c=copy.deepcopy(original);c['scheduleStatus']='scheduled';c['period']={'startDate':'2026-09-01','endDate':'2026-12-07'};c['schedules']=[]
   c['departmentRemarks']={d:v.split('\n운영 검토:')[0] for d,v in c['departmentRemarks'].items()}
   day=datetime.date(2026,9,1)
   while day<=datetime.date(2026,12,7):
    if day.isoformat() not in holiday:
     for m in clock[key]['clockReview']:
      if m['weekday']==day.isoweekday():c['schedules'].append({k:m[k] for k in ['weekday','startMinute','endMinute']}|{'date':day.isoformat(),'classroom':c['sourceClassroom']})
    day+=datetime.timedelta(days=1)
   meetings+=len(c['schedules']);ids.append(c['sourceId']);additions.append(c)
  base['courses']=additions;f=P/f'mokpo-{campus}-2026-2.{kind}-additions.json';f.write_text(json.dumps(base,ensure_ascii=False,indent=2)+'\n');hashes[f.name]=hashlib.sha256(f.read_bytes()).hexdigest();counts[campus]=len(additions)
 assert len(ids)==len(accepted)==expected
 result={'checkedAt':'2026-10-08','productionReady':False,'reviewedAdditions':expected,'datedMeetings':meetings,'candidateSha256':hashes,'campusCounts':counts,'sourceIds':ids,'ordinaryRulesOnly':True,'fixed615FilesChanged':False,'reviewContext':kind,'otherPendingCasesRemainSeparate':True,'sourceDispositions':'mokpo-additional-semantic-dispositions-20261008.json' if kind=='semantic' else 'mokpo-eligibility-semantic-dispositions-20261008.json'}
 (P/f'mokpo-{kind}-additions-audit-20261008.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');return result
if __name__=='__main__':
 import sys
 a=prepare(sys.argv[1] if len(sys.argv)>1 else 'semantic');print(a['reviewedAdditions'],a['datedMeetings'],a['campusCounts'])
