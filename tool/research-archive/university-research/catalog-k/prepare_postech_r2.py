"""Independent immutable r2: exact public row pairing and dated room/Webex changes."""
import copy,datetime as dt,hashlib,json,pathlib,re
R=pathlib.Path(__file__).resolve().parent
old=json.loads((R/'postech-main-2026-2.planned-audited-20261008-r1.json').read_text());new=copy.deepcopy(old)
rawpair=json.loads((R/'postech-ambiguous-room-time-plan-check.json').read_text())
closures=set(json.loads((R/'postech-planned-audited-20261008-r1-sha-manifest.json').read_text())['closureDates'])
changed=[]
for c in new['courses']:
 code=c['courseCode']
 if code not in ['NGCN302','SEMI202','SEMI323']:continue
 meetings=[]
 if code in ['NGCN302','SEMI202']:
  if code=='NGCN302':slots=[{'weekday':1,'startMinute':1020,'endMinute':1070,'classroom':'LG연구동 강의실 [102호]'}, {'weekday':1,'startMinute':1140,'endMinute':1340,'classroom':''}];note='월19:00–22:20 강의실 미게시. 월17:00–17:50은 LG연구동102호로 별도 게시.'
  else:slots=[{'weekday':d,'startMinute':570,'endMinute':645,'classroom':'제2공학관 강의실 [102호]'} for d in [2,4]];note='같은 시각의 원행 중 게시된 제2공학관102호를 보존하고 동일 회의를 합침.'
  day=dt.date(2026,9,7)
  while day<=dt.date(2026,12,24):
   for slot in slots:
    if day.isoweekday()==slot['weekday'] and day.isoformat() not in closures:meetings.append(dict(slot,date=day.isoformat()))
   day+=dt.timedelta(days=1)
  evidence=next(x for x in rawpair if x['code']==code)
  c['metadata']['pairedPublicPlanTimeRoomEvidence']=evidence
 else:
  # The current plan gives each dated lecture/lab entry. Exam entries are not
  # turned into exact exam-time claims; normal public slots remain separate evidence.
  weeks=c['metadata']['sourceOperatingSections']['8. 강의진도계획']
  entries=re.findall(r'^\((\d{1,2})/(\d{1,2})\)([^\n]*)',weeks,re.M)
  physical_tues={'2026-09-08','2026-09-15','2026-09-22','2026-10-06','2026-10-20'}
  live={'2026-11-10','2026-11-17','2026-11-24','2026-12-01','2026-12-08'}
  for month,day,title in entries:
   date=dt.date(2026,int(month),int(day));ds=date.isoformat()
   if ds in closures or re.search('Exam|추석',title,re.I):continue
   assert date.isoweekday() in [2,4]
   virtual=ds in live
   room='' if virtual else ('C5 [422-1호]' if date.isoweekday()==4 or ds in physical_tues else '나노융합기술원 [510호] 반도체공학과 실험실습실')
   meeting={'weekday':date.isoweekday(),'startMinute':660,'endMinute':760,'classroom':room,'date':ds}
   if virtual:meeting['deliveryMode']='liveOnline'
   meetings.append(meeting)
  note='계획서에 명시된 일반강의·실습 날짜/강의실만 반영. 11/10·11/17·11/24·12/1·12/8은11:00–12:40 Webex. 시험 실제 시각은 별도 미게시이므로 생성하지 않음. 공통 휴업일 제외.'
 c['schedules']=meetings;c['scheduleStatus']='scheduled';c['metadata']['plannedTimetableDecision']='plannedRegularTimetable' if code!='SEMI323' else 'explicitDatedPartialTimetable';c['metadata']['decisionReason']=note
 for dep in c['departments']:c['departmentRemarks'][dep]+='\n'+note
 changed.append({'code':code,'section':c['section'],'dateCount':len(meetings),'reason':note})
assert len(changed)==3
for a,b in zip(old['courses'],new['courses']):
 if a['courseCode'] not in ['NGCN302','SEMI202','SEMI323']:assert a==b
 for field in ['sourceId','courseCode','section','sourceSchedule','sourceClassroom','professor','departments','credits','departmentCredits','departmentClassifications']:
  assert a[field]==b[field]
fn='postech-main-2026-2.planned-audited-20261008-r2.json';content=(json.dumps(new,ensure_ascii=False,indent=2)+'\n').encode();(R/fn).write_bytes(content)
manifest={'researchOnly':True,'completionClaim':False,'file':fn,'sha256':hashlib.sha256(content).hexdigest(),'parentR1SHA':hashlib.sha256((R/'postech-main-2026-2.planned-audited-20261008-r1.json').read_bytes()).hexdigest(),'currentPublicOfferingCount':418,'scheduledCount':sum(bool(c['schedules']) for c in new['courses']),'dateCount':sum(len(c['schedules']) for c in new['courses']),'changed':changed,'other415CourseObjectsUnchanged':True,'allCoreMetadataAndRawSourceSchedulesUnchanged':True,'sameTermAndClosurePolicyAsR1':True}
(R/'postech-planned-audited-20261008-r2-sha-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in manifest.items() if k in ['sha256','scheduledCount','dateCount','changed']})
