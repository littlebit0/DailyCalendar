from pathlib import Path
from bs4 import BeautifulSoup as B
p=Path(__file__).parent;out=Path('test/fixtures/academic');out.mkdir(exist_ok=True,parents=True)
for school in ['nambu','pcu','konyang','dju']:
 d=B((p/(school+'-calendar.html')).read_bytes(),'html.parser')
 if school=='nambu':els=[t for t in d.select('table') if t.caption and t.caption.get_text(strip=True)=='학사 일정표']
 elif school=='pcu':
  els=[d.select_one('#years_sel'),d.select_one('#school_cal')]
  for e in els:
   for hidden in e.select('.calendars, .calendar, .month_cal'):hidden.decompose()
 elif school=='konyang':els=[d.select_one('#prev_schdule')]+[t for t in d.select('table') if t.select_one('th') and ('MONTH' in t.get_text() or t.select_one('th[colspan="2"]'))]
 else:els=[d.select_one('h4[in-data]')]+d.select('.schedule_calendar')
 (out/(school+'-expansion17-2026.html')).write_text('<!doctype html><meta charset="utf-8">'+''.join(str(e) for e in els))
 print(school,sum(len(str(e)) for e in els))
