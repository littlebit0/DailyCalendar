"""Published public special filters; anonymous normal protocol only."""
import json,time
from knu_collect_current_public import R,PublicClient,BASE,QUERY,FIELDS,public_data,dump
FILTERS=[('05-remote','rmtCrseYn'),('06-foreign-language','rprsnLctreLnggeSctcd'),('07-flipped','flplnCrseYn'),('08-national-remote','pstinNtnnvRmtCrseYn'),('09-dg-gb-remote','dgGbDstrcRmtCrseYn'),('10-su-evaluation','sugrdEvltnYn'),('11-practical','prctsExrmnYn'),('12-knu-future','knuFtrDesigYn'),('13-humanities-liberal','cltreHmntsCltreYn'),('14-sdg','sdgCltreYn'),('15-interactive','rltmCrseYn'),('16-rise','riseRmtCrseYn'),('17-mutual-recognition','coRcgnnSbjetYn')]
c=PublicClient()
pre=public_data(c,'/public/web/stddm/common/stddmCommonInfo/selectListYrsmtInfos',{'eventId':'EVE00251','mngtYn':'Y','dispGbn':'A','itttnCd':'1','isApi':'Y'})
assert any(r.get('year')=='2026' and r.get('smstrSctcd')==BASE['estblSmstrSctcd'] and r.get('prdYn')=='Y' and r.get('existYn')=='Y' for r in pre)
out=R/'knu-current-public-special-scopes';out.mkdir(exist_ok=True)
base={r['crseNo']:r for r in json.load(open(R/'knu-2026-2-current-public-owner-course-rows.json'))}
index=[];added={}
for label,key in FILTERS:
 p=out/(label+'.json')
 if p.exists(): rows=json.load(open(p))
 else:
  rows=[{k:r.get(k) for k in FIELDS if k in r} for r in public_data(c,QUERY,{**BASE,key:'Y'})]
  dump(p,rows);time.sleep(.3)
 new=[r for r in rows if r['crseNo'] not in base]
 for r in new: added.setdefault(r['crseNo'],[]).append({'source':label,'row':r})
 index.append({'label':label,'condition':{key:'Y'},'count':len(rows),'newIdentityCount':len(new)})
 print(label,len(rows),'new',len(new),flush=True)
dump(R/'knu-current-public-special-scope-index.json',index)
dump(R/'knu-current-public-special-new-identities.json',added)
print('unique new identities',len(added),flush=True)
