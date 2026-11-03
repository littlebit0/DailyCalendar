import json,pathlib,datetime
p=pathlib.Path(__file__).parent;read=lambda n:json.loads((p/n).read_text());datasets={c:read('skku-'+c+'-2026-2.own-operation-v27.json') if (p/('skku-'+c+'-2026-2.own-operation-v27.json')).exists() else read('baseline-skku-'+c+'-2026-2.json') for c in ['humanities','naturalScience','icampus']};allc=[c for d in datasets.values() for c in d['courses']]
literal={'FTM3097-01':('09-01 09-08 09-15 09-22 09-29 10-06 10-13 10-20 10-27 11-03 11-10 11-17 11-24 12-01 12-08',[(2,1080,1155,'61415'),(2,1170,1245,'61415')],None),'COS3063-01':('09-09 09-16 09-23 09-30 10-07 10-14 10-28 11-04 11-11 11-18 11-25 11-30 12-02 12-07',[(1,990,1065,'31707'),(3,900,975,'31707')],'inPerson')}
proof=[]
for key,(mds,frames,mode) in literal.items():
 c=next(x for x in allc if x['courseCode']+'-'+x['section']==key);expected=[]
 for md in mds.split():
  date='2026-'+md;weekday=datetime.date.fromisoformat(date).isoweekday()
  for wd,start,end,room in frames:
   if wd==weekday:expected.append({'weekday':wd,'startMinute':start,'endMinute':end,'classroom':room,'date':date,'deliveryMode':mode})
 assert c['schedules']==expected,(key,c['schedules'][:2]);proof.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':expected})
oldplans=oldcourses=unchanged=0
for campus,d in datasets.items():
 b=read('baseline-skku-'+campus+'-2026-2.json')
 for old,new in zip(b['courses'],d['courses']):
  if old['courseCode']+'-'+old['section'] not in literal:
   assert old==new;unchanged+=1
   if old['schedules']:oldcourses+=1;oldplans+=len(old['schedules'])
  else:
   assert not old['schedules']
   for k in old:
    if k not in ['schedules','scheduleStatus','unresolvedReasons','researchOnly','scheduleEvidenceKind','actualAttendanceConfirmed','commonClosureDatesApplied','partialCoverage','period','departmentRemarks']:assert old[k]==new[k]
assert (unchanged,oldcourses,oldplans)==(2780,1780,49043)
r={'sourceOnly':True,'SDKExecuted':False,'result':'PASS','newCourses':2,'newMeetings':44,'priorWholeCourses':unchanged,'priorScheduledCourses':oldcourses,'priorMeetings':oldplans,'totalScheduledCourses':1782,'totalMeetings':49087,'ordinalProjectionApplied':False,'literalExpectedValuesAreIndependentTestOracle':True,'sourceLiteralCourseIds':['COS3063-01'],'sourceDerivedRegularCourseIds':['FTM3097-01'],'byCourse':proof};(p/'independent-literal-date-validation.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print('PASS 2/44 oldwhole1780/49043 total1782/49087')
