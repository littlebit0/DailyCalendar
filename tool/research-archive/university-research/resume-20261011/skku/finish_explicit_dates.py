import json,hashlib,copy,datetime,re
from pathlib import Path
ROOT=Path('.');OUT=ROOT/'work/university-research/resume-20261011/skku'
short=json.loads((OUT/'fall-date-shortlist.json').read_text())
reasons={
'FTM4035-01':'Plan ends 17:50; current native frame ends 17:45. Clock conflict not silently normalized.',
'GEDN054-01':'Date-like tokens are references/outline numbering, not attendance dates.',
'CFTD069-41':'Assignment deadlines and unallocated online/offline BL; no dated synchronous frame.',
'BUS2015-03':'Literal dated topics exist, but dated physical/live allocation of PBL is not explicit.',
'SPT4009-41':'Dated topics exist; extraction does not explicitly establish offline/live allocation; glyph completeness unproven.',
'KID4022-01':'Flipped-learning dated topics do not explicitly allocate remaining physical/live dates.',
'GEDC010-15':'Plan Friday dates conflict with native Saturday frame; prerecorded delivery is not attendance.',
'CLA7101-01':'Prerecorded course and report dates do not reserve live attendance.',
'CFTD108-01':'Printed CTTD108 identity differs; online-theory/offline-demo dates not allocated.',
'SOA4010-01':'Plan clock ends 17:50 vs native 17:45; fieldtrip/Roblox dates do not resolve matching native attendance.',
'PHR3143-41':'Weekly live Zoom or recording alternative, no directly dated exclusive attendance allocation. No week arithmetic.',
'GEDC010-10':'Plan 11:00–12:40 conflicts native end 12:50; preserve dated in-person evidence but hold clock conflict.',
'STA2011-01':'9월/10월 followed by numbered topics, not exact month-day attendance dates.',
'GEDC010-14':'Printed GEDC010-00 placeholder section, no verified explicit section14 in body; preserve date evidence separately.',
'GEDT017-67':'Body sections49/59 differ from target67; no substitution.',
'CFTD110-41':'Direct dates exist but blended online/offline date allocation is unspecified.',
'BUS2005-04':'Ordinary learning explicitly flexible-time online; sole 12/12 in-person final has no actual exam clock.',
'ART2046-01':'Practical/project dates exist, but attendance mode/PBL allocation not explicitly assigned; individual meetings and field events retained as evidence.',
'CFTD048-01':'Attached body CFTD065-01 differs from CFTD048-01; date tokens are assignment deadlines.',
'CFTD070-01':'100-minute live portion not allocated within two native75-minute blocks; no invented timing.',
'ART3075-01':'Dated project/practical topics exist; no explicit offline/live allocation for reserved PBL frames.',
'IPH4004-41':'Source Monday15–16:30 room86102 conflicts native Wednesday12/13 room86120.',
'GEDS070-41':'Prerecorded online dates do not reserve synchronous attendance.',
'GEDI003-02':'Holiday dates do not supply dated ordinary attendance; remaining plan uses weeks without exact dates.',
'ESM3050-41':'English Fall dates and Korean spring-date table coexist; team project/video submission activities lack dated physical/live attendance allocation.',
'EAM3099-42':'Month plus numbered laboratory topics, not exact dates; live allocation across two weekdays unspecified.',
'FDM3019-01':'Studio/project dates and makeup-needed note exist, but PBL actual attendance allocation and exhibition time unresolved.',
'GEDT017-79':'Body sections49/59 differ from target79; no substitution.',
'CFTD065-01':'10/25 and12/6 are assignment deadlines, not dated attendance.',
'GEDC010-11':'Video and offline freely combined; no per-date offline/live assignment.',
'CAL2076-41':'Filename2026 but body2025 Fall and 2025 Friday dates; do not change year.',
'CFTD097-01':'75-minute synchronous portion not allocated within native two50-minute slots.',
'BUS3045-05':'12.5 is topic/chapter notation; online-concept/offline-analysis week allocation has no literal attendance dates.',
'GEDM001-D7':'Attachment filenameD7 but bodyGEDM001-C2; exact section identity unresolved.'}
configs={
'DKL2018-02':('1','inPerson','09-02 09-09 09-23 09-30 10-14 10-21 11-11 11-18 11-25 12-02',False,['09-16/10-07/11-04 explicitly prerecorded','10-28/12-09 exams not assigned exam clock','Attachment2 partial duplicate; attachment1 used']),
'ART2069-01':('1','inPerson','09-10 09-17 10-01 10-08 10-15 10-22 10-29 11-05 11-12 11-19 11-26 12-03 12-10',False,['09-03 mixed online orientation/offline lecture allocation unknown','09-24 holiday/task no makeup clock','12-17 critique no explicit offline row']),
'EPN2004-01':('1','inPerson','08-31 09-02 09-07 09-09 09-14 09-16 09-21 09-23 09-30 10-07 10-12 10-14 10-19 10-21 10-26 10-28 11-02 11-04 11-09 11-11 11-16 11-18 11-25 11-30 12-02 12-07 12-09',False,['09-28/10-05 prerecorded in both tables','11-23 one table offline/default vs second explicitly prerecorded: date held','12-14 reflection-report deadline, not timed attendance','Overlapping topics preserved; no table chosen over other']),
'AAI2005-02':('1',None,'08-31 09-07 09-14 09-21 10-12 10-26 11-02 11-09 11-16 11-23 11-30',False,['First knowledge-acquisition prerecorded: no attendance reservation','Second slot classroom/Zoom choice preserved; no forced deliveryMode','09-28/10-05 common closures without explicit makeup held','10-19/12-14 exams no exam clock','12-07 absent from printed table: no inferred date']),
'CFTD003-41':('1','liveOnline','09-04',False,['Only09-04 row explicitly realtime online; no extension to later rows','Unassigned room preserved in original source but blank in live-online meeting']),
'GEDT017-47':('2','inPerson','09-11 09-18 10-02 10-16 11-06 11-13 11-20 11-27 12-11',True,['Attachment2 current school file row is section47 but body has no identity header','Attachment1 body actually section46; do not use attachment1','09-04/09-25/10-09 prerecorded','10-23/10-30/12-04 officehour/team work explicitly no classroom lecture','12-18 no explicit mode'])}
assets={};lookup={}
for p in [ROOT/'assets/timetable/skku-humanities-2026-2.json',ROOT/'assets/timetable/skku-naturalScience-2026-2.json']:
 d=json.loads(p.read_text());assets[str(p)]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'courseCount':len(d['courses'])}
 for c in d['courses']:lookup[c['courseCode']+'-'+c['section']]=(p,c)
