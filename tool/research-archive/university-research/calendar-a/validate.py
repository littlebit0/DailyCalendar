"""Validate official rendered date ranges without guessing or clipping periods."""
import datetime as dt
import html
import json
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parent

def clean(value):
    return ' '.join(html.unescape(re.sub(r'<[^>]*>', ' ', value)).split())

def bounds(date_text, page_year, page_month):
    pairs = re.findall(r'(\d{2})\.(\d{2})', date_text)
    assert 1 <= len(pairs) <= 2, date_text
    sm, sd = map(int, pairs[0])
    sy = page_year - (sm > page_month)
    start = dt.date(sy, sm, sd)
    if len(pairs) == 1:
        end = start
    else:
        em, ed = map(int, pairs[1])
        end = dt.date(sy + (em < sm), em, ed)
    assert start <= end
    return start.isoformat(), end.isoformat()

def gnue():
    unique = {}
    for name in ['gnue-calendar-direct.html', 'gnue-2026-2.html', 'gnue-2025-2.html']:
        text = (ROOT / name).read_text()
        sections = re.findall(r'<div class="month_txt">\s*<p class="month_tit">(\d{4})년 (\d{2})월</p>\s*<ul>(.*?)</ul>', text, re.S)
        assert len(sections) == 6, (name,len(sections))
        rows = 0
        for year, month, section in sections:
            for date, title in re.findall(r'<li>\s*<span[^>]*>(.*?)</span>(.*?)</li>', section, re.S):
                start,end = bounds(clean(date), int(year), int(month))
                title = clean(title)
                rows += 1
                key = start,end,title
                unique[key] = {'start':start,'inclusiveEnd':end,'title':title}
        print(name, 'months',len(sections),'rows',rows)
    events = [e for e in unique.values() if e['start'] <= '2026-12-31' and e['inclusiveEnd'] >= '2026-01-01']
    events.sort(key=lambda e:(e['start'],e['title']))
    (ROOT / 'gnue-events2026.json').write_text(json.dumps(events,ensure_ascii=False,indent=2))
    print('GNUE 2026 unique overlap',len(events))
    for e in events:
        if '방학' in e['title']:print(e)

def konkuk():
    unique={}
    for year in [2025,2026]:
        name='konkuk-year.html' if year==2026 else 'konkuk-year2025.html'
        text=(ROOT/name).read_text()
        assert re.search(r'id="year"[^>]*value=[\'"]'+str(year),text)
        sections=re.findall(r'<p class="box-month">(\d+)월</p>(.*?)(?=<p class="box-month">|\Z)',text,re.S)
        assert len(sections)==12
        n=0
        for month,section in sections:
            for date,title in re.findall(r'<p class="list-date">(.*?)</p>\s*<p class="list-content">(.*?)</p>',section,re.S):
                start,end=bounds(clean(date),year,int(month));title=clean(title);n+=1
                unique[start,end,title]={'start':start,'inclusiveEnd':end,'title':title,'campus':'서울'}
        print('Konkuk Seoul',year,n)
    events=[e for e in unique.values() if e['start']<='2026-12-31' and e['inclusiveEnd']>='2026-01-01']
    events.sort(key=lambda e:(e['start'],e['title']))
    (ROOT/'konkuk-seoul-events2026.json').write_text(json.dumps(events,ensure_ascii=False,indent=2));print('Konkuk Seoul2026',len(events))

if __name__=='__main__':
    gnue();konkuk()
