import json,pathlib,re,copy,collections
p=pathlib.Path('work/full-timetable-audit-20261012/limited-c-public-sources');a=json.load(open(p/'eulji-three-department-schema2-candidate.json'));b=json.load(open(p/'eulji-two-pdf-source-candidate.json'));old=json.load(open('assets/timetable/eulji-seongnam-2026-2.json'));held=[];ready=[];merged=[];blocked=[];cross=[];scopeExcluded=[]
def n(s):return re.sub(r'\s+','',s or'')
def slot(c):return tuple(sorted((s['weekday'],s['startMinute'],s['endMinute'],n(s.get('classroom')))for s in c['schedules']))
def strong(c):return(n(c['courseName']),n(c['professor']),slot(c),c.get('period',{}).get('startDate'),c.get('period',{}).get('endDate'))
for c in a['courses']+b['courses']:
 if c.get('sourceGrade')=='대학원':
  scopeExcluded.append({'reason':'Official XLSX source grade explicitly 대학원; outside undergraduate scope','candidate':c});continue
 if c['scheduleStatus']!='scheduled':held.append(c);continue
 ready.append(copy.deepcopy(c))
# Native code+section is authoritative. For code-less same-room, same-professor simultaneous blocks, retain a locator-based first identity and all independently published source locators; never title-only joins.
for c in ready:
 match=[]
 for i,o in enumerate(merged):
  coded=c['courseCode']and o['courseCode']and(c['courseCode'],c['section'])==(o['courseCode'],o['section'])
  physical=(not c['courseCode']and not o['courseCode']and c['professor']and o['professor']and all(s.get('classroom')for s in c['schedules'])and strong(c)==strong(o)and(not c['section']or not o['section']or c['section']==o['section']))
  if coded or physical:match.append((i,'native_code_section'if coded else'exact_title_professor_room_weekday_clock_term'))
 if len(match)==1:
  i,proof=match[0];o=merged[i];o.setdefault('sourceLocators',[o.pop('sourceLocator')]).append(c['sourceLocator']);o.setdefault('sourceIds',[o['sourceId']]).append(c['sourceId']);o.setdefault('additionalSourceUrls',[]).append(c['sourceUrl']);o.setdefault('sourceContexts',[]).append({k:c[k]for k in['sourceGrade','sourceClass']})
  for d in c['departments']:
   if d not in o['departments']:o['departments'].append(d)
   for field in ['departmentClassifications','departmentRemarks']:o[field][d]=c[field][d]
  cross.append({'retainedSourceId':o['sourceId'],'addedSourceId':c['sourceId'],'proof':proof})
 else:merged.append(c)
result=copy.deepcopy(old);result['schemaVersion']=2;result['additionalSourceUrls']=list(dict.fromkeys(c['sourceUrl']for c in merged));result['mergeStatus']='integration candidate; originals retained exactly; unresolved source rows held'
for c in merged:
 # Existing exchange source lacks professor. Avoid guessing section identity, and do not introduce another card when same native title/time/room may refer to an existing course.
 possible=[o for o in old['courses']if n(c['courseName'])==n(o['courseName'])and slot(c)==slot(o)and(not c['section']or not o['section']or c['section']==o['section'])]
 if possible:
  blocked.append({'candidateSourceId':c['sourceId'],'existingSourceIds':[o['sourceId']for o in possible],'reason':'Exact title+weekday/time+room overlap; old source professor absent/native codes absent. Existing preserved; candidate excluded pending section identity proof.','candidate':c})
 else:result['courses'].append(c)
result['sourceRowCount']=len(result['courses']);result['completionClaim']=False
periodProof=json.load(open(p/'eulji-period-source-proof.json')) if(p/'eulji-period-source-proof.json').exists()else None
if periodProof:
 result['periodEvidence']=periodProof
 oldIds={c['sourceId']for c in old['courses']}
 for c in result['courses']:
  if c['sourceId']not in oldIds:c['periodEvidence']=periodProof
(p/'eulji-seongnam-integration-candidate.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
ledger={'final':True,'completionClaim':False,'existingSeongnamRetained':len(old['courses']),'existingUijeongbuRetained':7,'rawXlsxSourceInstances':len(a['courses']),'rawPdfSourceInstances':len(b['courses']),'scheduledReadyBeforeConsolidation':len(ready),'consolidatedNewReady':len(merged),'newInserted':len(result['courses'])-len(old['courses']),'integrationCount':len(result['courses']),'identityJoins':cross,'possibleExistingOverlapsHeld':blocked,'unrecognizedSourceRows':held,'scopeExcluded':scopeExcluded,'graduateExcludedCount':len(scopeExcluded),'sourceRules':['No native course code invented. Code-less identity uses original locator.','No title-only joins. Same-professor/same-room/same-weekday-clock/same-term exact physical joins only.','All existing60+7 timed courses untouched.','Clinical, placement, partial-week, nightclock, professor-integrated ambiguous texts held; no inferred date/clock.'],'sourceReadiness':'Research source integration complete for safely readable public XLSX/PDF subset; incomplete university-wide catalogue.'}
if periodProof:ledger['periodEvidence']=periodProof
(p/'eulji-integration-ledger.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2));print({k:ledger[k]for k in['scheduledReadyBeforeConsolidation','consolidatedNewReady','newInserted','integrationCount']});print('crossjoins',len(cross),'oldOverlapHeld',len(blocked),'unrecognized',len(held))
