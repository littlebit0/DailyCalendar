from pathlib import Path
import hashlib,json,collections,re
R=Path('.');O=R/'work/university-research/resume-20261011/dgist'
asset=R/'assets/timetable/dgist-unknown-2026-2.json'; boundary=R/'work/university-research/resume-batch-20261010/remaining-source-boundaries/dgist.json'; planfile=R/'work/university-research/catalog-r/dgist-current-published-plans-educational.json'
d=json.loads(asset.read_text());held=[c for c in d['courses'] if not c.get('schedules')];old={x['sourceId']:x for x in json.loads(boundary.read_text())['held']};plans={(p['code'],p['section']):p for p in json.loads(planfile.read_text())};raw={}
for year in ['2020','2024','2014']:
 p=R/f'work/university-research/catalog-r/dgist2026-2-{year}-current-recheck-20261008.json';raw[year]={(x['SBJT_NO'],x['CLSS_NO']):x for x in json.loads(p.read_text())}
rows=[];planrows=[];variantscount=0
for c in held:
 key=(c['courseCode'],c['section']);previous=old[c['sourceId']]
 assert c['sourceSchedule']==previous['nativeSchedule']
 for v in c['sourceEducationalMetadata']['curriculumVariants']:
  assert v['fields']==raw[v['curriculum']][key];variantscount+=1
 p=plans.get(key,{});f=p.get('fields',{}); present=bool(f)
 if present:
  assert f['SBJT_NO']==key[0] and f['CLSS_NO']==key[1]
  assert f.get('INFO','').replace(' ','')==c['sourceSchedule'].replace(' ','')
  educational={k:f.get(k,'') for k in ['INFO','LSN_MTHD','LT_POLY','ETC','SCHETCHUL','ALL_CNTN']}
  planrows.append({'offering':'-'.join(key),'sourceFields':educational})
 reason=previous['sourceBoundary']
 if key==('HSS123','01'):reason='K-MOOC asynchronous preparation plus bi-weekly in-class discussions; exact alternating discussion dates not published'
 if key==('MSE302','01'):reason='On-site or online lectures; exact allocation and synchronous/asynchronous online mode not published'
 if key==('LS313a','01'):reason='Native plan explicitly warns experiments may exceed the two-hour clock; actual end/allocation remains unresolved under prior adjudication'
 if key==('RP303','01'):reason='Native plan says weekly basic research, with schedule to be discussed after semester starts; exact appointed dates/time not published'
 rows.append({'sourceId':c['sourceId'],'offering':'-'.join(key),'nativeSchedule':c['sourceSchedule'],'nativeCampus':c['campus'],'sourceBoundary':previous['sourceBoundary'],'preciseHoldReason':reason,'nativePlanAvailable':present,'newEligibleAppointment':False})
assert len(held)==373 and set(old)=={c['sourceId'] for c in held}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
receipt={'date':'2026-10-11','scope':'Process already-acquired373held DGIST offerings only; no source reacquisition or repeated SDK verification','wholeCatalog':len(d['courses']),'existingScheduled':sum(bool(c.get('schedules')) for c in d['courses']),'held':len(held),'boundaryCounts':dict(collections.Counter(r['sourceBoundary'] for r in rows)),'heldPublishedPlanResponses':len(planrows),'nativeCurriculumVariantsMatched':variantscount,'all373PriorBoundaryIdentityMatches':True,'eligibleMissingCandidateCount':0,'candidateCreated':False,'sourceFacts':'All held source clock/room strings are preserved. Semester dates alone do not turn research/internship allocation labels into actual weekly attendance. Existing current source metadata has no physical campus classification for these offerings. Do not invent campus from buildingcodes.','sourceHashes':{str(p):sha(p) for p in [asset,boundary,planfile]},'sourceReacquisition':False,'productChanged':False,'SDKTestsBuildInstall':False,'completionClaim':False,'impossibleClaim':False}
(O/'existing-held-source-receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n');(O/'all373-held-boundaries.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');(O/'nine-held-published-plans.json').write_text(json.dumps(planrows,ensure_ascii=False,indent=2)+'\n');print(json.dumps(receipt,ensure_ascii=False))
