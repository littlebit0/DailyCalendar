import json,pathlib,datetime
p=pathlib.Path(__file__).parent;read=lambda n:json.loads((p/n).read_text());courses=read('skku-humanities-2026-2.own-operation-v10.json')['courses']+read('skku-naturalScience-2026-2.own-operation-v10.json')['courses']+read('baseline-skku-icampus-2026-2.json')['courses']
mon=['08-31','09-07','09-14','09-21','10-12','10-19','10-26','11-02','11-09','11-16','11-23','11-30','12-07','12-14']
tue=['09-01','09-08','09-15','09-22','09-29','10-06','10-13','10-20','10-27','11-03','11-10','11-17','11-24','12-01','12-08','12-15']
wed=['09-02','09-09','09-16','09-23','09-30','10-07','10-14','10-21','10-28','11-04','11-11','11-18','11-25','12-02','12-09','12-16']
thu=['09-03','09-10','09-17','10-01','10-08','10-15','10-22','10-29','11-05','11-12','11-19','11-26','12-03','12-10','12-17']
fri=['09-04','09-11','09-18','10-02','10-16','10-23','10-30','11-06','11-13','11-20','11-27','12-04','12-11','12-18']
rows={
'BUS2028-02':[(3,990,1065,'33527',wed,['10-21','12-02','12-16'])],
'BUS2028-03':[(3,900,975,'33527',wed,['10-21','12-02','12-16'])],
'GBA3008-01':[(2,900,975,'90110',tue,['10-20','12-08','12-15']),(4,990,1065,'90110',thu,['10-22','12-10','12-17'])],
'GEC3109-01':[(1,720,795,'9B208',mon,['10-19','12-07','12-14']),(3,810,885,'9B208',wed,['10-21','12-09','12-16'])],
'PHL3040-01':[(4,540,615,'31707',thu,['10-22','12-10']),(4,630,705,'31707',thu,['10-22','12-10'])],
'FRE2017-01':[(2,900,950,'31608',tue,['10-13','10-20','12-08','12-15']),(2,960,1010,'31608',tue,['10-13','10-20','12-08','12-15']),(4,900,950,'31608',thu,['10-15','10-22','12-10','12-17']),(4,960,1010,'31608',thu,['10-15','10-22','12-10','12-17'])],
'GELT075-05':[(2,960,1010,'31705',tue,['10-20','11-10','11-17','11-24','12-01','12-15'])],
'GELT075-06':[(2,780,830,'50307',tue,['10-20','11-10','11-17','11-24','12-01','12-15'])],
'GEDM001-07':[(5,600,650,'50407',fri,['12-11','12-18']),(5,660,710,'50407',fri,['12-11','12-18'])],
'GEDM001-E9':[(5,720,770,'50407',fri,['12-11','12-18']),(5,780,830,'50407',fri,['12-11','12-18'])],
'GEDG002-46':[(1,990,1065,'26506',mon,['12-14']),(3,900,975,'26506',wed,['12-16'])],
'GEDG002-48':[(2,810,885,'26506',tue,['12-15']),(4,720,795,'26506',thu,['12-17'])],
'GEDG002-54':[(5,540,615,'26506',fri,['12-18']),(5,630,705,'26506',fri,['12-18'])],
'GEDW027-41':[(3,990,1065,'36209',wed,['12-16'])],
'GEDW004-41':[(3,630,705,'36209',wed,['12-16'])],
'GEDW004-42':[(3,540,615,'36209',wed,['12-16'])],
'GEDW004-45':[(3,900,975,'36209',wed,['12-16'])]}
receipt=[]
for key,frames in rows.items():
 c=next(x for x in courses if x['courseCode']+'-'+x['section']==key);expected=[]
 for weekday,a,b,room,dates,excluded in frames:
  for short in dates:
   if short in excluded:continue
   date='2026-'+short;assert datetime.date.fromisoformat(date).isoweekday()==weekday;expected.append({'weekday':weekday,'startMinute':a,'endMinute':b,'classroom':room,'date':date,'deliveryMode':'inPerson'})
 expected.sort(key=lambda x:(x['date'],x['startMinute']));assert expected==c['schedules'];receipt.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':expected})
assert sum(len(x['expectedSchedulesLiteral']) for x in receipt)==358
bases=[read(f'baseline-skku-{campus}-2026-2.json') for campus in ['humanities','naturalScience','icampus']];new={c['sourceId']:c for c in courses};unchanged=0;oldplans=0;oldscheduled=0
for d in bases:
 for b in d['courses']:
  if b['courseCode']+'-'+b['section'] in rows:continue
  assert new[b['sourceId']]==b
  unchanged+=1;oldplans+=len(b['schedules']);oldscheduled+=bool(b['schedules'])
assert (unchanged,oldscheduled,oldplans)==(2765,1720,47771)
(p/'independent-literal-date-validation.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'result':'PASS','newCourses':17,'newMeetings':358,'priorWholeCourses':2765,'priorScheduledCourses':1720,'priorMeetings':47771,'totalScheduledCourses':1737,'totalMeetings':48129,'ordinalExclusionsNotActualExamDates':True,'byCourse':receipt},ensure_ascii=False,indent=2)+'\n');print('PASS 17/358, prior1720/47771 retained, total1737/48129')
