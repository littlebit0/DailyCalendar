"""Current public UI organization filters, no authentication or protection bypass."""
import json,time,pathlib
from knu_public_sources import PublicClient
R=pathlib.Path(__file__).parent
ORG='/public/web/stddm/lsspr/syllabus/lectPlnInqr/selectItttnCdListLectPlnInqr'
QUERY='/public/web/stddm/lsspr/syllabus/lectPlnInqr/selectListLectPlnInqr'
YEAR='2026';SEM='CMBS001400002'
BASE={'estblYear':YEAR,'estblSmstrSctcd':SEM,'lctreLnggeSctcd':'ko','gubun':'01','isApi':'Y'}
FIELDS=['lctreMthodNm','lctrmInfo','lctreLnggeSctcd','crseNo','estblUnivNm','estblDprtnNm','estblYear','estblDprtnCd','estblSmstrSctnm','estblSmstrSctcd','estblGrade','sbjetSctnm','sbjetNm','sbjetDvnno','sbjetCd','pckgeRqstPssblYn','pckgeRqstCnt','rmrk','appcrCnt','attlcPrscpCnt','lssnsTimeInfo','lssnsRealTimeInfo','prctsTime','doPlan','thryTime','totalPrfssNm','mngetEstblYn','crdit','expniSllbsYn','bldngSn','bldngCd','bldngNm','lssnsLcttmUntcd','sbjetSctcd2','rmnmCd','grdscCmmnnSbjetYn']

def dump(path,x): path.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
def public_data(c,url,s):
 x=c.post(url,s)
 if x.get('success') is not True: raise RuntimeError('Public query did not succeed')
 if not isinstance(x.get('data'),list): raise RuntimeError('Public response schema differs')
 return x['data']
def main():
 c=PublicClient()
 pre=public_data(c,'/public/web/stddm/common/stddmCommonInfo/selectListYrsmtInfos',{'eventId':'EVE00251','mngtYn':'Y','dispGbn':'A','itttnCd':'1','isApi':'Y'})
 current=[r for r in pre if r.get('year')==YEAR and r.get('smstrSctcd')==SEM]
 if not current or any(r.get('prdYn')!='Y' or r.get('existYn')!='Y' for r in current): raise RuntimeError('Normal public year/term not available')
 dump(R/'knu-current-public-period-preflight.json',[{k:r.get(k) for k in ['year','smstrSctcd','beginDt','endDt','prdYn','existYn']} for r in current])
 colleges=json.load(open(R/'knu-current-public-colleges.json'))
 orgs=[]
 for col in colleges:
  s={**BASE,'gubun':'03','code':col['code'],'name':col['name']}
  ds=public_data(c,ORG,s)
  for d in ds:
   if not d.get('code'): raise RuntimeError('Organization without public code')
   orgs.append({'collegeCode':col['code'],'collegeName':col['name'],'code':d['code'],'name':d['name']})
  time.sleep(.15)
 dump(R/'knu-current-public-all-department-filters.json',orgs)
 unique_depts={o['code']:o for o in orgs}
 scopes=[('dept-'+code,{'estblDprtnCd':code}) for code in unique_depts]
 # All conditions are literally documented by public UI searchParamInput.
 scopes += [('liberal',{'sbjetRelmCd':'01'}),('military',{'sbjetRelmCd':'STCU001000021'}),('teaching',{'sbjetSctcd':'STCU000800007'}),('research-industry',{'estblDprtnCd':'300H'})]
 outdir=R/'knu-current-public-scopes';outdir.mkdir(exist_ok=True)
 index=[];union={};aliases={}
 for i,(label,filt) in enumerate(scopes):
  p=outdir/(label+'.json')
  if p.exists(): rows=json.load(open(p))
  else:
   raw=public_data(c,QUERY,{**BASE,**filt})
   rows=[{k:r.get(k) for k in FIELDS if k in r} for r in raw]
   dump(p,rows);time.sleep(.2)
  index.append({'filterLabel':label,'filter':filt,'rowCount':len(rows)})
  for row in rows:
   key=row.get('crseNo')
   if not key: raise RuntimeError('Course without identity')
   aliases.setdefault(key,[]).append(label)
   if key not in union: union[key]=row
   elif row!=union[key]:
    # Keep variants; do not silently resolve different target departments.
    aliases[key].append({'variant':row})
  if (i+1)%25==0: print('scopes',i+1,'of',len(scopes),'uniqueCourses',len(union),flush=True)
 dump(R/'knu-current-public-scope-index.json',index)
 dump(R/'knu-2026-2-current-public-course-rows.json',list(union.values()))
 dump(R/'knu-current-public-aliases.json',aliases)
 print('completeScopes',len(scopes),'allDepartmentAliases',len(orgs),'distinctDepartmentCodes',len(unique_depts),'uniqueCourses',len(union),flush=True)
if __name__=='__main__':main()
