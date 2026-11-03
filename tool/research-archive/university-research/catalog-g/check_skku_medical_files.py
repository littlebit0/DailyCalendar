from skku_public import Public,P
import json,time
p=Public('KO',prefix='skku-ko-')
for code in ['MED3096','MED3148','MED3173']:
 params={'GAESUL_YEAR':'2026','GAESUL_TERM':'20','HAKSU_NO':code,'BUNBAN':'41','_TRANSACTION_ID':'selectFile2','_FIRST_OUT_DS_NM':'dsMyFile2','_ALL_OUT_DS_NM':'dsMyFile2=dsMyFile2','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
 data=p.post('/E_NHSSU900011P/selectFile2',params,'medical-files-'+code)
 print(code,json.dumps(data,ensure_ascii=False),flush=True);time.sleep(.15)
