#!/usr/bin/env python3
"""Crawl uwins MCB07S public view: 2026-2, every undergraduate college/hagbu/sosog x grade 1-5 (전공별) and every 영역별 area x grade."""
import html, json, os, re, subprocess, sys, time
import urllib.parse

# Public read-only view; no login. robots.txt on uwins redirects to an error page,
# so per the 2026-10-23 user decision it is queried directly: >=1.2 s between
# requests, identifying User-Agent, curl only.
URL = 'https://uwins.ulsan.ac.kr/LESN/B/MCB07S.aspx?MenuID=MCB07S!1&frame=oebu'
UA = ('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0 Safari/537.36 '
      'DailyCalendar/1.0 (+https://github.com/littlebit0/DailyCalendar)')
_last = [0.0]

def curl(cookie, data=None, out=None):
    wait = 1.2 - (time.time() - _last[0])
    if wait > 0: time.sleep(wait)
    cmd = ['curl', '-s', '-m', '60', '-A', UA, '-c', cookie, '-b', cookie,
           '-w', '%{http_code}', '-o', out]
    if data is not None:
        body = out + '.body'
        with open(body, 'w') as fh:
            fh.write(urllib.parse.urlencode(data))
        cmd += ['-e', URL, '-H', 'Content-Type: application/x-www-form-urlencoded',
                '--data-binary', '@' + body]
    cmd.append(URL)
    code = subprocess.run(cmd, capture_output=True, text=True).stdout
    _last[0] = time.time()
    if code != '200':
        raise RuntimeError(f'HTTP {code}')
    return open(out, encoding='utf-8', errors='replace').read()

from ulsan_view import P, check_area_view, check_navigation, check_term, form, options


OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
CK = os.path.join(OUT, 'ck.txt')
GRAD = {'11042', '11111', '11108', '11122', '11136', '12047', '12050', '12110', '12053'}
ROW = re.compile(r'<tr>\s*<td>\s*<span id="CP1_iuwgList_lbIsuNm_(\d+)">(.*?)</span>(.*?)</tr>', re.S)

def text(x):
    return ' '.join(html.unescape(re.sub(r'<[^>]+>', ' ', x)).replace('\xa0', ' ').split())

def rows(s):
    if '해당자료가 없습니다' in s and 'lbIsuNm_0' not in s:
        return []
    out = []
    for m in ROW.finditer(s):
        idx, isu, rest = m.groups()
        tds = re.findall(r'<td[^>]*>(.*?)</td>', '<td>' + rest, re.S)
        cells = [text(t) for t in tds]
        sp = re.search(r"SetParam\(&#39;[AB]&#39;,(.*?)\);", rest)
        args = [a.strip().strip("'") for a in html.unescape(sp.group(1)).split(',')] if sp else []
        out.append({'idx': int(idx), 'isu': text(isu), 'cells': cells, 'setParam': args})
    n = len(re.findall(r'id="CP1_iuwgList_lbIsuNm_\d+"', s))
    if len(out) != n:
        raise RuntimeError(f'row parse mismatch {len(out)} != {n}')
    return out

def fresh():
    if os.path.exists(CK): os.remove(CK)
    s = curl(CK, out=os.path.join(OUT, 'last.html'))
    return s

def post(s, target, **vals):
    f = form(s)
    f['__EVENTTARGET'] = target
    f['__EVENTARGUMENT'] = ''
    for k, v in vals.items():
        f[P + k] = v
    return curl(CK, f, os.path.join(OUT, 'last.html'))

results = json.load(open(os.path.join(OUT, 'major.json'))) if os.path.exists(os.path.join(OUT, 'major.json')) else []
done = {(r['daehag'][0], r['hagbu'][0], r['sosog'][0], r['grade']) for r in results}
tree = json.load(open(os.path.join(OUT, 'tree.json'))) if os.path.exists(os.path.join(OUT, 'tree.json')) else []
seen_tree = {(t['daehag'][0], t['hagbu'][0]) for t in tree}
s = fresh()
check_term(s)
colleges = [(v, t) for v, t in options(s, P + 'ddlDaehag') if v not in GRAD]
json.dump(options(s, P + 'ddlDaehag'), open(os.path.join(OUT, 'colleges.json'), 'w'), ensure_ascii=False)

