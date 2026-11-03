# 숭실대 공개 강의시간표(zcmw2100) 2026-2 전체 재수집: 범위 대조용.
# work/university-research/catalog-c/acquire_ssu.py + acquire_ssu_general.py를 합치고
# 출력 폴더 분리, 요청 간격 0.6초, 숭실사이버대 탭 추가.
import urllib.request, urllib.parse, http.cookiejar, re, html, json, time, sys
from pathlib import Path
from html.parser import HTMLParser

OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
URL = 'https://ecc.ssu.ac.kr/sap/bc/webdynpro/sap/zcmw2100?sap-language=KO'
# SAP Web Dynpro는 브라우저 UA가 아니면 'cannot be processed in plugin mode'(500)로 답한다. 식별자는 붙여 둔다.
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36 (compatible; DailyCalendar/1.0)'
HEAD = {'User-Agent': UA, 'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9'}
SAFE = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_.'
enc = lambda ev: ''.join(c if c in SAFE else '~' + format(ord(c), '04X') for c in ev)
cdata = lambda raw: ''.join(re.findall(r'<!\[CDATA\[(.*?)\]\]>', raw.decode(), re.S))

opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
with opener.open(urllib.request.Request(URL, headers=HEAD), timeout=30) as r:
    s = r.read().decode()
form = re.search(r'<form\b[^>]*action="([^"]+)"[^>]*>(.*?)</form>', s, re.S)
action = urllib.parse.urljoin(URL, html.unescape(form.group(1)))
data = {html.unescape(n): html.unescape(v) for n, v in re.findall(r'name="([^"]+)" value="([^"]*)"', form.group(2))}
data['SAPEVENTQUEUE'] = enc('LoadingPlaceHolder_LoadId_loadingPlaceholder_ResponseDatadeltaClientActionsubmit')
headers = dict(HEAD, Referer=URL, Origin='https://ecc.ssu.ac.kr')
headers.update({'X-Requested-With': 'XMLHttpRequest', 'X-XHR-Logon': 'accept',
                'Content-Type': 'application/x-www-form-urlencoded'})
time.sleep(0.6)
with opener.open(urllib.request.Request(action, data=urllib.parse.urlencode(data).encode(), headers=headers), timeout=30) as r:
    b = r.read()
(OUT / 'loaded.xml').write_bytes(b)
loaded = cdata(b)
year = re.search(r'id="WD92"[^>]*value="([^"]+)"', loaded)
sem = re.search(r'id="WDE6"[^>]*value="([^"]+)"', loaded)
print('term', year and year[1], sem and sem[1])
assert year and year[1] == '2026학년도' and sem and sem[1] == '2학기'


def event(control, ev, params, label):
    global action, data, b
    content = cdata(b)
    f = re.search(r'<form\b[^>]*action="([^"]+)"[^>]*>(.*?)</form>', content, re.S)
    if f:
        action = urllib.parse.urljoin(URL, html.unescape(f.group(1)))
        data = {html.unescape(n): html.unescape(v) for n, v in re.findall(r'name="([^"]+)" value="([^"]*)"', f.group(2))}
    q = control + '_' + ev + '' + ''.join(k + '' + str(v) for k, v in params.items()) + \
        'ResponseDatadeltaClientActionsubmit'
    data['SAPEVENTQUEUE'] = enc(q)
    time.sleep(0.6)
    with opener.open(urllib.request.Request(action, data=urllib.parse.urlencode(data).encode(), headers=headers), timeout=60) as r:
        b = r.read()
    (OUT / f'{label}.xml').write_bytes(b)
    return b


class Options(HTMLParser):
    def __init__(self, ident):
        super().__init__(); self.ident = ident; self.depth = 0; self.items = []

    def handle_starttag(self, t, a):
        d = dict(a)
        if t == 'div':
            if self.depth: self.depth += 1
            elif d.get('id') == self.ident: self.depth = 1
        if self.depth and d.get('ct') == 'LIB_I':
            self.items.append((d['data-itemkey'], d.get('data-itemvalue1', '')))

    def handle_endtag(self, t):
        if t == 'div' and self.depth: self.depth -= 1


def opts(raw, ident):
    p = Options(ident); p.feed(cdata(raw)); return p.items


index = []
for college, cname in opts(b, 'WD0104'):
    event('ComboBox', 'Select', {'Id': 'WD0103', 'Key': college, 'ByEnter': 'false'}, 'college-' + college)
    for dept, dname in opts(b, 'WD0114'):
        event('ComboBox', 'Select', {'Id': 'WD0113', 'Key': dept, 'ByEnter': 'false'}, 'department-' + dept)
        event('Button', 'Press', {'Id': 'WD0119'}, f'courses-{college}-{dept}')
        index.append({'tab': '학부전공별', 'college': college, 'collegeName': cname, 'key': dept, 'name': dname,
                      'file': f'courses-{college}-{dept}.xml'})
    print('college', cname, len(index), flush=True)

for item, idx, label in [('WD011A', 1, 'required'), ('WD011D', 2, 'elective'), ('WD0120', 3, 'chapel'),
                         ('WD0123', 4, 'teaching'), ('WD0129', 6, 'linked'), ('WD012C', 7, 'convergence'),
                         ('WD0138', 11, 'cyber')]:
    event('TabStrip', 'TabSelect', {'Id': 'WDF4', 'ItemId': item, 'ItemIndex': idx, 'FirstVisibleItemIndex': 0}, label + '-tab')
    buttons = re.findall(r'<div[^>]*id="([^"]+)"[^>]*ct="B"[^>]*lsdata="([^"]+)"', b.decode())
    search = [i for i, attrs in buttons if '검색' in attrs]
    assert len(search) == 1, (label, search)

    class Controls(HTMLParser):
        def __init__(self): super().__init__(); self.items = []

        def handle_starttag(self, t, a):
            d = dict(a)
            if d.get('ct') == 'CB' and d['id'] not in ['WD92', 'WDE6', 'WD015D']:
                m = re.search(r"3:'([^']+)'", d.get('lsdata', ''))
                if m: self.items.append((d['id'], m[1]))
    c = Controls(); c.feed(cdata(b))
    if label in ('teaching', 'cyber') or not c.items:
        event('Button', 'Press', {'Id': search[0]}, label + '-courses')
        index.append({'tab': label, 'key': '', 'name': '', 'file': label + '-courses.xml', 'controls': c.items})
        print(label, 'single', c.items, flush=True)
        continue
    assert len(c.items) == 1, (label, c.items)
    ident, listbox = c.items[0]
    for key, choice in opts(b, listbox):
        event('ComboBox', 'Select', {'Id': ident, 'Key': key, 'ByEnter': 'false'}, f'{label}-choice-{key}')
        event('Button', 'Press', {'Id': search[0]}, f'{label}-courses-{key}')
        index.append({'tab': label, 'key': key, 'name': choice, 'file': f'{label}-courses-{key}.xml'})
    print(label, len(index), flush=True)
(OUT / 'index.json').write_text(json.dumps(index, ensure_ascii=False, indent=1) + '\n')
print('queries', len(index))
