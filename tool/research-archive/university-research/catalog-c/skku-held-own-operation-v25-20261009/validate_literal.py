import json,pathlib,datetime
p=pathlib.Path(__file__).parent;read=lambda n:json.loads((p/n).read_text());datasets={c:read('skku-'+c+'-2026-2.own-operation-v25.json') if (p/('skku-'+c+'-2026-2.own-operation-v25.json')).exists() else read('baseline-skku-'+c+'-2026-2.json') for c in ['humanities','naturalScience','icampus']};allc=[c for d in datasets.values() for c in d['courses']]
literal={'CFTD122-02':('09-01 09-08 09-15 09-22 09-29 10-06 10-13 10-20 10-27 11-03 11-10 11-17 11-24 12-01',[(2,1200,1250,'50105')],'inPerson'),'CFTD045-01':('08-31 09-07 09-14 09-21 10-12 10-19 10-26 11-02 11-09 11-16 11-23 11-30 12-07',[(1,1080,1155,'50401'),(1,1170,1245,'50401')],None),'GEDC010-50':('09-03 09-10 10-01 10-15 10-29 11-12 11-19 11-26 12-10',[(4,780,830,'36215'),(4,840,890,'36215')],None)}
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
assert (unchanged,oldcourses,oldplans)==(2779,1777,48975)
r={'sourceOnly':True,'SDKExecuted':False,'result':'PASS','newCourses':3,'newMeetings':58,'priorWholeCourses':unchanged,'priorScheduledCourses':oldcourses,'priorMeetings':oldplans,'totalScheduledCourses':1780,'totalMeetings':49033,'ordinalProjectionApplied':False,'literalExpectedValuesAreIndependentTestOracle':True,'sourceLiteralCourseIds':['GEDC010-50'],'sourceDerivedRegularCourseIds':['CFTD122-02','CFTD045-01'],'byCourse':proof};(p/'independent-literal-date-validation.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print('PASS 3/58 oldwhole1777/48975 total1780/49033')
