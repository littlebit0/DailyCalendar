from skku_public import Public,P
import json,time
p=Public('KO',prefix='skku-ko-');output=[]
for code in ['PHR3015','PHR3016','MED3096','MED3148','MED3173']:
 params={'GAESUL_YEAR':'2026','GAESUL_TERM':'20','HAKSU_NO':code,'BUNBAN':'41','_TRANSACTION_ID':'selectMain0','_FIRST_OUT_DS_NM':'dsInfoTab01','_ALL_OUT_DS_NM':'dsInfoTab01=dsInfoTab01','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
 data=p.post('/E_NHSSU900011P/selectMain0',params,'plan-clock-'+code,save=False)
 rows=[{k:r.get(k)for k in ['GAESUL_YEAR','GAESUL_TERM','HAKSU_NO','BUNBAN','SUUP_YOIL_GYOSI','SUUP_GANGUISIL','ISU_NM','BIGO','CLASS_INFO','HAKJUM_TIME']} for r in data.get('dsInfoTab01',[])]
 output.extend(rows);print(code,json.dumps(rows,ensure_ascii=False),flush=True);time.sleep(.15)
(P/'skku-ko-detailed-clock5.json').write_text(json.dumps(output,ensure_ascii=False,indent=2))
