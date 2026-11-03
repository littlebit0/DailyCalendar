"""Read only documented public syllabus overview; never collect teacher contacts."""
import json,pathlib,time,concurrent.futures
from knu_public_sources import PublicClient
R=pathlib.Path(__file__).parent;OUT=R/'knu-current-public-plans';OUT.mkdir(exist_ok=True)
END='/public/web/stddm/lsspr/syllabus/lectPlnInputDtl/selectListLectPlnInputDtlPub'
FIELDS=['crseNo','estblYear','estblSmstrSctcd','sbjetCd','sbjetDvnno','sbjetNm','estblDprtnCd','estblDprtnNm','lctrePrdInfo','lssnsTimeInfo','lctrmInfo','rmrk','attlcRefMtterCntns','lssnsMethdMediaCntns','smmryPrpsCntns','lssnsGoalLrnngCntns','bfrfaLrnngCntns','doPlan','sllbsTpnm','sllbsCnt','thryPrctsTimeInfo','totalLssnsTimeInfo','troblSpporCntns','taskRsrchQstnCntns','taskEvltnMethdCntns','lctreGoalCntns','lctreMnblCntns']
def worker(rows):
 c=PublicClient();success=0;errors=[]
 for i,row in enumerate(rows):
  ident=row['crseNo'];path=OUT/(ident+'.json')
  if path.exists():success+=1;continue
  search={k:row[k] for k in ['estblYear','estblSmstrSctcd','sbjetCd','sbjetDvnno','estblDprtnCd','doPlan']}
  search.update({'lctreLnggeSctcd':'STCU001400002' if row.get('doPlan')=='Eng' else 'STCU001400001','readOnlyYn':'Y','isApi':'Y'})
  try:
   x=c.post(END,search)
   if x.get('success') is not True or not isinstance(x.get('data'),dict):raise ValueError('Unexpected public syllabus schema')
   d=x['data'];sel={k:d.get(k) for k in FIELDS}
   path.write_text(json.dumps(sel,ensure_ascii=False,indent=2)+'\n');success+=1
  except Exception as e:errors.append({'identity':ident,'exceptionType':type(e).__name__})
  time.sleep(.4)
  if (i+1)%200==0:print('worker progress',i+1,'of',len(rows),'successful',success,'failures',len(errors),flush=True)
 return {'successful':success,'errors':errors}
if __name__=='__main__':
 allrows=json.load(open(R/'knu-2026-2-current-public-course-rows.json'))
 # Explicit official exclusion; retain their source raw separately, not fake UG.
 rows=[x for x in allrows if '교육대학원 개설 교직과목임' not in (x.get('rmrk') or '')]
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(worker,[rows[::2],rows[1::2]]))
 (R/'knu-public-plan-collection-audit.json').write_text(json.dumps({'expectedUndergraduateCourses':len(rows),'results':results,'contactsSaved':False,'completionClaim':False},ensure_ascii=False,indent=2)+'\n')
 print('finished',sum(x['successful'] for x in results),'failures',sum(len(x['errors']) for x in results),flush=True)
