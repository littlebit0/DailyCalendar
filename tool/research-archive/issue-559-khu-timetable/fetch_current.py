"""Re-query the official anonymous KHU undergraduate lecture list (same public parameters as 2026-10-07)."""
import json,time,urllib.parse,urllib.request,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent
SRC=Path('/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalogs/khu-major_202620.json')
majors=[r for r in json.loads(SRC.read_text()) if r['gb']=='H']
out=ROOT/'public-2026-10-23'
for i,m in enumerate(majors,1):
    f=out/(m['cd']+'.json')
    if f.exists(): continue
    params=dict(attribute='lectListJson',lang='ko',loginYn='N',menu='1',search_div='E',p_day='',p_time='',p_teach='',p_subjt='',p_major=m['cd'],p_lang='',p_year='2026',p_term='20',lecture_cd='',initYn='Y')
    req=urllib.request.Request('https://sugang.khu.ac.kr/core?'+urllib.parse.urlencode(params),headers={'User-Agent':'Mozilla/5.0 (compatible; DailyCalendar/1.0)','X-Requested-With':'XMLHttpRequest','Referer':'https://sugang.khu.ac.kr/login?attribute=loginMain&lang=ko&loginYn=N&schedule_cd=hakbu'})
    data=json.loads(urllib.request.urlopen(req,timeout=30).read())
    assert isinstance(data.get('rows'),list),data
    f.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    time.sleep(0.6)
    if i%20==0: print(i,len(majors),flush=True)
print('done',len(majors))
