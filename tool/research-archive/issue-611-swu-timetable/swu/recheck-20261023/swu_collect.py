# 서울여대 공식 학부시간표/강의실조회(비로그인) 재수집. robots.txt 확인 불가 호스트를 사용자 결정에 따라 직접 조회.
import json, subprocess, sys, time, urllib.parse, os
OUT = sys.argv[1]
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36 DailyCalendar/1.0 (+https://github.com/littlebit0/DailyCalendar)'
PAGE = 'https://swis.swu.ac.kr/json/ccs/extCcsSOpenSubSearch.xrf'
EX = 'https://swis.swu.ac.kr/ext.ccs.ExtCcsSOpenSubSearch.ex'
CJ = os.path.join(OUT, 'cookies.txt')
last = [0.0]
def wait():
    d = time.time() - last[0]
    if d < 1.2: time.sleep(1.2 - d)
    last[0] = time.time()
def post(params, name):
    wait()
    body = urllib.parse.urlencode(params) + '&'
    path = os.path.join(OUT, 'raw', name + '.json')
    r = subprocess.run(['curl', '-sS', '-m', '60', '-A', UA, '-e', PAGE, '-b', CJ, '-c', CJ, '-X', 'POST',
        '-H', 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8', '-H', 'req-protocol: urlencoded',
        '-H', 'res-protocol: json', '-H', 'eXria-Version: eXria.1.0', '-H', 'req-charset: UTF-8', '-H', 'res-charset: utf-8',
        '--data', body, '-o', path, '-w', '%{http_code}', EX], capture_output=True, text=True)
    if r.stdout != '200': raise SystemExit(f'{name}: HTTP {r.stdout} {r.stderr}')
    return json.load(open(path, encoding='utf-8'))['root']
def rows(v):
    if not isinstance(v, dict): return []
    r = v.get('row', [])
    return r if isinstance(r, list) else [r]
wait(); subprocess.run(['curl', '-sS', '-A', UA, '-c', CJ, '-o', os.path.join(OUT, 'raw', 'page.html'), PAGE], check=True)
init = post({'strCommand': 'onLoad'}, 'onLoad')
year, smt = init['keyDate']['YEAR'], init['keyDate']['SMT']
chk = post({'strCommand': 'chkSchedule', 'strYearRcd': year, 'strSmtRcd': smt}, 'chkSchedule')
combos = []
for code, label in [(x['CD'], x['CD_NM']) for x in rows(init['listCode1'])]:
    if code == 'CCR00101': deps = [x['SA_CD'] for x in rows(init['listNetSa'])]
    elif code == 'CCR00113': deps = [x['SA_CD'] for x in rows(init['listNetConnSa'])]
    elif code == 'CCR00114': deps = [x['SA_CD'] for x in rows(init['listHybirdMajor'])]
    else: deps = ['']
    for dep in deps: combos.append((code, label, dep, ''))
    if code == 'CCR00112':
        for c2 in rows(init['listCode2']): combos.append((code, label, '', c2['CU_CD']))
manifest = {'retrievedAt': time.strftime('%Y-%m-%dT%H:%M:%S%z'), 'year': year, 'smt': smt, 'chk': chk.get('iChkCount'), 'queries': []}
for code, label, dep, c2 in combos:
    res = post({'strCommand': 'list', 'strYearRcd': year, 'strSmtRcd': smt, 'strDivRcd': code, 'strDepCd': dep, 'strCode2': c2},
               f'list-{code}-{dep or "all"}-{c2 or "all"}')
    lst = rows(res.get('openSubList'))
    err = res.get('EXRIAERRMSG')
    manifest['queries'].append({'div': code, 'label': label, 'department': dep, 'code2': c2, 'rows': len(lst), 'err': err})
json.dump(manifest, open(os.path.join(OUT, 'manifest.json'), 'w'), ensure_ascii=False, indent=1)
print(len(combos), sum(q['rows'] for q in manifest['queries']))
