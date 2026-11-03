"""No unavailable-school inference. Acquisition, reviewed evidence gaps and pending reviews separate."""
import json,collections
from pathlib import Path
R=Path(__file__).resolve().parent
cat=json.loads((R/'cnu-current-catalog-education.json').read_text());review={}
review_files=['cnu-reviewed-operation-cases-20261008.json','cnu-reviewed-week-exceptions-20261008.json','cnu-reviewed-field-contexts-20261008.json','cnu-reviewed-dated-conflicts-20261008.json','cnu-reviewed-current-clinical4-20261008.json','cnu-reviewed-intensive-contexts-20261008.json']
for name in review_files:
 for row in json.loads((R/name).read_text())['reviews']:review.setdefault(row['courseId'],[]).append({'file':name,'kind':row.get('kind','currentClinicalOperatingDatesUnresolved')})
for row in json.loads((R/'cnu-two-dated-chinese-proofs-20261008.json').read_text()):review.setdefault(row['courseId'],[]).append({'file':'cnu-two-dated-chinese-proofs-20261008.json','kind':'completePrintedDatesWithMakeupRoomUnresolved'})
verified={'1001-7041-00','1151-2003-01','1138-3006-00'}
for cid in verified:review[cid]=[{'file':'cnu-three-dated-dart-verification.json','kind':'completePrintedDatesAppReadRestorePassed'}]
statuses=[];counts=collections.Counter()
for c in cat:
 cid=c['COURSE_NO'];f=R/'cnu-current-education'/f'{cid}.json';j=json.loads(f.read_text()) if f.exists() else None
 if str(c['CLOSE_YN'])=='1':status='currentClosed'
 elif not j:status='publicEducationNotYetAcquired'
 elif not j['planPresent']:status='currentPublicPlanAbsent'
 elif cid in verified:status='specificActualDatedProofPassed'
 elif cid in review:status='observedContextReviewedActualGatePending'
 else:status='wholeSemanticReviewPending'
 counts[status]+=1;statuses.append({'courseId':cid,'status':status,'contextEvidence':review.get(cid,[]),'sourceResponseSHA256':j.get('sourceResponseSHA256') if j else None,'unresolvedClockOrDateNeverInvented':True})
a=json.loads((R/'cnu-current-education-collection-audit.json').read_text())
(R/'cnu-current-review-status-index.json').write_text(json.dumps({'rows':statuses,'counts':dict(counts),'observedReviewedCourseIds':len(review),'wholeCollectionComplete':a['finished'],'wholeSemanticReviewComplete':False,'wholeSupportComplete':False,'productionChanged':False},ensure_ascii=False,indent=2));print(dict(counts),'observed reviewed ids',len(review))
