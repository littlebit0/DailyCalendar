from skku_public import Public,P
import json,time
p=Public('KO',prefix='skku-ko-')
for code in ['MED3096','MED3148','MED3173']:
 source=json.loads((P/('skku-ko-medical-files-'+code+'.json')).read_text())['dsMyFile2'][0]
 params={'FILE_ID':source['BIZ_PLN_FILE_ID'],'_TRANSACTION_ID':'selectDsFile2','_FIRST_OUT_DS_NM':'dsFile2','_ALL_OUT_DS_NM':'dsFile2=dsFile2','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
 data=p.post('/E_NAttachFile/selectAttachFiles',params,'medical-attachments-'+code)
 print(code,json.dumps(data,ensure_ascii=False),flush=True);time.sleep(.15)