base=ROOT/'work/university-research/catalog-c/skku-public-primary-bulk-v192-20261010'
patches=[];decisions=[]
for item in short:
 key=item['offering'];p=ROOT/item['cache'];s=json.loads(p.read_text());chosen=key in configs and p.name==key.lower()+'-attachment'+configs[key][0]+'-education-cache.json'
 reason=('direct dated attendance candidate; excluded rows separately held' if chosen else ('partial duplicate; use attachment1 only' if key=='DKL2018-02' else ('wrong-section attachment1; candidate based only on exact linked attachment2' if key=='GEDT017-47' else reasons.get(key,'unresolved'))))
 decisions.append({'offeringCode':key,'cache':str(p),'cacheSha256':hashlib.sha256(p.read_bytes()).hexdigest(),'sourceSha256':s.get('sha256'),'sourceURL':s.get('sourceURL'),'publicAttachmentRow':s.get('publicAttachmentRow'),'currentFileRow':s.get('currentFileRow'),'decision':('conditionalCandidate' if chosen and configs[key][3] else 'additiveCandidate' if chosen else 'held'),'reason':reason,'nativeDateContexts':item['hits'],'fullEducationalTextCache':s['educationFullText'],'originalHumanVisualCompletenessConfirmed':False})
for key,(seq,mode,dates,conditional,holds) in configs.items():
 p,c=lookup[key];sfile=base/(key.lower()+'-attachment'+seq+'-education-cache.json');s=json.loads(sfile.read_text());n=copy.deepcopy(c);meetings=[]
 for md in dates.split():
  date='2026-'+md;wd=datetime.date.fromisoformat(date).isoweekday();frames=[f for f in c['rawMeetingFrameForReviewOnly'] if f['weekday']==wd];assert frames,(key,date)
  for f in frames:
   f=copy.deepcopy(f);f['date']=date
   if mode:f['deliveryMode']=mode
   if key in ['CFTD003-41','ART2069-01']:f['classroom']=''
   meetings.append(f)
 n['schedules']=copy.deepcopy(c['schedules'])+meetings;n['scheduleStatus']='scheduled';n['scheduleEvidenceKind']='plannedRegularTimetable';n['actualAttendanceConfirmed']=False;n['commonClosureDatesApplied']=True
 n['operatingReviewBasis']='Only directly printed 2026 fall dates with explicit classroom or realtime allocation, aligned with current native clock. Prerecorded, ambiguous and examination rows remain unreserved. User-selected attendance mode is preserved where school permits classroom/Zoom choice.'
 n['partialOperatingRegistration']=True
 n['sourceEducationalOperatingEvidenceReference']={'file':'work/university-research/resume-20261011/skku/additive-date-candidates.json','offeringCode':key,'sourceCache':str(sfile),'sourceSha256':s.get('sha256'),'conditionalIdentityReviewRequired':conditional}
 for dep,text in n.get('departmentRemarks',{}).items():n['departmentRemarks'][dep]=text+'\n추가 확보된 공개 계획서의 직접 날짜와 대면·실시간 시각만 반영한 부분 시간표입니다. 사전제작·시험 및 미확정 배정은 예약하지 않았습니다.'
 patches.append({'offeringCode':key,'asset':str(p),'assetBeforeSha256':assets[str(p)]['sha256'],'conditionalReviewRequired':conditional,'originalWholeObject':c,'proposedWholeObject':n,'newMeetingCount':len(meetings),'newDirectDates':['2026-'+x for x in dates.split()],'allDirectDatesWithinOriginalTermFrame':all(c['ordinaryTermFrameForReviewOnly']['startDate']<=f['date']<=c['ordinaryTermFrameForReviewOnly']['endDate'] for f in meetings),'originalTermFrame':c['ordinaryTermFrameForReviewOnly'],'excludedOrHeldConditions':holds,'source':{'cache':str(sfile),'cacheSha256':hashlib.sha256(sfile.read_bytes()).hexdigest(),'originalSourceSha256':s.get('sha256'),'sourceURL':s.get('sourceURL'),'currentFileRow':s.get('currentFileRow'),'publicAttachmentRow':s.get('publicAttachmentRow'),'fullEducationalText':s['educationFullText'],'humanSourceVisualCompletenessConfirmed':False},'preservation':{'originalMeetingCount':len(c['schedules']),'allOriginalMeetingsRetained':n['schedules'][:len(c['schedules'])]==c['schedules'],'sourceScheduleUnchanged':n['sourceSchedule']==c['sourceSchedule'],'sourceEducationalMetadataUnchanged':n['sourceEducationalMetadata']==c['sourceEducationalMetadata'],'rawFramesUnchanged':n['rawMeetingFrameForReviewOnly']==c['rawMeetingFrameForReviewOnly'],'departmentRemarksPreservedAsPrefix':all(n['departmentRemarks'][d].startswith(t) for d,t in c.get('departmentRemarks',{}).items())}})
