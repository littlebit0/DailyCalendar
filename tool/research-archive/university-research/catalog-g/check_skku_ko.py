from skku_public import Public,P
import json,time
p=Public('KO');audit=json.loads((P/'skku-all-audit.json').read_text());allrows=json.loads((P/'skku-all-2026-2.json').read_text())['records'];byid={r['HAKSU_NO_BUNBAN']:r for r in allrows};records=[]
for id in audit['incompleteClockIds']:
 r=byid[id];params={'YEAR':'2026','TERM':'20','GAESUL_CAMPUS_GB':r['CAMPUS_GB'],'SEARCH_GB':'1','SEARCH_KEY':r['HAKSU_NO'],'HAK_JIBJUNG':'0','_TRANSACTION_ID':'selectMain','_FIRST_OUT_DS_NM':'dsGrdMain','_ALL_OUT_DS_NM':'dsGrdMain=dsGrdMain','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
 data=p.post('/E_NHSSU900070M/selectMain',params,'ko-exact-'+r['HAKSU_NO'])
 for x in data.get('dsGrdMain',[]):
  if x.get('HAKSU_NO_BUNBAN')==id:records.append(x);print(id,x.get('GYOSI_NAME'),flush=True)
 time.sleep(.12)
(P/'skku-truncated-ko-crosscheck.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
