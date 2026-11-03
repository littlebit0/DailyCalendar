import json,copy,hashlib,collections,datetime,re
from pathlib import Path
R=Path('work/university-research/remaining-ordinary-native-clock-audit-v1-20261009'); P=Path('work/university-research/catalog-g')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def write(n,d):(R/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
files=read('assets/timetable/catalog.json'); groups={}; receipts=[]; shortlisted=[]
for f in files:
 d=read(f); uid=d['universityId'];g=groups.setdefault(uid,{'universityId':uid,'catalogFiles':[],'totalCourses':0,'scheduledCourses':0,'noScheduleCourses':0,'nativeStatusCounts':{},'explicitReasonCounts':{},'noExplicitReasonRowCount':0,'explicitClockTextAndMissingDedicatedProfessorOrRoomField':0})
 g['catalogFiles'].append(f);g['totalCourses']+=len(d['courses']); reasons=collections.Counter(g['explicitReasonCounts']); statuses=collections.Counter(g['nativeStatusCounts'])
 for c in d['courses']:
  if c.get('schedules'):g['scheduledCourses']+=1;continue
  g['noScheduleCourses']+=1;statuses[c.get('scheduleStatus','<absent>')]+=1; rowReasons=[]
  for obj in [c,c.get('metadata',{}),c.get('sourceEducation',{})]:
   if not isinstance(obj,dict):continue
   for k,v in obj.items():
    if any(t in k.lower() for t in ['reason','hold','blockingexplanation']):
     if isinstance(v,list):rowReasons.extend(f'{k}: '+(x if isinstance(x,str)else json.dumps(x,ensure_ascii=False,sort_keys=True))for x in v)
     elif v:rowReasons.append(f'{k}: {v}')
  if not rowReasons:g['noExplicitReasonRowCount']+=1
  reasons.update(set(rowReasons))
  exact=bool(re.search(r'[0-2]?\d:[0-5]\d',str(c.get('sourceSchedule',''))))or bool(c.get('rawMeetingFrameForReviewOnly'))
  if exact and(str(c.get('professor')or'').strip()in['','미정','미배정','000']or str(c.get('sourceClassroom')or'').strip()in['','미정','미배정','미지정','비지정']):g['explicitClockTextAndMissingDedicatedProfessorOrRoomField']+=1
  if c.get('unresolvedReasons')==['missingPublishedRoom']or c.get('metadata',{}).get('heldReasons')==['실제 강의실 미공개']:shortlisted.append({'asset':f,'baselineRow':c,'baselineRowCanonicalSHA256':hashlib.sha256(json.dumps(c,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()})
 g['nativeStatusCounts']=dict(statuses);g['explicitReasonCounts']=dict(reasons);receipts.append({'file':f,'sha256':sha(f),'universityId':uid,'campus':d['campus']})
write('all-current-native-catalog-file-receipts.json',receipts)
write('all-current-university-remaining-reason-census.json',{'checkpointSourceAtAcquisition':118,'completionClaim':False,'reasonCountsMeaning':'Direct existing explicit reason occurrences, not newly proved impossibility; reasons overlap. Empty sourceClassroom field does not prove absent classroom because sourceSchedule may contain native room. No explicit reason means not inferred.','catalogFiles':len(files),'universityCount':len(groups),'universities':list(groups.values())})
write('all16-room-only-reason-full-native-rows.json',shortlisted)
audit=read(P/'skku-public-operating-plan-audit.json'); selected={r['offeringCode']:r for r in audit['records']if r['offeringCode']in['CFTD088-01','CFTD086-01','MED3141-41','MED3142-41','MED3162-41']}
write('current5-full-available-operating-records.json',selected)
calpaths=[P/'skku-current-term-closure-rule-evidence.json',Path('work/university-research/catalog-w/dongguk/current-own-calendar-education.json')]
write('own-calendar-native-receipts.json',[{'file':str(p),'sha256':sha(p),'education':read(p)}for p in calpaths])
proof=[];counts=[]
for asset,key,weekday,start,end,room in [('assets/timetable/dongguk-seoul-2026-2.json','MGT4090-01',1,720,780,''),('assets/timetable/skku-humanities-2026-2.json','CFTD088-01',4,810,885,'50305'),('assets/timetable/skku-humanities-2026-2.json','CFTD086-01',4,1080,1150,'31506')]:
 before=read(asset); name=Path(asset).stem
 if not(R/(name+'.baseline118.json')).exists():write(name+'.baseline118.json',before)
 target=next(c for c in before['courses']if c['courseCode']+'-'+c['section']==key)
 if 'dongguk' in asset:
  assert target['metadata']['heldReasons']==['실제 강의실 미공개'];native=target['metadata']['nativeEducationalRow'];assert native['강의형태']=='일반강의'and native['집중이수학기기간']is None and native['강의유형']=='이론'
  begin=datetime.date(2026,9,1);finish=datetime.date(2026,12,7);blocked={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}|{f'2026-10-{d}'for d in range(20,27)};record={'nativeEducationalRow':native};basis='Published ordinary native Monday12:00–13:00 clock; missing professor and room preserved blank. Individual interview requirement preserved; no placement/intensive or multiple-room ambiguity.'
 else:
  record=selected[key];row=record['sourceRow'];detail=record['detail'][0]
  assert row['GAESUL_YEAR']=='2026'and row['GAESUL_TERM']=='20'and row['HAKBU_JIBJUNG_GB']=='N'and row['SUUP_TYPE_CD']=='33'and row['PER_NAME']==target['professor']==detail['PER_NAME']
  assert room+'호'in row['BIGO'];assert '온라인[사전제작]+오프라인'in row['SUUP_TYPE_NM'];assert target['unresolvedReasons']==['missingPublishedRoom']
  rules=read(calpaths[0]);begin=datetime.date.fromisoformat(rules['term']['startDate']);finish=datetime.date.fromisoformat(rules['term']['endDate']);blocked=set(rules['nationalHolidayDates']['dates'])|set(rules['closureRule']['schoolSpecificClosures']);basis='Exact current published offline Thursday clock; asynchronous0.5h preparation has no created time. Native BIGO explicitly names combined-class room; preserve original 미지정 field and use same-offering remark room only. No guessed building/campus or second course room.'
 meetings=[];day=begin
 while day<=finish:
  if day.isoweekday()==weekday and day.isoformat()not in blocked:meetings.append({'date':day.isoformat(),'weekday':weekday,'startMinute':start,'endMinute':end,'classroom':room})
  day+=datetime.timedelta(days=1)
 proof.append({'sourceId':target['sourceId'],'asset':asset,'nativeCodeSection':key,'nativeClock':[weekday,start,end],'meetingRoom':room,'originalSourceClassroom':target.get('sourceClassroom'),'baselineRow':target,'ownOperatingRecord':record,'basis':basis,'expectedDatesIndependentlyListedInFixture':True,'candidateDatedCount':len(meetings),'fullAttachmentBoundary':'CFTD086 original HWPX binary not retained; current full available parsed educational record frozen, not native binary SHA proof.'if key=='CFTD086-01'else'Full current inline detail/native educational row available.', 'eligibilityState':'sourceOnlyCandidateReviewNotProductActivation'})
# build one combined candidate per affected campus, allotherwholeobjects preserved
for name in ['dongguk-seoul-2026-2','skku-humanities-2026-2']:
 before=read(R/(name+'.baseline118.json'));after=copy.deepcopy(before);ids={p['sourceId']:p for p in proof if Path(p['asset']).stem==name}
 for c in after['courses']:
  if c['sourceId']not in ids:continue
  p=ids[c['sourceId']];weekday,start,end=p['nativeClock'];dates=(['2026-'+s for s in ['09-07','09-14','09-21','09-28','10-12','10-19','11-02','11-09','11-16','11-23','11-30','12-07']]if weekday==1 else['2026-'+s for s in ['09-03','09-10','09-17','10-01','10-08','10-15','10-22','10-29','11-05','11-12','11-19','11-26','12-03','12-10','12-17']])
  assert len(dates)==p['candidateDatedCount']
  c['schedules']=[{'date':d,'weekday':weekday,'startMinute':start,'endMinute':end,'classroom':p['meetingRoom']}for d in dates];c['scheduleStatus']='scheduled'
  c['sourceRoomOnlyOrdinaryReview']={'basis':p['basis'],'actualAttendanceConfirmed':False,'originalRoomRetained':True,'sourceProof':'independent3-native-source-proof.json'}
  if weekday==4:c['sourceExplicitRemarkRoom']=p['meetingRoom'];c['unresolvedReasons']=[];c['period']={'startDate':'2026-08-31','endDate':'2026-12-18'}
  else:c['metadata']['heldReasons']=[]
 for old,new in zip(before['courses'],after['courses']):
  if old['sourceId']not in ids:assert old==new
  else:
   for k in old:
    if k in['schedules','scheduleStatus','unresolvedReasons','metadata','period']:continue
    assert old[k]==new[k],k
 after.update(researchOnly=True,productionIntegrationEnabled=False,completionClaim=False,wholeOperatingVerified=False)
 write(name+'.room-only-ordinary-candidate.json',after)
 counts.append({'campus':after['campus'],'universityId':after['universityId'],'courses':len(after['courses']),'scheduled':sum(bool(c['schedules'])for c in after['courses']),'dated':sum(len(c['schedules'])for c in after['courses']),'newCourses':len(ids),'newDatedMeetings':sum(p['candidateDatedCount']for p in ids.values())})
write('independent3-native-source-proof.json',proof);write('candidate-counts.json',counts)
assert all(sha(r['file'])==r['sha256']for r in receipts)
print({'universities':len(groups),'catalogs':len(files),'noSchedule':sum(g['noScheduleCourses']for g in groups.values()),'shortlist':len(shortlisted),'candidate':counts})