def goto(dv, hv=None, tries=3):
    global s
    for t in range(tries):
        try:
            s = post(s, P + 'ddlDaehag', ddlDaehag=dv, ddlSearchType='1')
            check_navigation(s, dv)
            if hv is not None:
                s = post(s, P + 'ddlHagbu', ddlDaehag=dv, ddlHagbu=hv, ddlSearchType='1')
                check_navigation(s, dv, hv)
            return s
        except RuntimeError as e:
            print('retry nav', dv, hv, e, flush=True)
            s = fresh()
    raise RuntimeError('navigation failed')

for dv, dn in (colleges if os.environ.get('SKIP_MAJOR') != '1' else []):
    goto(dv)
    allnames = options(s, P + 'ddlHagbu')
    hagbus = []
    for hv, hn in allnames:
        if hv not in [h for h, _ in hagbus]:
            hagbus.append((hv, hn))
    if not options(s, P + 'ddlSosog'):
        # 교양대학 has a 교양학부 entry without any 소속; postbacks on it fail server-side.
        for hv, hn in hagbus:
            if (dv, hv) not in seen_tree:
                tree.append({'daehag': [dv, dn], 'hagbu': [hv, hn], 'hagbuNames': [hn], 'sosog': []})
                seen_tree.add((dv, hv))
        json.dump(tree, open(os.path.join(OUT, 'tree.json'), 'w'), ensure_ascii=False, indent=1)
        print('no sosog', dn, hagbus, flush=True)
        s = fresh()
        continue
    for hv, hn in hagbus:
        goto(dv, hv)
        sosogs = options(s, P + 'ddlSosog')
        if (dv, hv) not in seen_tree:
            tree.append({'daehag': [dv, dn], 'hagbu': [hv, hn], 'hagbuNames': [n for v, n in allnames if v == hv], 'sosog': sosogs})
            seen_tree.add((dv, hv))
        for sv, sn in sosogs:
            for y in '12345':
                if (dv, hv, sv, y) in done:
                    continue
                for t in range(3):
                    try:
                        s = post(s, P + 'btnSearch', ddlDaehag=dv, ddlHagbu=hv, ddlSosog=sv, ddlHagnyeon=y, ddlSearchType='1', ddlGangjwa_yu_gb='%')
                        break
                    except RuntimeError as e:
                        print('retry search', dv, hv, sv, y, e, flush=True)
                        s = fresh(); goto(dv, hv)
                else:
                    raise RuntimeError('search failed')
                check_term(s)
                f = form(s)
                if (f[P + 'ddlDaehag'], f[P + 'ddlHagbu'], f[P + 'ddlSosog'], f[P + 'ddlHagnyeon']) != (dv, hv, sv, y):
                    raise RuntimeError(f'selection drift {dv} {hv} {sv} {y}')
                r = rows(s)
                results.append({'mode': '전공별', 'daehag': [dv, dn], 'hagbu': [hv, hn], 'sosog': [sv, sn], 'grade': y, 'rows': r})
                print(dn, hn, sn, y, len(r), flush=True)
        json.dump(results, open(os.path.join(OUT, 'major.json'), 'w'), ensure_ascii=False)
        json.dump(tree, open(os.path.join(OUT, 'tree.json'), 'w'), ensure_ascii=False, indent=1)

# 영역별
def goto_areas(tries=3):
    global s
    for t in range(tries):
        try:
            s = post(s, P + 'ddlSearchType', ddlSearchType='4')
            check_area_view(s)
            return
        except RuntimeError as e:
            print('retry area view', e, flush=True)
            s = fresh()
    raise RuntimeError('area view failed')

goto_areas()
areas = options(s, P + 'ddlYeong')
area_results = []
for av, an in areas:
    for y in '12345':
        for t in range(3):
            try:
                s = post(s, P + 'btnSearch', ddlSearchType='4', ddlYeong=av, ddlHagnyeon=y)
                check_area_view(s, av, y)
                break
            except RuntimeError as e:
                print('retry area search', av, y, e, flush=True)
                s = fresh(); goto_areas()
        else:
            raise RuntimeError('area search failed')
        r = rows(s)
        area_results.append({'mode': '영역별', 'area': [av, an], 'grade': y, 'rows': r})
        print('영역', an, y, len(r), flush=True)
# Never replace an earlier area.json with a partial or empty crawl.
if len(area_results) != len(areas) * 5 or not areas:
    raise RuntimeError(f'incomplete area crawl {len(area_results)} of {len(areas) * 5}')
json.dump(area_results, open(os.path.join(OUT, 'area.json'), 'w'), ensure_ascii=False)
print('DONE', sum(len(x['rows']) for x in results), sum(len(x['rows']) for x in area_results))
