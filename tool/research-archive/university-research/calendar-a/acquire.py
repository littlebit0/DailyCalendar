"""Read only normal official published calendar queries; sanitize session markers."""
import datetime as dt
import json
import pathlib
import re
import time
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent
HEADERS = {'User-Agent': 'Mozilla/5.0 DailyCalendar-source-validation'}

def fetch(name, url, data=None):
    req = urllib.request.Request(url, headers=HEADERS,
        data=urllib.parse.urlencode(data).encode() if data is not None else None)
    with urllib.request.urlopen(req, timeout=30) as response:
        text = response.read().decode('utf-8')
    text = re.sub(r';jsessionid=[A-Za-z0-9]+', '', text)
    (ROOT / name).write_text(text)
    time.sleep(.25)
    return text

def chosun():
    ids = set()
    for year, month in [(2025, 12)] + [(2026, m) for m in range(1, 13)]:
        text = fetch(f'chosun-{year}-{month:02d}.html',
            'https://csu.chosun.ac.kr/schdulmanage/chosun/1/view.do',
            {'siteId': 'chosun', 'year': year, 'month': month, 'kind': ''})
        assert f'{year}년 {month}월 학사일정 표' in text
        ids.update(re.findall(r"set_layer\('([0-9]+)', 'chosun', '1'\)", text))
        print('chosun month', year, month, len(ids), flush=True)
    events = []
    for ident in sorted(ids, key=int):
        text = fetch(f'chosun-layer-{ident}.html',
            f'https://csu.chosun.ac.kr/schdulmanage/chosun/1/{ident}/schdulManageArtclLayer.do', {})
        title = re.search(r'<h1>(.*?)</h1>', text, re.S).group(1).strip()
        dates = re.findall(r'\b(20\d{2})\.(\d{2})\.(\d{2})\b', text)
        assert len(dates) == 2, ident
        start, end = [dt.date(*map(int, d)) for d in dates]
        assert start <= end, ident
        events.append({'officialId': ident, 'title': title, 'start': start.isoformat(),
            'inclusiveEnd': end.isoformat()})
    overlap = [e for e in events if e['start'] <= '2026-12-31' and e['inclusiveEnd'] >= '2026-01-01']
    (ROOT / 'chosun-events2026.json').write_text(json.dumps(overlap, ensure_ascii=False, indent=2))
    print('chosun final', len(events), len(overlap), flush=True)

if __name__ == '__main__':
    chosun()
