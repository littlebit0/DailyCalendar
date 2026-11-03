import json,pathlib,datetime
p=pathlib.Path(__file__).parent;read=lambda n:json.loads((p/n).read_text());courses=read('skku-humanities-2026-2.own-operation-v11.json')['courses']+read('skku-naturalScience-2026-2.own-operation-v11.json')['courses']+read('baseline-skku-icampus-2026-2.json')['courses']
mon=['08-31','09-07','09-14','09-21','10-12','10-19','10-26','11-02','11-09','11-16','11-23','11-30','12-07','12-14']
tue=['09-01','09-08','09-15','09-22','09-29','10-06','10-13','10-20','10-27','11-03','11-10','11-17','11-24','12-01','12-08','12-15']
wed=['09-02','09-09','09-16','09-23','09-30','10-07','10-14','10-21','10-28','11-04','11-11','11-18','11-25','12-02','12-09','12-16']
thu=['09-03','09-10','09-17','10-01','10-08','10-15','10-22','10-29','11-05','11-12','11-19','11-26','12-03','12-10','12-17']
fri=['09-04','09-11','09-18','10-02','10-16','10-23','10-30','11-06','11-13','11-20','11-27','12-04','12-11','12-18']
rows={
'FRE2023-01':[(2,720,795,'31608',tue,['10-13','10-20','12-08','12-15']),(4,810,885,'31608',thu,['10-15','10-22','12-10','12-17'])],
'FRE2025-01':[(5,720,795,'31605',fri,['10-16','10-23','12-11','12-18']),(5,810,885,'31605',fri,['10-16','10-23','12-11','12-18'])],
'SOC3012-01':[(2,900,975,'61607',tue,['12-15']),(4,990,1065,'61607',thu,['12-17'])],
'PSY4012-01':[(3,720,795,'61603',wed,['11-04','12-09','12-16']),(3,810,885,'61603',wed,['11-04','12-09','12-16'])],
'KID2005-01':[(2,900,975,'50423',tue,['10-20','11-03','12-01','12-08','12-15'])],
'DES2008-01':[(2,720,795,'61202',tue,['12-15']),(2,810,885,'61202',tue,['12-15'])],
'DES2008-02':[(2,900,975,'61202',tue,['12-15']),(2,990,1065,'61202',tue,['12-15'])],
'DAT3066-01':[(5,900,975,'62401',fri,['10-23','12-18']),(5,990,1065,'62401',fri,['10-23','12-18'])],
'GEDC010-01':[(4,540,590,'50411',thu,['10-08','10-22','11-05','12-17']),(4,600,650,'50411',thu,['10-08','10-22','11-05','12-17'])],
'CFTD003-01':[(5,780,830,'50304',fri,['10-23','12-18']),(5,840,890,'50304',fri,['10-23','12-18'])],
'CFTD122-01':[(2,1080,1130,'50105',tue,['12-08','12-15'])],
'CFTD042-01':[(2,1080,1155,'50306',tue,[]),(2,1170,1245,'50306',tue,[])],
'EME2018-41':[(1,630,705,'22306',mon,['08-31','09-28','10-05','10-19','12-14'])],
'SWE3025-41':[(1,810,885,'26312',mon,['10-19','12-07','12-14']),(3,720,795,'26312',wed,['10-21','12-09','12-16'])],
'ICE2016-42':[(1,900,975,'61304A',mon,['09-28','12-07','12-14']),(3,990,1065,'61304A',wed,['09-30','12-09','12-16'])]}
receipt=[]
for key,frames in rows.items():
 c=next(x for x in courses if x['courseCode']+'-'+x['section']==key);expected=[]
 for weekday,a,b,room,dates,excluded in frames:
  for short in dates:
   if short in excluded:continue
   date='2026-'+short;assert datetime.date.fromisoformat(date).isoweekday()==weekday;expected.append({'weekday':weekday,'startMinute':a,'endMinute':b,'classroom':room,'date':date,'deliveryMode':'inPerson'})
 expected.sort(key=lambda x:(x['date'],x['startMinute']));assert expected==c['schedules'];receipt.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':expected})
assert sum(len(x['expectedSchedulesLiteral']) for x in receipt)==345
bases=[read(f'baseline-skku-{campus}-2026-2.json') for campus in ['humanities','naturalScience','icampus']];new={c['sourceId']:c for c in courses};unchanged=0;oldplans=0;oldscheduled=0
for d in bases:
 for b in d['courses']:
  if b['courseCode']+'-'+b['section'] in rows:continue
  assert new[b['sourceId']]==b
  unchanged+=1;oldplans+=len(b['schedules']);oldscheduled+=bool(b['schedules'])
assert (unchanged,oldscheduled,oldplans)==(2767,1737,48129)
(p/'independent-literal-date-validation.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'result':'PASS','newCourses':15,'newMeetings':345,'priorWholeCourses':2767,'priorScheduledCourses':1737,'priorMeetings':48129,'totalScheduledCourses':1752,'totalMeetings':48474,'ordinalExclusionsNotActualExamDates':True,'byCourse':receipt},ensure_ascii=False,indent=2)+'\n');print('PASS 15/345, prior1737/48129 retained, total1752/48474')
