"""Two exact current-plan dated exceptions; no ordinary checkpoint mutation."""
from pathlib import Path
import json,copy,hashlib,datetime
P=Path(__file__).parent
ABC=[(10,7),(10,8),(10,12),(10,14),(10,15),(11,2),(11,9),(11,11),(11,12),(11,16),(11,18),(11,19),(11,23),(11,25),(11,26)]
# Exact printed Korean weekday sequence crosschecked against2026 actual calendar.
ABC_WEEKDAYS=[3,4,1,3,4,1,1,3,4,1,3,4,1,3,4]
def prepare():
 holiday=set(json.loads((P/'mokpo-registration-candidate-audit-20261008.json').read_text())['excludedRegularClosureDates'])
 clocks={(c['courseCode'],c['section']):c for c in json.loads((P/'mokpo-current-whole-time-review-unregistered.json').read_text())['courses']}
 proofs=[];hashes={};total=0
 for campus in ['dorim','damyang','unknown']:
  dataset=json.loads((P/f'mokpo-{campus}-2026-2.checkpoint-next.json').read_text());result=[]
  for original in dataset['courses']:
   key=(original['courseCode'],original['section'])
   if key not in {('HIS041','00'),('ABC003','04')}:continue
   c=copy.deepcopy(original);assert not c['schedules'];c['schedules']=[];c['scheduleStatus']='scheduled'
   c['departmentRemarks']={d:v.split('\n운영 검토:')[0] for d,v in c['departmentRemarks'].items()}
   plan=json.loads((P/'mokpo-current-plan-operating-20261008'/('-'.join(key)+'.json')).read_text())['educationalDatasets']
   if key[0]=='ABC003':
    lines=plan['ds_out'][0]['additionalOperatingExcerpts']['GYOGWAMOK_GAEYO'];assert '# 수업시간:' in lines
    for (month,day),weekday in zip(ABC,ABC_WEEKDAYS):
     date=datetime.date(2026,month,day);assert date.isoweekday()==weekday and date.isoformat() not in holiday
     c['schedules'].append(dict(date=date.isoformat(),weekday=weekday,startMinute=1080,endMinute=1260,classroom=c['sourceClassroom']))
    c['period']={'startDate':'2026-10-07','endDate':'2026-11-26'}
    proofs.append({'sourceId':c['sourceId'],'sourceFile':'mokpo-current-plan-operating-20261008/ABC003-04.json','exactEducationalTimeLines':lines[1:],'explicitDates':[m['date'] for m in c['schedules']],'clock':'저녁6시~9시','minutes':[1080,1260],'printedWeekdaysMatchActual':True,'currentMainIdentityMatches':True,'schedulesEntireClass':True,'sessions':15,'totalHours':45,'sourcePrintedClassroom':c['sourceClassroom']})
   else:
    line=next(w['BANGBEOP'] for w in plan['ds_out3'] if '9/7 휴강' in w.get('BANGBEOP',''))
    day=datetime.date(2026,9,1)
    while day<=datetime.date(2026,12,7):
     if day.isoformat() not in holiday|{'2026-09-07'}:
      for m in clocks[key]['clockReview']:
       if m['weekday']==day.isoweekday():c['schedules'].append({k:m[k] for k in ['weekday','startMinute','endMinute']}|{'date':day.isoformat(),'classroom':c['sourceClassroom']})
     day+=datetime.timedelta(days=1)
    c['period']={'startDate':'2026-09-01','endDate':'2026-12-07'}
    proofs.append({'sourceId':c['sourceId'],'sourceFile':'mokpo-current-plan-operating-20261008/HIS041-00.json','exactEducationalNoClassLine':line,'removedActualDates':['2026-09-07'],'normalRuleOnly':True,'separateFinalExamNotCreated':True})
   result.append(c);total+=1
  dataset['courses']=result;path=P/f'mokpo-{campus}-2026-2.actual-date-additions.json';path.write_text(json.dumps(dataset,ensure_ascii=False,indent=2)+'\n');hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
 assert total==2
 audit={'checkedAt':'2026-10-08','productionReady':False,'checkpointNextChanged':False,'candidateSha256':hashes,'proofs':proofs,'additionalOrdinaryWithCanceledDate':1,'additionalEntireExplicitDates':1}
 (P/'mokpo-actual-date-additions-audit-20261008.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':prepare()
