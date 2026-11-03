# -*- coding: utf-8 -*-
"""Discovery only. Tokens are not semantic approval or an operating exception proof."""
import json,re
from pathlib import Path
R=Path(__file__).resolve().parent
WORD=re.compile(r'휴강|휴업|보강|집중\s*수업|집중\s*이수|비대면|실시간|비실시간|온라인|원격|VOD|녹화|현장\s*실습|임상\s*실습|인턴십|수업\s*없|강의\s*없|출석\s*대체|견학|답사|추석|한글날|개천절|Chuseok|make[- ]?up|no\s*class|field\s*trip|reading\s*week',re.I)
DATE=re.compile(r'(?<!\d)(?:(?:20\d{2})[./-][ \t]*)?(?:0?[1-9]|1[0-2])[./-][ \t]*(?:0?[1-9]|[12]\d|3[01])(?!\d)|\d{1,2}\s*월\s*\d{1,2}\s*일|September|October|November|December',re.I)
EDU_FIELDS={'LSN_OPER_MTHD','LSN_OPER_MTHD_UNTACT','TLSN_ANNM','LSN_RULE','ATTEND_RULE','PRE_LRN_CN','LSN_SMRY','SBJT_SMRY','REF_CTNT','MAJ_LRN_CTNT','ETC_CTNT','PRJT'}
contexts=[];counts={'acquiredFiles':0,'published':0,'unpublished':0,'operatingTokenContexts':0,'possibleDateContexts':0}
for f in sorted((R/'cnu-current-education').glob('*.json')):
 j=json.loads(f.read_text());counts['acquiredFiles']+=1;counts['published' if j['planPresent'] else 'unpublished']+=1
 for source,rows in [('header',j.get('header',[])),('week',j.get('weeks',[]))]:
  for i,row in enumerate(rows):
   for field,value in row.items():
    if field not in EDU_FIELDS or not isinstance(value,str) or not value.strip():continue
    sig=[]
    if WORD.search(value):sig.append('operatingTokens');counts['operatingTokenContexts']+=1
    # Course credits, attendance fractions and textbook references aren't date proofs.
    if field not in ('ATTEND_RULE','PRE_LRN_CN') and DATE.search(value):sig.append('possibleDate');counts['possibleDateContexts']+=1
    if sig:contexts.append({'courseId':j['courseId'],'section':source,'row':i,'week':row.get('WKORD'),'field':field,'signals':sig,'educationText':value,'reviewStatus':'pendingActualContextReview'})
(R/'cnu-current-operating-discovery.json').write_text(json.dumps(contexts,ensure_ascii=False,indent=2))
(R/'cnu-current-operating-discovery-audit.json').write_text(json.dumps({'counts':counts,'semanticReviewComplete':False,'fullCollectionComplete':False,'notes':['CONC_SBJT retains original related-subject text; never treated as intensive flag','Token discovery can include educational topics/generic policies/stale prior-year text; no automatic schedule approval or cancellation','Dates must agree with current year and per-course plan; week ordinal alone is not a printed date']},ensure_ascii=False,indent=2))
print(json.dumps(counts))
