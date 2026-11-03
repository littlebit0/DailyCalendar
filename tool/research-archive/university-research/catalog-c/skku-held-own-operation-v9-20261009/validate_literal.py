import json,pathlib,datetime
p=pathlib.Path(__file__).parent;read=lambda n:json.loads((p/n).read_text());courses=read('skku-humanities-2026-2.own-operation-v9.json')['courses']+read('skku-naturalScience-2026-2.own-operation-v9.json')['courses']+read('baseline-skku-icampus-2026-2.json')['courses']
mon=['08-31','09-07','09-14','09-21','10-12','10-19','10-26','11-02','11-09','11-16','11-23','11-30','12-07','12-14']
tue=['09-01','09-08','09-15','09-22','09-29','10-06','10-13','10-20','10-27','11-03','11-10','11-17','11-24','12-01','12-08','12-15']
wed=['09-02','09-09','09-16','09-23','09-30','10-07','10-14','10-21','10-28','11-04','11-11','11-18','11-25','12-02','12-09','12-16']
thu=['09-03','09-10','09-17','10-01','10-08','10-15','10-22','10-29','11-05','11-12','11-19','11-26','12-03','12-10','12-17']
rows={
'BUS2006-07':[(3,1080,1155,'33303',wed,['10-21','12-09','12-16']),(3,1170,1245,'33303',wed,['10-21','12-09','12-16'])],
'BUS2014-01':[(4,810,885,'33302',thu,['10-22','12-10','12-17'])],
'ECO3032-01':[(4,540,615,'31705',thu,['10-01','10-22','12-17']),(4,630,705,'31705',thu,['10-01','10-22','12-17'])],
'DKL2009-01':[(2,720,795,'31606',tue,['10-20','11-03','12-15']),(4,810,885,'31606',thu,['10-22','11-05','12-17'])],
'PSY3040-01':[(2,540,615,'61602',tue,['10-20','12-08','12-15']),(4,630,705,'61602',thu,['10-22','12-10','12-17'])],
'PHL2007-01':[(2,720,795,'31607',tue,['10-20','12-15']),(4,810,885,'31607',thu,['10-22','12-17'])],
'FRE2003-01':[(2,810,885,'31608',tue,['10-20','12-08','12-15']),(4,720,795,'31608',thu,['10-22','12-10','12-17'])],
'HAN2004-01':[(2,810,885,'50408',tue,['10-20','12-15']),(4,720,795,'50408',thu,['10-22','12-17'])],
'HAN2021-01':[(1,720,795,'50408',mon,['10-19','12-14']),(3,810,885,'50408',wed,['10-21','12-16'])],
'SWF3060-01':[(2,630,705,'61605',tue,['12-15'])],
'CON4016-01':[(2,900,975,'50318',['10-13','10-27'],[]),(2,990,1065,'50318',['10-13','10-27'],[])],
'CNT2003-01':[(1,810,885,'31709',mon,['09-21','12-14']),(3,720,795,'31709',wed,['09-23','12-16'])],
'COS3098-01':[(2,990,1065,'31506',tue,['10-06']),(4,900,975,'31506',thu,['10-08','12-03'])],
'DKL3054-01':[(1,630,705,'31706',['08-31','09-07','09-14','09-21','10-12','10-19','11-09','11-16','11-23','11-30','12-07'],[])],
'IAI3015-41':[(3,1140,1215,'48B114',['09-02'],[]),(3,1230,1305,'48B114',['09-02'],[])]}
receipt=[]
for key,frames in rows.items():
 c=next(x for x in courses if x['courseCode']+'-'+x['section']==key);expected=[]
 for weekday,a,b,room,dates,excluded in frames:
  for short in dates:
   if short in excluded:continue
   date='2026-'+short;assert datetime.date.fromisoformat(date).isoweekday()==weekday;expected.append({'weekday':weekday,'startMinute':a,'endMinute':b,'classroom':room,'date':date,'deliveryMode':'inPerson'})
 expected.sort(key=lambda x:(x['date'],x['startMinute']));assert expected==c['schedules'];receipt.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':expected})
assert sum(len(x['expectedSchedulesLiteral']) for x in receipt)==303
bases=[read(f'baseline-skku-{campus}-2026-2.json') for campus in ['humanities','naturalScience','icampus']];new={c['sourceId']:c for c in courses};unchanged=0;oldplans=0;oldscheduled=0
for d in bases:
 for b in d['courses']:
  if b['courseCode']+'-'+b['section'] in rows:continue
  assert new[b['sourceId']]==b
  unchanged+=1;oldplans+=len(b['schedules']);oldscheduled+=bool(b['schedules'])
assert (unchanged,oldscheduled,oldplans)==(2767,1705,47468)
(p/'independent-literal-date-validation.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'result':'PASS','newCourses':15,'newMeetings':303,'priorWholeCourses':2767,'priorScheduledCourses':1705,'priorMeetings':47468,'totalScheduledCourses':1720,'totalMeetings':47771,'ordinalExclusionsNotActualExamDates':True,'byCourse':receipt},ensure_ascii=False,indent=2)+'\n');print('PASS 15/303, prior1705/47468 retained, total1720/47771')
