"""Normal anonymous published DGIST offering form; no account/private identifiers saved."""
import json,time
from urllib.request import Request,urlopen
from urllib.parse import urlencode
from pathlib import Path
ROOT=Path(__file__).resolve().parent
BASE='https://welcome.dgist.ac.kr/ucs/ucsqProfRespSbjtInq/'
REMOVED={'PROF_NO','EMP_NO','CHRG_NO','USER_ID','EMAIL','TEL','PROF_ID'}
def request(path,form):
 time.sleep(.6)
 raw=urlopen(Request(BASE+path,data=urlencode(form).encode()),timeout=35).read()
 return json.loads(raw)
meta=[]
for orgn,curi in [('CMN12.03','2024'),('CMN12.03','2014'),('CMN12.12','')]:
 form={'pageNum':'1','pageSize':'99999','commonProgramId':'UcsqProfRespSbjtInq','searchOrgnClsfDcd':orgn,'searchLang':'ko','selectYearTerm':'2026CMN17.20','searchCuriShyy':curi,'searchCors':'','searchSust':'','searchCptnDcd':'','searchSbjtDetaDcd':'','searchSbNo':'','searchProfNm':''}
 if orgn=='CMN12.12':
  options=request('selectCorsList.do',form);ROOT.joinpath('dgist-ai-course-options.json').write_text(json.dumps(options,ensure_ascii=False,indent=2))
 a=request('list.do',form);rows=a.get('user',[]);assert int(a['records'])==len(rows) and int(a['total'])<=1
 safe=[{k:v for k,v in row.items() if k not in REMOVED} for row in rows]
 name='dgist2026-2-'+('ai' if orgn=='CMN12.12' else curi+'-curriculum')+'-rows.json';ROOT.joinpath(name).write_text(json.dumps(safe,ensure_ascii=False,indent=2))
 meta.append({'url':BASE+'list.do','publicForm':form,'records':int(a['records']),'rows':len(rows),'file':name,'removedPrivateIdentifierFields':list(REMOVED)})
 print(name,len(rows),flush=True)
ROOT.joinpath('dgist2026-2-acquisition-audit.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
