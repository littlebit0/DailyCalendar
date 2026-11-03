import json,urllib.request,time,threading,concurrent.futures,hashlib
from pathlib import Path
p=Path(__file__).parent/'root-followup-a-sources';rows=[r for r in json.loads((p/'gachon-native-onload-global.json').read_text())['cbUnivCD'] if r['VALUE'].startswith('Y')];lock=threading.Lock();last=0
# Actual published ssu1000q.clx.js: college selection sends same SendData to subDeptList /Ssu1000q/deptList.do and response cbDeptCD drives visible 学部/学科 combo.
def f(r):
 global last
 q={'groupType':'21','searchYear':'2026','searchTerm':'20','searchUnivCD':r['VALUE'],'searchDeptCD':'','searchIsuCD':'001','searchGrade':'','searchSubjectNm':''}
 with lock:
  time.sleep(max(0,.8-(time.monotonic()-last)));last=time.monotonic()
 u='https://info.gachon.ac.kr/Ssu1000q/deptList.do'
 try:
  b=urllib.request.urlopen(urllib.request.Request(u,data=json.dumps({'data':{'SendData':q}}).encode(),headers={'User-Agent':'Mozilla/5.0','Content-Type':'application/json;charset=UTF-8','Referer':'https://info.gachon.ac.kr/ssu/showTimetable.do'}),timeout=30).read();j=json.loads(b)
  (p/('gachon-medical-native-depts-'+r['VALUE']+'.json')).write_text(json.dumps(j,ensure_ascii=False,indent=2));return {'college':r,'query':q,'url':u,'sourceFile':str((p/('gachon-medical-native-depts-'+r['VALUE']+'.json')).resolve()),'sha256':hashlib.sha256(b).hexdigest(),'departments':j.get('cbDeptCD',[])}
 except Exception as e:return {'college':r,'query':q,'url':u,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:out=list(ex.map(f,rows))
(p/'gachon-medical-native-parent-receipts.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print({'colleges':len(out),'failed':sum('error'in r for r in out),'deptRows':sum(len(r.get('departments',[]))for r in out)})
