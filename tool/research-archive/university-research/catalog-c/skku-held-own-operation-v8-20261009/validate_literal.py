import json,pathlib,datetime
p=pathlib.Path(__file__).parent;read=lambda n:json.loads((p/n).read_text());courses=read('skku-humanities-2026-2.own-operation-v8.json')['courses']
mon=['08-31','09-07','09-14','09-21','10-12','10-19','10-26','11-02','11-09','11-16','11-23','11-30','12-07','12-14']
tue=['09-01','09-08','09-15','09-22','09-29','10-06','10-13','10-20','10-27','11-03','11-10','11-17','11-24','12-01','12-08','12-15']
wed=['09-02','09-09','09-16','09-23','09-30','10-07','10-14','10-21','10-28','11-04','11-11','11-18','11-25','12-02','12-09','12-16']
thu=['09-03','09-10','09-17','10-01','10-08','10-15','10-22','10-29','11-05','11-12','11-19','11-26','12-03','12-10','12-17']
rows={
'GEDG002-04':[(2,990,1065,'33406',tue,['10-20','12-15']),(4,900,975,'33406',thu,['10-22','12-17'])],
'GEDG002-05':[(1,990,1065,'31511',mon,['10-19','11-30','12-14']),(3,900,975,'31511',wed,['09-02','09-23','10-21','12-02','12-16'])],
'GEDG002-10':[(1,900,975,'50412',mon,['10-19','11-30','12-14']),(3,990,1065,'50412',wed,['09-02','09-23','10-21','12-02','12-16'])],
'GEDG029-03':[(2,720,795,'31511',tue,['09-29','12-15']),(4,810,885,'31511',thu,['10-01','12-17'])],
'GEDW018-08':[(4,720,795,'32416',thu,['12-17']),(4,810,885,'32416',thu,['12-17'])],
'GEDW019-03':[(2,900,975,'50205',tue,['10-06','12-15']),(2,990,1065,'50205',tue,['10-06','12-15'])],
'GEDW008-04':[(4,900,975,'61802',thu,['10-22','12-10','12-17']),(4,990,1065,'61802',thu,['10-22','12-10','12-17'])],
'GEDW014-06':[(4,720,795,'61802',thu,['10-22','12-10','12-17']),(4,810,885,'61802',thu,['10-22','12-10','12-17'])],
'GEDW014-08':[(3,720,795,'50401',wed,['10-21','12-09','12-16']),(3,810,885,'50401',wed,['10-21','12-09','12-16'])],
'GEDN017-01':[(4,630,705,'61605',thu,['10-22','12-10'])]}
receipt=[]
for key,frames in rows.items():
 c=next(x for x in courses if x['courseCode']+'-'+x['section']==key);expected=[]
 for weekday,a,b,room,dates,excluded in frames:
  for short in dates:
   if short in excluded:continue
   date='2026-'+short;assert datetime.date.fromisoformat(date).isoweekday()==weekday;expected.append({'weekday':weekday,'startMinute':a,'endMinute':b,'classroom':room,'date':date,'deliveryMode':'inPerson'})
 expected.sort(key=lambda x:(x['date'],x['startMinute']));assert expected==c['schedules'];receipt.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':expected})
assert sum(len(x['expectedSchedulesLiteral']) for x in receipt)==241
bases=[read(f'baseline-skku-{campus}-2026-2.json') for campus in ['humanities','naturalScience','icampus']];new={c['sourceId']:c for c in courses};unchanged=0;oldplans=0;oldscheduled=0
for d in bases:
 for b in d['courses']:
  if b['courseCode']+'-'+b['section'] in rows:continue
  if b['campus']=='humanities':assert new[b['sourceId']]==b
  unchanged+=1;oldplans+=len(b['schedules']);oldscheduled+=bool(b['schedules'])
assert (unchanged,oldscheduled,oldplans)==(2772,1695,47227)
(p/'independent-literal-date-validation.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'result':'PASS','newCourses':10,'newMeetings':241,'priorWholeCourses':2772,'priorScheduledCourses':1695,'priorMeetings':47227,'totalScheduledCourses':1705,'totalMeetings':47468,'ordinalExclusionsNotActualExamDates':True,'byCourse':receipt},ensure_ascii=False,indent=2)+'\n');print('PASS 10/241, prior1695/47227 retained, total1705/47468')
