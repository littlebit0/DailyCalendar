"""Enumerate every official 2026-2 undergraduate major selector across all campuses."""
from skku_public import Public,P
import json,time
p=Public("KO",prefix="skku-ko-");base='/E_NHSSU900020M/'
def post(action,params,name,out):
 params=dict(params,_TRANSACTION_ID=action,_FIRST_OUT_DS_NM=out,_ALL_OUT_DS_NM=out+'='+out,_MENU_ID='EXT_SCHEDULE',_PGM_ID='NHSSU030840M')
 return p.post(base+action,params,name).get(out,[])
colleges=post('selectBizType03',{'JOJIK_GB':'31','YEAR':'2026','TERM':'20'},'major-colleges','dsTongHakbu')
departments={}
for c in colleges:
 ds=post('selectBizType04',{'JOJIK_GB':'31','YEAR':'2026','TERM':'20','TONG_HAKBU':c['COM_CD']},'major-departments-'+c['COM_CD'],'dsHakgwa')
 for d in ds:departments[d['COM_CD']]=d
 time.sleep(.1)
(P/'skku-ko-major-departments.json').write_text(json.dumps(list(departments.values()),ensure_ascii=False,indent=2));print('departments',len(departments),flush=True)
records=[];index=[]
for campus in ['1','2','3']:
 for dep in departments:
  params={'YEAR':'2026','TERM':'20','HAKGWA_CD':dep,'ROAD_MAP':'%','CAMPUS_GB':campus,'HAK_JIBJUNG':'0'}
  name='major-courses-'+campus+'-'+dep;path=P/('skku-ko-'+name+'.json')
  if path.exists():data=json.loads(path.read_text()).get('dsGrdMain',[])
  else:data=post('selectMain',params,name,'dsGrdMain')
  records.extend(dict(row,queryCampus=campus,queryDepartment=dep)for row in data);index.append(dict(params,count=len(data)))
  time.sleep(.12)
 print('campus',campus,'rawRows',len(records),flush=True)
(P/'skku-ko-major-all-2026-2.json').write_text(json.dumps({'index':index,'records':records},ensure_ascii=False,indent=2));print('completeMajorRequests',len(index),'rawRows',len(records),flush=True)
