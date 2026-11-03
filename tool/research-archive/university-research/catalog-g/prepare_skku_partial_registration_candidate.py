"""Freeze full current metadata plus only explicitly reviewed dated offerings.
This permits bounded partial registration, never a whole-university completion claim.
"""
import json,hashlib,datetime,collections,argparse,re
from pathlib import Path
P=Path(__file__).resolve().parent
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--checkpoint',default='20261008');parser.add_argument('--expected-reviewed-count',type=int,default=30);args=parser.parse_args()
 if not re.fullmatch(r'\d{8}(?:-r\d+)?',args.checkpoint):raise SystemExit('Invalid immutable checkpoint name')
 scope=json.loads((P/'skku-final-current-scope-check.json').read_text())
 if not scope.get('currentCensusCompleted') or not scope.get('scopeStable'):
  raise SystemExit('Actual current whole census has not completed stably; no registration candidate.')
 if scope.get('knownCancelledStillPresent'):raise SystemExit('Published closed offerings remain; no candidate.')
 source=json.loads((P/'skku-final-current-educational-source.json').read_text())['records'];current={r['HAKSU_NO_BUNBAN']:r for r in source if r['JUKYONGHAKWI_GB']!='05'}
 assert len(current)==2782
 review=json.loads((P/'skku-reviewed-ordinary-draft-status.json').read_text());approved={r['offeringCode'] for r in review['reviewedOrdinary']};assert len(approved)==args.expected_reviewed_count and len(approved)>=30
 audit=json.loads((P/'skku-public-operating-plan-audit.json').read_text());proof={r['offeringCode']:r for r in audit['records']}
 clock=re.compile(r'([월화수목금토일])(?:\[[^\]]*\])?(\d{2}):(\d{2})[-~](\d{2}):(\d{2})')
 def clock_frames(value):
  return sorted((m[1],int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5])) for m in clock.finditer(value))
 for key in approved:
  evidence=proof[key];assert evidence['currentDetailIdentityConfirmed'] and evidence['detail']
  detail=evidence['detail'][0];source_row=current[key]
  assert detail['PER_NAME'].strip()==source_row['PER_NAME'].strip(), key+' current teacher conflict'
  assert clock_frames(source_row['GYOSI_NAME']) and clock_frames(source_row['GYOSI_NAME'])==clock_frames(detail.get('SUUP_YOIL_GYOSI','')), key+' current detail clock conflict'
 manifest={'universityId':'skku','semester':'2026-2','completionClaim':False,'wholeOperatingAuditFinished':False,'wholeCurrentDetailsFetched':audit['allCurrentDetailsFetched'],'registrationScope':'Entire currently published UG/cross-degree metadata; only individually reviewed actual dated meetings. Unreviewed offerings remain unscheduled/unrecognized without generated dates.','verifiedScheduledCourseCount':len(approved),'currentWholeCensusCheckedAt':scope['checkedAt'],'currentCensusCompleted':True,'currentCensusStable':True,'wholeCurrentCount':2782,'excludedGraduateOnly05':32,'campuses':[]}
 total=0;allcounts=collections.Counter()
 for campus in ['humanities','naturalScience','icampus']:
  data=json.loads((P/f'skku-{campus}-2026-2.ordinary-reviewed-draft.json').read_text());counts=collections.Counter()
  for c in data['courses']:
   key=c['courseCode']+'-'+c['section'];assert key in current;r=current[key]
   assert c['sourceSchedule']==r['GYOSI_NAME'];assert c['professor']==r['PER_NAME'];assert c['sourceDegreeCode']==r['JUKYONGHAKWI_GB']
   if c['scheduleStatus']=='scheduled':
    assert key in approved and proof[key]['currentDetailIdentityConfirmed'];assert c['schedules'];assert c['commonClosureDatesApplied'];assert c['operatingReviewBasis']
    assert all(m.get('date') for m in c['schedules']);c['researchOnly']=False
   else:assert not c['schedules']
   counts[c['scheduleStatus']]+=1;allcounts[c['scheduleStatus']]+=1;total+=1
  data.update({'researchOnly':False,'productionActivationAllowed':True,'completionClaim':False,'partialOperatingRegistration':True,'wholeOperatingAuditFinished':False,'wholeCurrentDetailsFetched':audit['allCurrentDetailsFetched'],'wholeCurrentCensusStable':True,'wholeCurrentCensusCheckedAt':scope['checkedAt'],'publicEducationalEvidenceCount':audit['count'],'registrationBoundaries':'Only explicitly reviewed actual dated meetings are active; all remaining operating evidence is unresolved or no printed fixed clock. No whole support completion claim.'})
  path=P/f'skku-{campus}-2026-2.partial-audited-{args.checkpoint}.json';body=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode();digest=hashlib.sha256(body).hexdigest()
  if path.exists() and path.read_bytes()!=body:raise SystemExit('Immutable registration filename already has different bytes; use a new audited checkpoint filename.')
  if not path.exists():path.write_bytes(body)
  manifest['campuses'].append({'campus':campus,'campusName':data['campusName'],'path':str(path),'sha256':digest,'courseCount':len(data['courses']),'scheduleCounts':dict(counts)})
 assert total==2782;assert allcounts['scheduled']==len(approved)
 manifest['counts']=dict(allcounts);manifest['notApprovedForDatedMeetingsCount']=2782-len(approved);manifest['knownIndividuallyBlockedCases']=review['explicitBlockedEducationalCases'];manifest['preparedAt']=datetime.datetime.now(datetime.timezone.utc).isoformat()
 path=P/f'skku-partial-audited-{args.checkpoint}-sha-manifest.json';body=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
 if not path.exists():path.write_bytes(body)
 print({'courseCount':total,'counts':dict(allcounts),'completionClaim':False})
