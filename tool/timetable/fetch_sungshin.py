#!/usr/bin/env python3
"""Fetch Sungshin 2026-2 개설강좌조회 rows from https://sugang.sungshin.ac.kr/findBCRM02010.do.

sugang.sungshin.ac.kr/robots.txt is `Disallow: /`. The page opens without
login (2026-2 수강신청 안내 p8: "로그인하지 않아도 '개설강좌조회' 메뉴에서 …
조회할 수 있음"); it is fetched directly by the user's decision (2026-10-23).
Every request goes through curl only, at least 1.2 s apart, with a browser UA
followed by `DailyCalendar/1.0 (+https://github.com/littlebit0/DailyCalendar)`.
Each data call follows the site's own NetFunnel flow (5101 ticket, 5002
re-check while the server says wait, then 5004 complete); a non-pass result
stops the run. No login, CAPTCHA or queue bypass.

Usage (run on 2026-10-23, outputs kept in work/issue-621-sungshin-timetable/sungshin/):
  fetch_sungshin.py DIR init                       # form code lists -> onload.json
  fetch_sungshin.py DIR query '{...,"sbjMngCd":"USLE001.10"}' mng_10.json
  fetch_sungshin.py DIR query '{...,"objCrsCd":"USSR001.10"}' obj_10.json
  fetch_sungshin.py DIR bydept '{"yy":"2026","semCd":"COMM063.20","orgClsfCd":"COMM075.101"}' bydept_101.json
  fetch_sungshin.py DIR syllabus yy:semCd:orgClsfCd:dptMjrCd:sbjNo:dvcls:empNo ...
DIR must contain ua.txt (the User-Agent line).
"""
import json, re, subprocess, sys, time, os
from urllib.parse import quote, urlencode

D = sys.argv[1]  # data dir
UA = open(os.path.join(D, 'ua.txt')).read().strip()
JAR = os.path.join(D, 'jar.txt')
NF = 'https://nfn.sungshin.ac.kr/ts.wseq'
BASE = 'https://sugang.sungshin.ac.kr'
_last = [0.0]

def curl(args):
    gap = time.time() - _last[0]
    if gap < 1.2:
        time.sleep(1.2 - gap)
    r = subprocess.run(['curl', '-s', '-m', '60', '-A', UA, '-b', JAR, '-c', JAR] + args, capture_output=True)
    _last[0] = time.time()
    return r.stdout.decode('utf-8', 'replace')

def ms():
    return str(int(time.time() * 1000))

def parse(txt):
    m = re.search(r"result='([^']*)'", txt)
    if not m:
        raise SystemExit('NetFunnel 응답 해석 불가: ' + txt[:300])
    res = m.group(1)
    op, code, rest = res.split(':', 2)
    params = dict(p.split('=', 1) for p in rest.split('&') if '=' in p)
    return res, int(code), params

def escape_js(s):
    # JS escape(): 영숫자와 @*_+-./ 외 인코딩
    return quote(s, safe="@*_+-./")

def set_nf_cookie(res):
    lines = [l for l in open(JAR).read().splitlines() if '\tNetFunnel_ID\t' not in l] if os.path.exists(JAR) else ['# Netscape HTTP Cookie File']
    lines.append('\t'.join(['.sungshin.ac.kr', 'TRUE', '/', 'TRUE', '0', 'NetFunnel_ID', escape_js(res)]))
    open(JAR, 'w').write('\n'.join(lines) + '\n')

def ticket():
    txt = curl([f'{NF}?opcode=5101&nfid=0&prefix=NetFunnel.gRtype=5101;&sid=service_3&aid=act_1&js=yes&{ms()}', '-e', BASE + '/'])
    res, code, p = parse(txt)
    while code == 201:  # 대기열: 서버가 준 ttl만큼 기다린 뒤 재확인
        print(f"  대기열 대기 nwait={p.get('nwait')} ttl={p.get('ttl')}", file=sys.stderr)
        time.sleep(max(1, int(p.get('ttl', '1') or 1)))
        txt = curl([f"{NF}?opcode=5002&key={p['key']}&nfid=0&prefix=NetFunnel.gRtype=5002;&ttl={p.get('ttl','1')}&sid=service_3&aid=act_1&js=yes&{ms()}", '-e', BASE + '/'])
        res, code, p = parse(txt)
    if code != 200:
        raise SystemExit(f'NetFunnel 통과 아님(code={code}): {res[:200]} — 중단')
    set_nf_cookie(res)
    return p['key']

def complete(key):
    curl([f'{NF}?opcode=5004&key={key}&nfid=0&prefix=NetFunnel.gRtype=5004;&js=yes&{ms()}', '-e', BASE + '/'])

def action(path, data):
    key = ticket()
    try:
        body = curl(['-X', 'POST', BASE + path, '-e', BASE + '/findBCRM02010.do',
                     '-H', 'Content-Type: application/x-www-form-urlencoded', '-H', 'req-protocol: urlencoded',
                     '-H', 'res-protocol: json', '-H', 'X-Requested-With: XMLHttpRequest', '-H', 'Accept: */*',
                     '--data', urlencode(data)])
    finally:
        complete(key)
    return body

def get_page(path):
    key = ticket()
    try:
        return curl([BASE + path, '-e', BASE + '/findBCRM02010.do'])
    finally:
        complete(key)


def main():
    cmd = sys.argv[2]
    if cmd == 'init':
        curl([BASE + '/', '-o', '/dev/null'])
        curl([BASE + '/findBCRM02010.do', '-e', BASE + '/', '-o', '/dev/null'])
        out = action('/findBCRM02010OnLoad.do', {})
        open(os.path.join(D, 'onload.json'), 'w').write(out)
    elif cmd == 'complete':
        complete(sys.argv[3])
    elif cmd in ('query', 'bydept'):
        path = '/findBCRM02010Main.do' if cmd == 'query' else '/findBCRM02010ByDept.do'
        out = action(path, json.loads(sys.argv[3]))
        open(os.path.join(D, sys.argv[4]), 'w').write(out)
        print(sys.argv[4], len(out))
    elif cmd == 'syllabus':
        for spec in sys.argv[3:]:
            yy, sem, org, dept, sbj, dv, emp = spec.split(':')
            q = urlencode({'yy': yy, 'semCd': sem, 'orgClsfCd': org, 'dptMjrCd': dept,
                           'sbjNo': sbj, 'dvcls': dv, 'empNo': emp})
            out = get_page('/findBCRM02010P01.do?' + q)
            open(os.path.join(D, f'plan_{sbj}_{dv}.html'), 'w').write(out)
            print(sbj, dv, len(out))
    else:
        raise SystemExit('unknown command ' + cmd)


if __name__ == '__main__':
    main()
