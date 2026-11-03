import json,pathlib,datetime
p=pathlib.Path(__file__).parent;read=lambda n:json.loads((p/n).read_text());courses=read('skku-humanities-2026-2.own-operation-v15.json')['courses']+read('baseline-skku-naturalScience-2026-2.json')['courses']+read('baseline-skku-icampus-2026-2.json')['courses']
mon=['08-31','09-07','09-14','09-21','10-12','10-19','10-26','11-02','11-09','11-16','11-23','11-30','12-07','12-14']
tue=['09-01','09-08','09-15','09-22','09-29','10-06','10-13','10-20','10-27','11-03','11-10','11-17','11-24','12-01','12-08','12-15']
wed=['09-02','09-09','09-16','09-23','09-30','10-07','10-14','10-21','10-28','11-04','11-11','11-18','11-25','12-02','12-09','12-16']
thu=['09-03','09-10','09-17','10-01','10-08','10-15','10-22','10-29','11-05','11-12','11-19','11-26','12-03','12-10','12-17']
fri=['09-04','09-11','09-18','10-02','10-16','10-23','10-30','11-06','11-13','11-20','11-27','12-04','12-11','12-18']
rows={'KLC2016-01':[(1,1080,1155,'31301',['08-31','09-07'],[]),(3,1080,1155,'31301',['09-02','09-09'],[])],'PHL3042-01':[(2,1080,1155,'31702',tue,['10-20','12-08','12-15']),(2,1170,1245,'31702',tue,['10-20','12-08','12-15'])]}
receipt=[]
for key,frames in rows.items():
 c=next(x for x in courses if x['courseCode']+'-'+x['section']==key);expected=[]
 for weekday,a,b,room,dates,excluded in frames:
  for short in dates:
   if short in excluded:continue
   date='2026-'+short;assert datetime.date.fromisoformat(date).isoweekday()==weekday;expected.append({'weekday':weekday,'startMinute':a,'endMinute':b,'classroom':room,'date':date,'deliveryMode':'inPerson'})
 expected.sort(key=lambda x:(x['date'],x['startMinute']));assert expected==c['schedules'];receipt.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':expected})
assert sum(len(x['expectedSchedulesLiteral']) for x in receipt)==30
bases=[read(f'baseline-skku-{campus}-2026-2.json') for campus in ['humanities','naturalScience','icampus']];new={c['sourceId']:c for c in courses};unchanged=0;oldplans=0;oldscheduled=0
for d in bases:
 for b in d['courses']:
  if b['courseCode']+'-'+b['section'] in rows:continue
  assert new[b['sourceId']]==b
  unchanged+=1;oldplans+=len(b['schedules']);oldscheduled+=bool(b['schedules'])
assert (unchanged,oldscheduled,oldplans)==(2780,1757,48582)
(p/'independent-literal-date-validation.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'result':'PASS','newCourses':2,'newMeetings':30,'priorWholeCourses':2780,'priorScheduledCourses':1757,'priorMeetings':48582,'totalScheduledCourses':1759,'totalMeetings':48612,'ordinalExclusionsNotActualExamDates':True,'byCourse':receipt},ensure_ascii=False,indent=2)+'\n');print('PASS 2/30, prior1757/48582 retained, total1759/48612')
