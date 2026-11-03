# coding: utf-8
"""Research-only complete metadata; unresolved scheduling stays individually blocked."""
import json,re,datetime,collections
from pathlib import Path
P=Path(__file__).resolve().parent
catalog=json.loads((P/'gachon-current-refresh/courses.json').read_text())
short={(r['campus'],r['sourceRow']['HAKSU_NO']):r for r in json.loads((P/'gachon-short-course-period-candidates.json').read_text())['rows']}
nonshort={(r['campus'],r['sourceRow']['HAKSU_NO']):r for r in json.loads((P/'gachon-nonshort-report-exception-audit.json').read_text())['reports']}
cyber={r['sourceRow']['HAKSU_NO']:r for r in json.loads((P/'gachon-cyber-delivery-context-review.json').read_text())['rows']}
allcourses=[]
for item in catalog:
 r=item['row'];full=r['HAKSU_NO'];campus=item['campus'];key=(campus,full)
 assert re.fullmatch('[A-Z0-9]{8}',full)
 code=full[:5];section=full[5:];title=r['SUBJECT_NM_KOR'].strip();blocks=[]
 rawslots=[]
 for day,period in re.findall(r'([월화수목금토일])(\d+)',r['TIME'] or ''):
  n=int(period);assert 1<=n<=14
  rawslots.append({'weekday':'월화수목금토일'.index(day)+1,'period':n,'startMinute':480+60*n,'endMinute':530+60*n})
 for s in sorted(rawslots,key=lambda s:(s['weekday'],s['period'])):
  if blocks and blocks[-1]['weekday']==s['weekday'] and blocks[-1]['lastPeriod']+1==s['period']:
   blocks[-1]['lastPeriod']=s['period'];blocks[-1]['endMinute']=s['endMinute']
  else:blocks.append({'weekday':s['weekday'],'firstPeriod':s['period'],'lastPeriod':s['period'],'startMinute':s['startMinute'],'endMinute':s['endMinute'],'classroom':r['LOC_NM'] or ''})
 reasons=[];period={'startDate':'2026-09-01','endDate':'2026-12-14','evidence':'gachon-current-scope-clock-term-manifest.json','kind':'ordinarySemesterFinalExamEnd; conditional makeup is not automatic weekly recurrence'}
 c=short.get(key)
 if c:
  assert c['sourceRow']==r
  if not c['periodBoundValidated'] or c['candidatePeriod'] is None:
   reasons+=['current individual concentrated teaching period missing/conflicting'];period=None
  else:
   p=c['candidatePeriod'];period={'startDate':p['start'],'endDate':p['last'],'evidence':'gachon-short-course-period-candidates.json','kind':p.get('lastMeans','explicit current individual published period')}
  review=c.get('contextReview') or {};cl=review.get('contextClassification','')
  if c.get('unresolvedOperatingException'):reasons+=['current makeup/delivery/exam actual date or clock unresolved']
  if cl in ['online_exception','weekly_online_exception','weekly_online_exception_and_exam_notice','delivery_notice']:
   reasons+=['per-week online replacement requires exact synchronous/asynchronous and day verification']
  if review.get('explicitExceptions') and cl not in ['scheduled_exam','scheduled_exam_and_assignment']:
   reasons+=['explicit operating exception not yet normalized into verified meetings']
 ns=nonshort.get(key)
 if ns:
  assert ns['sourceRow']==r
  ident=ns['report'];weeks=ns['weeklyRows']
  if not all(ident.get(k) for k in ['headerCourseCodeMatches','currentTermMatches','catalogProfessorAppearsInReport']):reasons+=['current public plan identity not fully verified']
  if len(weeks)!=15 or {w['week'] for w in weeks}!=set(range(1,16)):reasons+=['current individual weekly schedule incomplete/nonstandard; no ordinary repeat fallback']
  signals={s for w in weeks for s in w['signals']}
  if signals & {'보강','휴강'}:reasons+=['current plan explicitly announces makeup/no-class exception not yet normalized']
  if signals & {'온라인','비대면','녹화','원격'} and '실시간화상강의' not in title:
   reasons+=['public plan contains delivery exception requiring actual per-week review']
 if 'AI-NTree' in title:reasons+=['actual two-day department subgroup period and clock unresolved/conflicting'];period=None
 if code=='09804':reasons+=['current2026-2 social-service notice122814: only weeks1-3 and end-term in-person; individual dates/instructor notice required, no whole-term repeat']
 if full in ['11396001','11396002']:reasons+=['explicit no classes in weeks8/15 requires dated meeting conversion']
 delivery=None;cr=cyber.get(full)
 if '실시간화상강의' in title:delivery='liveOnline'
 elif r['CYBER_YN']=='CYBER':
  classification=cr.get('deliveryClassification') if cr else None
  if classification=='asynchronous_video':delivery='asynchronous';blocks=[]
  elif classification=='flipped_with_in_person':delivery=None
  else:reasons+=['CYBER flag does not specify full synchronous/asynchronous meeting semantics']
 # Preserve complete metadata and all known individual gaps. No fabricated clocks/periods.
 reasons=list(dict.fromkeys(reasons))
 decision='unrecognized' if reasons else ('asynchronousVerified' if delivery=='asynchronous' else ('unscheduledUnposted' if not rawslots else 'regularCandidate'))
 credit=re.fullmatch(r'(\d+(?:\.\d+)?)\((\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)\)',r['SISU'] or '');assert credit
 out={'sourceId':f'gachon/{campus}/2026/2/{code}/{section}','universityId':'gachon','campus':'global' if campus=='20' else 'medical','campusSourceCode':campus,'campusName':'글로벌캠퍼스' if campus=='20' else '메디컬캠퍼스','academicYear':2026,'semester':'2','courseCode':code,'section':section,'officialOfferingCode':full,'courseName':title,'professor':r['PROFNM'] or '','credits':float(credit[1]),'classification':r['ISU_NM'],'area':r['AREA_NM'] or '','department':r['PRINT_DPT'] or '','rawCreditHours':r['SISU'],'rawSchedule':r['TIME'] or '','rawRoom':r['LOC_NM'] or '','sourceRow':r,'publishedActualSlots':rawslots,'period':period,'schedulingDecision':decision,'blockingReasons':reasons,'deliveryMode':delivery,'schedules':[] if reasons else blocks,'unrecognizedActualSlotCandidates':blocks if reasons else [],'operatingEvidence':{'short':c is not None,'nonshort':ns is not None,'cyberClassification':cr.get('deliveryClassification') if cr else None},'multipleRoomAssignmentPolicy':'original comma-separated room field preserved; no invented period-to-room assignment','researchOnly':True}
 if full=='12718001':
  evidence=json.loads((P/'gachon-12718001-ot-dated-evidence.json').read_text())
  assert evidence['officialOfferingCode']==full and evidence['courseCode']==code and evidence['section']==section
  assert all(evidence['currentReportIdentity'][k] for k in ['headerCourseCodeMatches','currentTermMatches','catalogProfessorAppearsInReport'])
  assert 'OT. 9/1 13-14' in evidence['sourcePhrase'] and '실시간 화상 OT (ZOOM)' in evidence['sourcePhrase']
  assert not reasons
  meeting=evidence['dateMeetingCandidate'];assert meeting['date']=='2026-09-01' and meeting['weekday']==2
  assert meeting['startMinute']==780 and meeting['endMinute']==840
  out['schedules']=[meeting];out['schedulingDecision']='datedCandidate';out['deliveryMode']=None
  out['weeklyRecurrenceAllowed']=False
  out['datedEvidence']='gachon-12718001-ot-dated-evidence.json'
  out['noTimedMeetingInfo']={'sourceFile':'gachon-cyber-delivery-context-review.json','sourceText':'매주 화요일 업데이트 되는 동영상 강의를 시청(일주일 내 원하는 시간에 시청가능)','semesterWeeklyGridMustNotBeRepeated':True}
 if delivery=='liveOnline':
  for m in out['schedules']:m['deliveryMode']='liveOnline'
 allcourses.append(out)
