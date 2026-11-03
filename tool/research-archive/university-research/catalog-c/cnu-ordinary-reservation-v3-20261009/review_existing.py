"""Research-only triage of existing current educational plans, no requests."""
import json,re,hashlib,collections
from pathlib import Path
OUT=Path(__file__).resolve().parent
PRIOR=OUT.parent/'cnu-ordinary-reservation-v2-20261008'
CAT=OUT.parents[1]/'catalog-f'
base=json.loads((PRIOR/'cnu-unknown-2026-2.ordinary-reservation-research-v2-20261008.json').read_text())
held={c['sourceEducation']['courseId']:c for c in base['courses'] if not c['schedules']}
screen=json.loads((PRIOR/'source-semantic-screen.json').read_text())
# This first pass requires no prior semantic barrier except absent foreground phrase.
pool=[r for r in screen['decisions'] if r['courseId'] in held and r['screenReasons']==['ExplicitOrdinaryForegroundNeedsReview']]
# These conservative source-body signals are triage, not permanent ineligibility.
patterns={
'CurrentRemoteOrModeSemanticReview':r'온라인|비대면|원격|녹화|동영상|블렌디드|블랜디드|하이브리드|zoom|blended|remote|online|asynchronous|recorded|MOOC',
'IndividualLessonOrPlacementSemanticReview':r'1\s*[:대]\s*1|일대일|개별적\s*운영|조별수업|개인레슨|개인\s*레슨|개별\s*수업|개인\s*수업|개인\s*지도|개별\s*지도|one.to.one|individual\s*lesson|인텐시브|레슨',
'FieldOrAlternateOperationSemanticReview':r'현장|견학|탐방|외부|교외|봉사|인턴|임상|비교과|실습기관|답사|집중|격주|별도|자율|학교방문|미술관\s*관람|시수[^\n]{0,20}모아서|연구\s*참여|교수\s*연구실|지도교수[^\n]{0,40}연구|지역사회[^\n]{0,50}프로젝트[^\n]{0,20}참여|플립러닝|field\s*trip|placement|intensive|biweekly',
'KnownCancellationMakeupOrExtraClockReview':r'휴강|보강|수업\s*없|대체\s*수업|no\s*class|cancel|\d{1,2}:\d{2}|(?<!\d)\d{1,2}\s*시(?!간)',
}
compiled={k:re.compile(v,re.I) for k,v in patterns.items()}
rows=[]
for d in pool:
 cid=d['courseId'];c=held[cid];path=PRIOR/'current-education'/f'{cid}.json'
 if not path.exists():path=CAT/'cnu-current-education'/f'{cid}.json'
 p=json.loads(path.read_text());reasons=[];signals=[]
 for h in p['header']:
  if h.get('OPEN_SHTM_CD_NM')!='2학기':reasons.append('PlanSemesterConflict')
  if h.get('TLSN_ANNM') and re.sub(r'\s','',h['TLSN_ANNM'])!=re.sub(r'\s','',c['sourceSchedule']):reasons.append('PlanNativeClockRoomConflict')
  # Main and alternative operating fields determine delivery; broad synopsis topics do not.
  for field in ['LSN_OPER_MTHD','LSN_OPER_MTHD_UNTACT','LSN_RULE','ATTEND_RULE']:
   text=str(h.get(field) or '')
   for reason,pat in compiled.items():
    if pat.search(text):signals.append({'field':field,'text':text,'reason':reason});reasons.append(reason)
 for w in p['weeks']:
  for field in ['MAJ_LRN_CTNT','ETC_CTNT','PRJT']:
   text=str(w.get(field) or '')
   for reason,pat in compiled.items():
    if pat.search(text):signals.append({'week':w.get('WKORD'),'field':field,'text':text,'reason':reason});reasons.append(reason)
 slots=c['sourceEducation']['actualDisplayedClocks']
 if not slots or any(not s['location'] or not (0<=s['startMinute']<s['endMinute']<=1440) for s in slots):reasons.append('LiteralClockRoomInvalid')
 rows.append({'courseId':cid,'sourceId':c['sourceId'],'courseName':c['courseName'],'sourcePlanFile':str(path),'sourcePlanSHA256':hashlib.sha256(path.read_bytes()).hexdigest(),'sourceResponseSHA256':p['sourceResponseSHA256'],'sourceVerifiedOn':p.get('verifiedOn'),'nativeClockRows':slots,'mainOperatingStatements':[h.get('LSN_OPER_MTHD','') for h in p['header']],'reasons':sorted(set(reasons)),'sourceSignals':signals,'preliminaryOrdinary':not reasons})
a={'researchOnly':True,'completionClaim':False,'productEdited':False,'SDKUsed':False,'noNetworkUsed':True,'priorUnknownWhole':3887,'priorUnknownScheduled':1427,'priorDaedeok1Unchanged':True,'held2460':2460,'singleAbsentForegroundPhrasePool':len(pool),'preliminaryOrdinary':sum(r['preliminaryOrdinary'] for r in rows),'triageOnlyReviewPending':True,'reasonCounts':dict(collections.Counter(q for r in rows for q in r['reasons'])),'decisions':rows}
(OUT/'existing-source-semantic-triage.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n')
print({k:v for k,v in a.items() if k not in ['decisions']})
