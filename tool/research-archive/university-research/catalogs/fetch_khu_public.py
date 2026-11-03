"""Collect only the officially exposed anonymous undergraduate department search."""
import json,time,urllib.parse,urllib.request,collections
from pathlib import Path
ROOT=Path(__file__).resolve().parent
majors=[r for r in json.loads((ROOT/'khu-major_202620.json').read_text()) if r['gb']=='H']
directory=ROOT/'khu-public-2026-2';directory.mkdir(exist_ok=True)
manifest=[]
for index,major in enumerate(majors,1):
    filename=directory/(major['cd']+'.json')
    if not filename.exists():
        params=dict(attribute='lectListJson',lang='ko',loginYn='N',menu='1',search_div='E',p_day='',p_time='',p_teach='',p_subjt='',p_major=major['cd'],p_lang='',p_year='2026',p_term='20',lecture_cd='',initYn='Y')
        url='https://sugang.khu.ac.kr/core?'+urllib.parse.urlencode(params)
        request=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0','X-Requested-With':'XMLHttpRequest','Referer':'https://sugang.khu.ac.kr/login?attribute=loginMain&lang=ko&loginYn=N&schedule_cd=hakbu'})
        response=urllib.request.urlopen(request,timeout=45)
        data=json.loads(response.read())
        assert isinstance(data.get('rows'),list),data
        filename.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
        time.sleep(.25)
    rows=json.loads(filename.read_text())['rows']
    manifest.append(dict(major=major['cd'],name=major['nm'],count=len(rows),file=str(filename.relative_to(ROOT))))
    if index%20==0:print('Departments',index,'/',len(majors),'rows',sum(x['count'] for x in manifest),flush=True)
(ROOT/'khu-public-query-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
allrows=[]
for record in manifest:
    for row in json.loads((ROOT/record['file']).read_text())['rows']:
        allrows.append(dict(queryDepartment=record['major'],queryDepartmentName=record['name'],**row))
(ROOT/'khu-public-all-query-rows.json').write_text(json.dumps(allrows,ensure_ascii=False,indent=2)+'\n')
keys=collections.Counter((r['campus_nm'],r['lecture_cd_disp']) for r in allrows)
summary=dict(queryDepartments=len(manifest),rawRows=len(allrows),uniqueCampusCourseSections=len(keys),campusRawCounts=dict(collections.Counter(r['campus_nm'] for r in allrows)),emptyTimeRaw=sum(not r['timetable'] for r in allrows),categories=dict(collections.Counter(r['field_gb'] for r in allrows)),fullEnablingSafe=False,blockers=['Category code mapping and active teaching dates need primary-source validation.', 'Duplicate cross-department sections must preserve restrictions and reconcile conflicting fields.'])
(ROOT/'khu-public-catalog-audit.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(summary,ensure_ascii=False,indent=2))