assert len(allcourses)==3809
assert len({r['sourceId'] for r in allcourses})==3809
assert len(short)==490
assert sum(r['period'] is not None for r in allcourses if r['operatingEvidence']['short'])==466
for r in allcourses:
 assert not r['blockingReasons'] or not r['schedules']
 for m in r['schedules']:assert 0<=m['startMinute']<m['endMinute']<=1440
counts=dict(collections.Counter(r['schedulingDecision'] for r in allcourses))
result={'researchOnly':True,'productionActivationAllowedByThisFixture':False,'completionClaim':False,'term':'2026-2','wholeMetadataCount':3809,'freshWholeSource':'gachon-current-refresh/courses.json','clockAndSchemaEvidence':'gachon-current-scope-clock-term-manifest.json','counts':counts,'scheduledCandidateTotal':counts.get('regularCandidate',0)+counts.get('datedCandidate',0),'limitation':'Current public metadata complete; individual operating exception candidates explicitly blocked. All3809 individual plans not reviewed; explicit cancellation flag/list not verified.','courses':allcourses}
(P/'gachon-full-normalized-source-candidates.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(counts)
(P/'gachon-individual-scheduling-gaps.json').write_text(json.dumps([{'code':r['officialOfferingCode'],'title':r['courseName'],'campus':r['campus'],'reasons':r['blockingReasons']} for r in allcourses if r['blockingReasons']],ensure_ascii=False,indent=2))
