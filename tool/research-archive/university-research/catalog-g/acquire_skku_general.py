"""Enumerate published general-course category selectors and full sections."""
from skku_public import Public,P
import json,re,time
p=Public();base='/E_NHSSU900010M/'
def post(action,params,name,out):
 params=dict(params,_TRANSACTION_ID=action,_FIRST_OUT_DS_NM=out,_ALL_OUT_DS_NM=out+'='+out,_MENU_ID='EXT_SCHEDULE',_PGM_ID='NHSSU030840M')
 path=P/('skku-'+name+'.json')
 if path.exists():
  data=json.loads(path.read_text())
 else:data=p.post(base+action,params,name)
 if out not in data:raise ValueError('Expected dataset absent: '+name)
 return data[out]
js=(P/'NHSSU900010M_EN.js').read_text()
categories=re.findall(r'new BindItem\("item_[^"]+","[^"]+","text","dsGrdMain01","([^"]+)"\)',js)
records=[];index=[]
for campus in ['1','2','3']:
 common={'YEAR':'2026','TERM':'20','CAMPUS_GB':campus,'HAK_JIBJUNG':'0'}
 counts=post('selectMain01',common,'general-counts-'+campus,'dsGrdMain01')
 codes={}
 for category in categories:
  rows=post('selectMain02',dict(common,YUNGYUK_ETC_CD=category),'general-subjects-'+campus+'-'+category,'dsGrdMain02')
  index.append(dict(campus=campus,category=category,count=len(rows)))
  for row in rows:codes.setdefault(row['HAKSU_NO'],[]).append(category)
  time.sleep(.12)
 print('campus',campus,'general subjects',len(codes),flush=True)
 for code, cats in codes.items():
  rows=post('selectMain03',dict(common,HAKSU_NO=code),'general-sections-'+campus+'-'+code,'dsGrdMain03')
  records.extend(dict(row,queryCampus=campus,queryCategories=cats) for row in rows)
  time.sleep(.12)
 print('campus',campus,'general rows',len(records),flush=True)
(P/'skku-general-all-2026-2.json').write_text(json.dumps({'categories':categories,'index':index,'records':records},ensure_ascii=False,indent=2))
