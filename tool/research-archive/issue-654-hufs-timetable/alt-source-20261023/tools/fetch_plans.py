import sys, json, re, time, subprocess
from pathlib import Path
sys.path.insert(0,'/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-t')
src=open('/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-t/acquire_hufs_whole_operating_plans.py').read()
ns={}; exec(src.split('from concurrent.futures')[0].replace('ROOT=Path(__file__).resolve().parent','ROOT=Path(".")'), ns)
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36 DailyCalendar/1.0 (+https://github.com/littlebit0/DailyCalendar)'
keys=json.load(open(sys.argv[1])); out=Path(sys.argv[2]); out.mkdir(exist_ok=True)
for campus,key in keys:
    path=out/f'{campus}-{key}.json'
    if path.exists(): continue
    url='https://wis.hufs.ac.kr/src08/jsp/lecture/syllabus.jsp?mode=print&ledg_year=2026&ledg_sessn=3&org_sect=A&lssn_cd='+key
    time.sleep(1.1)
    body=subprocess.run(['curl','-s','--max-time','60','-A',UA,url],capture_output=True,check=True).stdout.decode('utf-8','replace')
    p=ns['Cells'](); p.feed(body); fields=ns['educational_cells'](p.values)
    ok=bool(re.search(r'(?:^|\s)'+re.escape(key)+r'$',fields.get('identity',''))) and '2026-2학기' in body
    path.write_text(json.dumps({'campus':campus,'key':key,'sourceUrl':url,'checkedDate':'2026-10-23','headerOk':ok,'fields':fields},ensure_ascii=False,indent=2))
    print(campus,key,ok,flush=True)
