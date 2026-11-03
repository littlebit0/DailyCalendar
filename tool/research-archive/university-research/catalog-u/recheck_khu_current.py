"""Recheck the university's documented anonymous undergraduate department list.

No account access, login or session extraction. Only educational fields saved.
"""
import json,time,urllib.parse,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parent
OLD=ROOT.parent/'catalogs'
FIELDS={'queryDepartment','queryDepartmentName','timetable','eng_yn_nm','bigo','lect_grade','subjt_cd','campus_nm','field_gb','lecture_cd','teach_na','unit_num','subjt_name','class_cd','haksu_code','lecture_cd_disp'}
majors=[r for r in json.loads((OLD/'khu-major_202620.json').read_text()) if r['gb']=='H']
rows=[];manifest=[]
for i,major in enumerate(majors,1):
 params=dict(attribute='lectListJson',lang='ko',loginYn='N',menu='1',search_div='E',p_day='',p_time='',p_teach='',p_subjt='',p_major=major['cd'],p_lang='',p_year='2026',p_term='20',lecture_cd='',initYn='Y')
 url='https://sugang.khu.ac.kr/core?'+urllib.parse.urlencode(params)
 request=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0','X-Requested-With':'XMLHttpRequest','Referer':'https://sugang.khu.ac.kr/login?attribute=loginMain&lang=ko&loginYn=N&schedule_cd=hakbu'})
 try:
  with urllib.request.urlopen(request,timeout=35) as response:data=json.loads(response.read())
  if not isinstance(data.get('rows'),list):raise ValueError('Anonymous list unavailable')
 except Exception as error:
  (ROOT/'khu-current-query-failure-20261008.json').write_text(json.dumps({'department':major['cd'],'finishedDepartments':i-1,'errorType':type(error).__name__,'fullCollectionComplete':False},indent=2)+'\n')
  raise SystemExit(f'Stopped normally at department{i}; {type(error).__name__}')
 safe=[{k:v for k,v in dict(queryDepartment=major['cd'],queryDepartmentName=major['nm'],**r).items() if k in FIELDS} for r in data['rows']]
 (ROOT/f"khu-current-{major['cd']}-20261008.json").write_text(json.dumps(safe,ensure_ascii=False,indent=2)+'\n');rows.extend(safe)
 manifest.append({'department':major['cd'],'name':major['nm'],'rows':len(safe)})
 if i%20==0:print(f'Checked {i}/{len(majors)} departments; {len(rows)} educational rows',flush=True)
 time.sleep(.35)
(ROOT/'khu-current-educational-rows-20261008.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
old=[{k:v for k,v in r.items() if k in FIELDS} for r in json.loads((OLD/'khu-public-all-query-rows.json').read_text())]
canon=lambda rs:{json.dumps(r,ensure_ascii=False,sort_keys=True) for r in rs}
a,b=canon(old),canon(rows)
audit={'checkedAt':'2026-10-08','departments':len(manifest),'rows':len(rows),'previousRawRows':len(old),'addedEducationalVariants':len(b-a),'removedEducationalVariants':len(a-b),'completionClaim':False,'operatingReviewComplete':False,'fullDepartmentQueryCollectionComplete':True,'noAccountOrSessionAccess':True,'staffAndEnrollmentCountersExcluded':True}
(ROOT/'khu-current-educational-recheck-audit-20261008.json').write_text(json.dumps(audit,indent=2)+'\n');print(audit,flush=True)
