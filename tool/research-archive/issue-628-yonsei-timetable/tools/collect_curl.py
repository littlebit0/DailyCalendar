"""연세 handbList 공개(비로그인) 강의계획서 조회를 curl로 다시 받는다 (2026-10-23).
사용자 결정(ALT_SOURCE_BRIEF 4번): robots.txt 확인 불가(302) 경로를 직접 조회.
- 요청 간격 1.1초 이상, 같은 범위 반복 없음(이미 받은 파일은 건너뜀).
- 공식 NetFunnel 대기열에 정상 참여(5101 진입, 201이면 서버가 준 TTL만큼 대기, 200일 때만 조회, 조회 후 5004 완료). 우회 없음.
- 대기열 키·쿠키 값은 기록하지 않는다.
"""
import base64, json, re, subprocess, sys, time, urllib.parse
from pathlib import Path

OUT = Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
JAR = OUT.parent / 'tools' / '.cookies'  # 공개 진입 페이지가 준 세션 쿠키(로그인 아님)
UA = ('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/130.0 Safari/537.36 DailyCalendar/1.0 (+https://github.com/littlebit0/DailyCalendar)')
BASE = 'https://underwood1.yonsei.ac.kr'
last = [0.0]

def curl(url, data=None, headers=()):
    wait = 1.1 - (time.time() - last[0])
    if wait > 0: time.sleep(wait)
    cmd = ['curl', '-sS', '--fail-with-body', '--max-time', '60', '-A', UA, '-b', str(JAR), '-c', str(JAR)]
    for h in headers: cmd += ['-H', h]
    if data is not None: cmd += ['--data-raw', data]
    cmd.append(url)
    r = subprocess.run(cmd, capture_output=True)
    last[0] = time.time()
    if r.returncode != 0: raise RuntimeError(f'curl failed {r.returncode}: {r.stderr.decode()[:200]}')
    return r.stdout

def queue(opcode, values):
    params = dict(opcode=str(opcode), nfid='0', prefix=f'NetFunnel.gRtype={opcode};', js='yes')
    params.update(values)
    text = curl('https://nfl.yonsei.ac.kr:443/ts.wseq?' + urllib.parse.urlencode(params) + '&' + str(int(time.time()*1000))).decode()
    m = re.search(r"result\s*=\s*['\"]([0-9]{4}:[0-9]{3}:[^'\"]*)['\"]", text)
    if not m: raise RuntimeError('Unrecognized queue response; stopped')
    _, code, value = m.group(1).split(':', 2)
    return int(code), dict(urllib.parse.parse_qsl(value, keep_blank_values=True))

menu = (float(105675)*3+46)*7; menu = menu*menu*menu+78
pgm = (float(4512)*5+48)*9; pgm = pgm*pgm+782
META = dict(_menuId=base64.b64encode(format(menu, '.0f').encode()).decode(),
            _pgmId=base64.b64encode(format(pgm, '.0f').encode()).decode(), _menuNm='')

def form(path, cond):
    code, f = queue(5101, dict(sid='service_1', aid='act_2'))
    while code == 201:
        ttl = int(f.get('ttl', '0'))
        if ttl <= 0 or not f.get('key'): raise RuntimeError('Invalid queue instructions')
        time.sleep(min(ttl, 30))
        code, f = queue(5002, dict(key=f['key'], ttl=str(min(ttl, 30)), sid='service_1', aid='act_2'))
    if code != 200 or not f.get('key'): raise RuntimeError(f'Queue did not admit request ({code}); stopped')
    try:
        data = {'@d1#'+k: str(v) for k, v in cond.items()}
        data.update({'@d#': '@d1#', '@d1#': 'dmCond', '@d1#tp': 'dm'}); data.update(META)
        obj = json.loads(curl(BASE+path, urllib.parse.urlencode(data),
            ['Content-Type: application/x-www-form-urlencoded; charset=UTF-8', 'X-Requested-With: XMLHttpRequest']))
        if obj.get('_METADATA_', {}).get('success') is False: raise RuntimeError('unsuccessful metadata')
        return {k: v for k, v in obj.items() if k.startswith('ds')}
    finally:
        if queue(5004, dict(key=f['key']))[0] != 200: raise RuntimeError('Queue completion unsuccessful')

def org(ds, campus='%', college='%'):
    p = OUT / f'org-{ds}-{campus}-{college}.json'
    if p.exists(): return json.loads(p.read_text())
    rows = form('/sch/sles/SlescsCtr/findSchSlesHandbList.do', dict(dsNm=ds, level='B', lv1=campus, lv2=college, lv3='%',
        sysinstDivCd='%', univGbn='A', syy='2026', smtDivCd='20', findAuthGbn='8')).get(ds, [])
    p.write_text(json.dumps(rows, ensure_ascii=False, indent=1)); return rows

curl(BASE + '/com/lgin/SsoCtr/initExtPageWork.do?link=handbList&locale=ko')
camps = org('dsCampsBusnsCd')
print('affiliations', [(c.get('deptCd'), c.get('deptNm')) for c in camps], flush=True)
scope = []
for campus in ['s1', 's2', 's7', 's8']:
    for college in org('dsUnivCd', campus):
        cc = college['deptCd']
        depts = org('dsFaclyCd', campus, cc) if cc != campus else []
        for dept in depts or [dict(deptCd='', deptNm='전체')]:
            dc = dept['deptCd']; target = OUT / f'{campus}-{cc}-{dc or "all"}.json'
            if target.exists(): rows = json.loads(target.read_text())['dsSles251']
            else:
                c = {k: '' for k in ['hy', 'cdt', 'kwdDivCd', 'kwd', 'allKwd', 'engChg', 'campsDivCd', 'stuno']}
                c.update(syy='2026', smtDivCd='20', campsBusnsCd=campus, univCd=cc, faclyCd=dc, searchGbn='1', prnGbn='false', lang='ko')
                obj = form('/sch/sles/SlessyCtr/findAtnlcHandbList.do', c)
                if 'dsSles251' not in obj: raise RuntimeError('Missing catalog dataset')
                rows = obj['dsSles251']; target.write_text(json.dumps(obj, ensure_ascii=False, indent=1))
            scope.append(dict(campus=campus, college=college['deptNm'], collegeCode=cc, department=dept['deptNm'],
                              departmentCode=dc, count=len(rows), capped=len(rows) >= 200))
            print(campus, cc, dc, len(rows), 'CAPPED' if len(rows) >= 200 else '', flush=True)
(OUT / 'scopes.json').write_text(json.dumps(scope, ensure_ascii=False, indent=1))
print('DONE scopes', len(scope), 'rows', sum(s['count'] for s in scope), 'capped', sum(s['capped'] for s in scope), flush=True)
