"""Normal public weekly syllabus, pedagogical fields only; anonymous cookies memory-only."""
import json,time,concurrent.futures
from knu_public_sources import PublicClient,ROOT as R
OUT=R/'knu-current-public-weekly-plans';OUT.mkdir(exist_ok=True)
END='/public/web/stddm/lsspr/syllabus/lectPlnInputDtl/selectListLectPlnInputDtlWekCntns'
FIELDS=['estblYear','estblSmstrSctcd','sbjetCd','sbjetDvnno','lctreLnggeSctcd','weekSn','lssnsGoalLrnngCntns','bfrfaLrnngCntns','lssnsMethdMediaCntns','taskRsrchQstnCntns','rmrk']
def worker(rows):
 c=PublicClient();success=0;errors=[]
 for i,row in enumerate(rows):
  ident=row['crseNo'];path=OUT/(ident+'.json')
  if path.exists():success+=1;continue
  search={k:row[k] for k in ['estblYear','estblSmstrSctcd','sbjetCd','sbjetDvnno','estblDprtnCd','doPlan']}
  search.update({'lctreLnggeSctcd':'STCU001400002' if row.get('doPlan')=='Eng' else 'STCU001400001','readOnlyYn':'Y','isApi':'Y'})
  try:
   x=c.post(END,search)
   if x.get('success') is not True or not isinstance(x.get('data'),list):raise ValueError('Unexpected public weekly schema')
   data=[{k:r.get(k) for k in FIELDS if k in r} for r in x['data']]
   path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');success+=1
  except Exception as e:errors.append({'identity':ident,'exceptionType':type(e).__name__})
  time.sleep(.4)
  if (i+1)%200==0:print('weekly worker',i+1,'of',len(rows),'successful',success,'errors',len(errors),flush=True)
 return {'successful':success,'errors':errors}
if __name__=='__main__':
 rows=json.load(open(R/'knu-2026-2-candidate-undergraduate-course-rows.json'))
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(worker,[rows[::2],rows[1::2]]))
 (R/'knu-weekly-collection-audit.json').write_text(json.dumps({'expectedCandidates':len(rows),'results':results,'completionClaim':False},ensure_ascii=False,indent=2)+'\n')
 print('weekly finished',sum(r['successful'] for r in results),'failures',sum(len(r['errors']) for r in results),flush=True)
