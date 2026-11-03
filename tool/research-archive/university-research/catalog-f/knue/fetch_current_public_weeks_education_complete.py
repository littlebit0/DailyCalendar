from urllib.request import build_opener, HTTPCookieProcessor, Request
from urllib.parse import urlencode,quote
from http.cookiejar import CookieJar
from pathlib import Path
import base64,time,json,hashlib
R=Path(__file__).resolve().parent
CHECKS=[]
op=build_opener(HTTPCookieProcessor(CookieJar()))
base='https://haksa.knue.ac.kr'
op.open(base+'/checkMenu.jsp?p0=P0mR43tX7RX1813o',timeout=25).read()
page=op.open(base+'/patis/common/OutLinkController.do',urlencode({'method':'checkURL','MENU_KEY':'P0mR43tX7RX1813o'}).encode(),timeout=25).read()
def query(service,method,mc,extra={}):
 params=dict(extra,serviceName=service,methodName=method,REQUEST_MENU_CD=mc,PRIVATE_FRAME_GB='3')
 def enc(x):return base64.b64encode(quote(x,safe="~()*!.'-").encode()).decode()
 parts=['SSV:utf-8']
 for i,(k,v) in enumerate(params.items()):parts.extend([f'PARAM{i}='+enc(k),f'VALUE{i}='+enc(v)])
 req=Request(base+'/patis/system/serviceController.do?platformType=nexacro&mc='+mc, ('\x1e'.join(parts)+'\x1e').encode(),headers={'Content-Type':'text/xml;charset=UTF-8','Referer':base+'/patis/common/OutLinkController.do'})
 data=op.open(req,timeout=25).read()
 if any(x in data.lower() for x in [b'access denied',b'captcha',b'too many requests']):raise RuntimeError('protective response stop')
 CHECKS.append({'method':method,'SHA256':hashlib.sha256(data).hexdigest()})
 time.sleep(.8);return data
initdata=query('Hl0402Service','selectInitData','3020408')

def datasets(data):
 text=data.decode('utf-8')
 result={}
 for part in text.split('Dataset:')[1:]:
  lines=part.split('\x1e');name=lines[0]
  columns=[v.split(':')[0] for v in lines[1].split('\x1f')][1:]
  result[name]=[dict(zip(columns,line.split('\x1f')[1:])) for line in lines[2:] if line.startswith('N\x1f')]
 return result
init=datasets(initdata)
del initdata
print('public-init', {k:len(v) for k,v in init.items()},flush=True)
(R/'init-field-inventory.json').write_text(json.dumps({k:sorted(set(q for r in v for q in r)) for k,v in init.items()},ensure_ascii=False,indent=2)+'\n')
weeks=[r for r in init['ds_out03'] if all(r.get(k)==v for k,v in {'YEAR':'2026','HAKGI':'2','CORS_GB':'1','GYEJEOLJE_GB':'1','DAEHAK_CD':'99999999'}.items())]
root=R/'current-weeks-education-complete-20261008';root.mkdir(exist_ok=True)
for r in weeks:
 data=query('Hl0402Service','selectList','3020408',{'YEAR':'2026','HAKGI':'2','CORS_GB':'1','GYEJEOLJE_GB':'1','DAEHAK_CD':'','HAKGWA_CD':'','JEONGONG_CD':'','GWAJEONG_GB':'','HAKNYEON':'','ISU_GYOGWA_GB':'','ISU_GB':'','GWAMOK_NM':'','GANGUI_JUCHA':r['GANGUI_JUCHA'],'JU_STT_DT':r['STT_DT'],'JU_END_DT':r['END_DT'],'GANGUI_JUCHA2':'0','GYORYU_GANGJWA_YN':'0'})
 import json
 rows=datasets(data)['ds_out']
 # Keep public timetable fields only; omit employee identifiers and file paths.
 fields=['YEAR','HAKGI','CORS_GB','GWAMOK_CD','GWAMOK_NM','BUNBAN','GYEJEOLJE_GB','DAEHAK_CD','HAKGWA_CD','JEONGONG_CD','ISU_GB_NM','JEONGONG_NM','HAKJEOM','GYOSU_NM','SIGANPYO2','BIGO','SUGANG_HAKNYEON_NM','GWAJEONG_GB_NM','GANGUI_JUCHA','IRON_SISU','SILSEUP_SISU','TIMTICHING_YN','SUGANG_JEHAN_INWON','GYORYU_JEHAN_INWON','GANGUI_TIME_GB_NM']
 (root/('week-'+r['GANGUI_JUCHA']+'.json')).write_text(json.dumps({'week':r,'courses':[{k:x.get(k) for k in fields} for x in rows]},ensure_ascii=False))
 print('week',r['GANGUI_JUCHA'],'courses',len(rows),flush=True)
 (R/'current-education-complete-public-flow-audit.json').write_text(json.dumps({'normalPublicFlowOnly':True,'privateOrStaffFieldsPersisted':False,'requests':CHECKS,'finished':False},indent=2)+'\n')

(R/'current-education-complete-public-flow-audit.json').write_text(json.dumps({'normalPublicFlowOnly':True,'privateOrStaffFieldsPersisted':False,'requests':CHECKS,'finished':True,'wholeWeeks':len(weeks)},indent=2)+'\n')
