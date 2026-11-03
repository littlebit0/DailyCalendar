import pathlib,json,datetime
p=pathlib.Path('work/university-research/catalog-c/skku-held-own-operation-v29-20261009');read=lambda n:json.loads((p/n).read_text());write=lambda n,x:(p/n).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
allc=[];bas=[]
for campus in ['humanities','naturalScience','icampus']:
 b=read(f'baseline-skku-{campus}-2026-2.json');bas+=b['courses'];f=p/f'skku-{campus}-2026-2.own-operation-v29.json';allc+=(json.loads(f.read_text()) if f.exists() else b)['courses']
mds={1:'08-31 09-07 09-14 09-21 10-12 10-26 11-02 11-09 11-16 11-23 11-30 12-07'.split(),3:'09-02 09-09 09-16 09-23 09-30 10-07 10-14 10-28 11-04 11-11 11-18 11-25 12-02 12-09'.split()}
slots={'CHI3038-01':[(1,900,975,'31502'),(3,990,1065,'31502')],'CHI3054-01':[(1,990,1065,'31502'),(3,900,975,'31502')]};receipts=[]
for key,frames in slots.items():
 c=next(x for x in allc if x['courseCode']+'-'+x['section']==key);expect=[]
 for weekday,start,end,room in frames:
  for md in mds[weekday]:
   day='2026-'+md;assert datetime.date.fromisoformat(day).isoweekday()==weekday
   expect.append({'weekday':weekday,'startMinute':start,'endMinute':end,'classroom':room,'date':day,'deliveryMode':None})
 expect.sort(key=lambda m:(m['date'],m['startMinute']));assert c['schedules']==expect
 receipts.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':expect,'dateListIsIndependentValidatorLiteralNotLiteralSourceDate':True,'sourceActualLiteralDates':[],'actualIndividualExamDatesConfirmed':False,'modeForced':False})
unchanged=0
for b,c in zip(bas,allc):
 if b['courseCode']+'-'+b['section'] not in slots:assert b==c;unchanged+=1
assert unchanged==2780;assert len([c for c in bas if c['schedules']])==1784;assert sum(len(c['schedules']) for c in bas)==49141;assert len([c for c in allc if c['schedules']])==1786;assert sum(len(c['schedules']) for c in allc)==49193
write('independent-literal-date-validation.json',{'result':'PASS','sourceOnly':True,'SDKExecuted':False,'byCourse':receipts,'oldWholeCourses':1784,'oldPlans':49141,'unchangedOtherObjects':2780,'newCourses':2,'newPlans':52,'candidateWholeCourses':1786,'candidateWholePlans':49193});print('PASS 2/52 prior1784/49141 all2780whole unchanged')
