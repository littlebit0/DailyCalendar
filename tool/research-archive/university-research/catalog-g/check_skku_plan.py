from skku_public import Public,P
import json
p=Public()
params={'YEAR':'2026','TERM':'20','HAKSU_NO':'MED3148','BUNBAN':'41'}
for action,out in [('select01','dsSelect01'),('select02','dsSelect02')]:
 a=dict(params,_TRANSACTION_ID=action,_FIRST_OUT_DS_NM=out,_ALL_OUT_DS_NM=out+'='+out,_MENU_ID='EXT_SCHEDULE',_PGM_ID='NHSSU030840M')
 data=p.post('/E_NHSSU900011P/'+action,a,'plan-MED3148-41-'+action)
 print(action,{k:len(v)for k,v in data.items()})
 print(json.dumps(data,ensure_ascii=False)[:1800])

a={'GAESUL_YEAR':'2026','GAESUL_TERM':'20','HAKSU_NO':'MED3148','BUNBAN':'41','_TRANSACTION_ID':'selectMain0','_FIRST_OUT_DS_NM':'dsInfoTab01','_ALL_OUT_DS_NM':'dsInfoTab01=dsInfoTab01','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
data=p.post('/E_NHSSU900011P/selectMain0',a,'plan-MED3148-41-detail',save=False)
safe=[{k:r.get(k)for k in ['GAESUL_YEAR','GAESUL_TERM','HAKSU_NO','BUNBAN','SUUP_YOIL_GYOSI','SUUP_GANGUISIL','ISU_NM','BIGO','CLASS_INFO']} for r in data.get('dsInfoTab01',[])]
(P/'skku-plan-MED3148-41-timing.json').write_text(json.dumps(safe,ensure_ascii=False,indent=2))
print('selectMain0 timing',json.dumps(safe,ensure_ascii=False))
