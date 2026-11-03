import json,pathlib,collections,re
P=pathlib.Path('work/all-university-completion-20261012');ap='work/full-timetable-audit-20261012/current-coverage-audit.json';audit=json.load(open(ap));old={r['university']:r for r in audit['schools']};cat=json.load(open('assets/timetable/catalog.json'));schools=collections.defaultdict(list)
for file in cat:
 d=json.load(open(file));schools[d['universityId']].append((file,d))
rows=[]
for slug,sets in sorted(schools.items()):
 a=old[slug];cs=[c for _,d in sets for c in d.get('courses',[])];bad=[c for c in cs if c.get('scheduleStatus')=='unrecognized' and not c.get('schedules')];fixed=[c for c in bad if str(c.get('sourceSchedule') or '').strip()];normal=[c for c in cs if c.get('scheduleStatus')=='unscheduled'];evidence=[];full=[];partial=[]
 for file,d in sets:
  for key in ['coverage','sourceScope','sourceNotice','wholeSchoolCourseCoverageComplete']:
   val=d.get(key)
   if val is not None:
    evidence.append({'file':file,'field':key,'value':val})
    if val is False or (isinstance(val,str) and re.search('whole.*not established|not.*whole|일부|전체.*뜻하지',val,re.I)):partial.append(file)
    if isinstance(val,str) and re.search('All27nativecollegefilters|Current native all-course search|Current whole public undergraduate offering lookup|Whole current public undergraduate offerings|Official whole registration book',val,re.I):full.append(file)
 if a.get('confirmedScopeLimitation'):
  evidence.append({'file':ap,'field':'confirmedScopeLimitation','value':a['confirmedScopeLimitation'],'snapshotCaution':'Historical source boundary; latest asset counts below supersede old counts.'})
  if slug not in {'jbnu'}:partial.append(ap)
 if slug=='nsu':partial.append('work/full-timetable-audit-20261012/nsu-emergency-current-root/B-NSU-PAUSE-HANDOFF-20261012.md')
 if slug=='inje':partial.append('work/full-timetable-audit-20261012/inje-full-a/PAUSE_HANDOFF.md')
 if slug in {'cbnu','gknu','chosun','donga'}:partial.append('work/full-timetable-audit-20261012/four-school-full-a/PAUSE_HANDOFF.md')
 reasons=[]
 if partial:reasons.append({'kind':'partialSourceScope','evidenceFiles':sorted(set(partial))})
 if bad:reasons.append({'kind':'unresolvedScheduleOrOperation','currentRows':len(bad),'withLiteralSourceSchedule':len(fixed),'note':'Current unrecognized status is distinct from normal unscheduled. Not labelled clock failure without source-specific proof.','examples':[{k:c.get(k) for k in ['sourceId','courseCode','section','courseName','sourceSchedule','scheduleStatus']} for c in (fixed or bad)[:3]]})
 fullAcquired=bool(full) and len(full)==len(sets)
 if not fullAcquired:reasons.append({'kind':'wholeSourceScopeReviewIncomplete','note':'No explicit current whole-university acquisition evidence was confirmed in the inspected local asset fields. This means review incomplete, not collection impossible. Historical wholeOperatingVerified=false alone was not used.'})
 recommend=bool(reasons)
 rows.append({'university':slug,'name':a['name'],'recommendTemporaryUnsupported':recommend,'scopeCategory':'partial' if partial else ('wholeSourceAcquired' if fullAcquired else 'wholeScopeNotConfirmedInThisAudit'),'reasons':reasons,'currentCourses':len(cs),'currentDatasets':[f for f,_ in sets],'currentUnrecognized':len(bad),'normalUnscheduled':len(normal),'normalUntimedIsNotFailure':True,'wholeSourceEvidence':evidence,'previousAuditCourses':a['courses'],'currentCountsChanged':a['courses']!=len(cs),'historicalEvidenceLocators':a.get('historicalEvidence',[]),'functionalVerificationClaim':False})
result={'source':'Local cached assets, prior coverage audit and handoffs only; no new network research.','decisionPolicy':'User requested temporary unsupported also when whole scope confirmation is not complete. Normal unscheduled/async records are not a disable reason. Explicit whole-source acquisition and current no-unrecognized are necessary for keep recommendation; product/application acceptance not claimed. Root should apply existing separately verified whole-scope evidence before final decision.','completionClaim':False,'rows':rows,'temporaryUnsupportedSlugs':[r['university'] for r in rows if r['recommendTemporaryUnsupported']],'keepSlugs':[r['university'] for r in rows if not r['recommendTemporaryUnsupported']]}
(P/'provisional-timetable-support-recommendation-b.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
(P/'PROVISIONAL-TIMETABLE-SUPPORT-B.md').write_text('# Local provisional support recommendation\n\nNo network / product / SDK work. Latest171catalog assets and96universities read.\n\n'+ '\n'.join(f"- {r['name']} ({r['university']}): "+('temporary unsupported: '+', '.join(x['kind'] for x in r['reasons']) if r['recommendTemporaryUnsupported'] else 'keep candidate; explicit whole source and no unrecognized') for r in rows)+'\n\nThis limited local field audit does not invalidate stronger whole-scope proof already held by root. Review-incomplete means not verified here, never university impossible. Before final application, root may supplement actual whole source packets for native API schools and baseline SMU. Do not use the unverified keep list as device acceptance.\n')
print('temporary',len(result['temporaryUnsupportedSlugs']),'keep',result['keepSlugs']);print('countChanged',[(r['university'],r['previousAuditCourses'],r['currentCourses']) for r in rows if r['currentCountsChanged']])
