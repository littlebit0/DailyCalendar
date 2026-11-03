import sys, json, time, subprocess, urllib.parse
from pathlib import Path
sys.path.insert(0, '/Users/kimhwi/Documents/Codex/DailyCalendar/work/wt/u-hufs-tt/tool/timetable')
import fetch_hufs as F
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36 DailyCalendar/1.0 (+https://github.com/littlebit0/DailyCalendar)'
def query(parameters):
    time.sleep(1.1)
    out = subprocess.run(['curl','-s','--max-time','60','-A',UA,'-e',F.SOURCE,'--data',urllib.parse.urlencode(parameters),F.BASE+'/hufs'],capture_output=True,check=True).stdout
    if len(out) > 8_000_000: raise ValueError('oversized')
    return F.decode_response(out.decode())
F.query = query
F.collect(Path(sys.argv[1]), 2026, resume='--resume' in sys.argv)
