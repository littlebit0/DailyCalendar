"""Anonymous 수강신청 public list for graduate orgs (gb=D), p_year=2026 p_term=20."""
import json,time,urllib.parse,urllib.request
from pathlib import Path
R=Path(__file__).resolve().parent
maj=[r for r in json.loads(Path('/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalogs/khu-major_202620.json').read_text()) if r['gb']=='D']
out=R/'grad-2026-10-24'
for m in maj:
    f=out/(m['cd']+'.json')
    if f.exists(): continue
    p=dict(attribute='lectListJson',lang='ko',loginYn='N',menu='1',search_div='E',p_day='',p_time='',p_teach='',p_subjt='',p_major=m['cd'],p_lang='',p_year='2026',p_term='20',lecture_cd='',initYn='Y')
    q=urllib.request.Request('https://sugang.khu.ac.kr/core?'+urllib.parse.urlencode(p),headers={'User-Agent':'Mozilla/5.0 (compatible; DailyCalendar/1.0)','X-Requested-With':'XMLHttpRequest','Referer':'https://sugang.khu.ac.kr/login?attribute=loginMain&lang=ko&loginYn=N&schedule_cd=hakbu'})
    d=json.loads(urllib.request.urlopen(q,timeout=30).read()); assert isinstance(d.get('rows'),list)
    f.write_text(json.dumps(d,ensure_ascii=False)); time.sleep(0.6)
print('done',len(maj))
