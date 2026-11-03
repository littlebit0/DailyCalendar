import json,pathlib,datetime
p=pathlib.Path(__file__).parent;read=lambda n:json.loads((p/n).read_text());datasets={c:read('skku-'+c+'-2026-2.own-operation-v22.json') if (p/('skku-'+c+'-2026-2.own-operation-v22.json')).exists() else read('baseline-skku-'+c+'-2026-2.json') for c in ['humanities','naturalScience','icampus']};allc=[c for d in datasets.values() for c in d['courses']]
literal={'PHR3167-41':('09-03 09-10 09-17 10-01 10-08 10-15 10-29 11-05 11-12 11-19 11-26 12-03 12-10',[(4,780,830,'530254'),(4,840,890,'530254'),(4,900,950,'530254')],None),'BIO3010-41':('08-31 09-02 09-07 09-09 09-14 09-16 09-21 09-23 12-07 12-09 12-14',[(1,720,795,'31213'),(3,810,885,'31213')],'inPerson'),'EEE3059-41':('08-31 09-02 09-07 09-09 09-14 09-16 09-21 09-23 09-30 10-07 10-12 10-14 10-21 10-26 10-28 11-02 11-04 11-09 11-11 11-16 11-18 11-23 11-25 11-30 12-02 12-07 12-09 12-16',[(1,720,795,'85731'),(3,810,885,'85731')],None)}
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
assert (unchanged,oldcourses,oldplans)==(2779,1769,48861)
r={'sourceOnly':True,'SDKExecuted':False,'result':'PASS','newCourses':3,'newMeetings':78,'priorWholeCourses':unchanged,'priorScheduledCourses':oldcourses,'priorMeetings':oldplans,'totalScheduledCourses':1772,'totalMeetings':48939,'ordinalProjectionApplied':False,'byCourse':proof};(p/'independent-literal-date-validation.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print('PASS 3/78 oldwhole1769/48861 total1772/48939')