packet={'sourceOnly':True,'productChangesPerformed':False,'assetsAtReceipt':assets,'shortlistAttachmentCount':len(short),'patches':patches,'existingReservationDeletionOrModificationRequested':[],'reusableCacheDoesNotEstablishFullVisualSourceCompleteness':True,'counts':{'confirmedCourses':sum(not p['conditionalReviewRequired'] for p in patches),'conditionalCourses':sum(p['conditionalReviewRequired'] for p in patches),'confirmedNewMeetings':sum(p['newMeetingCount'] for p in patches if not p['conditionalReviewRequired']),'conditionalNewMeetings':sum(p['newMeetingCount'] for p in patches if p['conditionalReviewRequired'])}}
conditional=copy.deepcopy(packet);conditional['patches']=[p for p in patches if p['conditionalReviewRequired']];conditional['integrationAllowed']=False;conditional['reason']='Section47 linked currentFileRow but body lacks section header; attachment1 explicitly section46. Parent identity adjudication required.'
packet['patches']=[p for p in patches if not p['conditionalReviewRequired']]
(OUT/'conditional-identity-candidates.json').write_text(json.dumps(conditional,ensure_ascii=False,indent=2)+'\n')
(OUT/'additive-date-candidates.json').write_text(json.dumps(packet,ensure_ascii=False,indent=2)+'\n')
(OUT/'all43-date-adjudication.json').write_text(json.dumps({'sourceOnly':True,'attachmentCount':len(decisions),'decisions':decisions},ensure_ascii=False,indent=2)+'\n')
print(packet['counts']);print('decisions',len(decisions));print([(p['offeringCode'],p['newMeetingCount']) for p in patches])
