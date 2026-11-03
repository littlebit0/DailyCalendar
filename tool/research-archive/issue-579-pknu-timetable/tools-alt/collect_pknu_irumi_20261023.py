"""국립부경대학교 공개 강의계획서 조회(irumi) 직접 조회 — 사용자 결정(2026-10-23)에 따른 robots.txt 차단 경로.

- curl만 사용, 요청 간격 1초 이상, 같은 페이지 반복 금지(실패 시 1회만 재시도 후 기록).
- User-Agent는 일반 브라우저 형식 + DailyCalendar 식별자.
- 로그인·대기열·방화벽 우회 없음. 401/403/429 또는 방화벽 응답이면 즉시 멈춘다.
- 강의계획서 원문(교수 연락처 포함)은 저장하지 않고 학사 필드만 남긴다.
사용: python3 -I collect_pknu_irumi_20261023.py <out_dir> <department_codes.json> [list|syllabus|all]
"""
import json, re, subprocess, sys, time, urllib.parse, xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import escape

UA = ('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/130.0 Safari/537.36 DailyCalendar/1.0 (+https://github.com/littlebit0/DailyCalendar)')
ENTRY = 'https://irumi.pknu.ac.kr/nxui/launch.html?screenid=Desktop_screen_quick&menuId=U020913'
LIST_URL = 'https://irumi.pknu.ac.kr/ezworks/noSessionController'
EMBED = 'https://reporting.pknu.ac.kr/ReportingServer/embed'
SERVICE = 'https://reporting.pknu.ac.kr/ReportingServer/service'
GAP = 1.2
HERE = Path(__file__).parent
out = Path(sys.argv[1]); depts = json.loads(Path(sys.argv[2]).read_text()); mode = sys.argv[3] if len(sys.argv) > 3 else 'all'
jar = out / 'cookies.txt'; log = out / 'requests.log'
last = [0.0]


class Stop(Exception):
    pass


def curl(url, data=None, headers=(), binary=False):
    wait = GAP - (time.time() - last[0])
    if wait > 0:
        time.sleep(wait)
    cmd = ['curl', '-sS', '-m', '60', '-A', UA, '-b', str(jar), '-c', str(jar), '-w', '\n%{http_code}', url]
    for h in headers:
        cmd += ['-H', h]
    if data is not None:
        cmd += ['--data-binary', '@-']
    p = subprocess.run(cmd, input=data.encode() if data is not None else None, capture_output=True)
    last[0] = time.time()
    body, _, code = p.stdout.rpartition(b'\n')
    code = int(code or 0)
    with log.open('a') as f:
        f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} {code} {len(body)} {url}\n")
    if code in (401, 403, 429):
        raise Stop(f'접근/속도 제한 응답 {code}: 우회하지 않고 멈춤')
    if b'Web firewall' in body or b'security policies' in body:
        raise Stop('웹방화벽 응답: 우회하지 않고 멈춤')
    if p.returncode != 0 or code != 200:
        raise RuntimeError(f'curl rc={p.returncode} http={code} {p.stderr[:200]!r}')
    return body


def dataset(name, cols, row=None):
    s = '<Dataset id="' + name + '"><ColumnInfo>' + ''.join('<Column id="' + k + '" type="STRING" size="256"/>' for k in cols) + '</ColumnInfo>'
    if row:
        s += '<Rows><Row>' + ''.join('<Col id="' + k + '">' + escape(str(v)) + '</Col>' for k, v in row.items()) + '</Row></Rows>'
    return s + '</Dataset>'


def list_request(dept):
    args = {'_sqlId': 'LtPdocInq.findLtPdocInq', '_method': 'getList', 'YY': '2026', 'SHTM_CD': 'U0003002', 'UNIV_GRSC_CLSF': '', 'COLG_CD': '',
            'OPEN_SUST_MJ_CD': dept, 'SBJT_NM': '', 'STAFF_NM': '', 'SBJ_FG': ''}
    b = '<?xml version="1.0" encoding="UTF-8"?><Root xmlns="http://www.nexacroplatform.com/platform/dataset"><Parameters>'
    b += ''.join('<Parameter id="' + k + '" type="string">' + escape(v) + '</Parameter>' for k, v in args.items()) + '</Parameters>'
    b += dataset('__DS_TRANS_INFO__', ['strAction', 'strSvcID', 'strURL', 'strInDatasets', 'strOutDatasets'], {'strAction': 'uni', 'strSvcID': 'menu', 'strURL': LIST_URL})
    b += dataset('_gds_userInfo', ['USER_ID'])
    b += dataset('_gdsProgInfo', ['PGM_PATH', 'MENU_ID', 'MENU_NM', 'EVNT_OCCUR_OBJ', 'LOCALE'], {'PGM_PATH': 'uni::cour/open/LtPdocInq.xfdl', 'MENU_ID': 'U020913', 'MENU_NM': '강의계획서조회', 'LOCALE': 'ko_KR'})
    b += dataset('_gdsOpInInfoDs', ['opOriDsNm']) + dataset('_gdsInDsOption', ['strInDatasets', 'datasetOption', 'currentRow']) + '</Root>'
    return b


KO = ['교과목명', '학수번호', '분반', '강의시간', '강의실', '강의형태', '개설학년', '학점-이론-실습']
KO_BOUND = set(KO + ['개설학(부)과', '담당교수', '연구실', '상담시간', '연락처', '이메일', '혁신수업', '핵심역량', '인재상', '전공능력', 'ESG'])
EN = [('교과목명', ['Course Title']), ('학수번호', ['Course', 'Number']), ('분반', ['Class Number']), ('개설학(부)과', ['Department/', 'Division']), ('개설학년', ['Academic', 'Year']),
      ('학점-이론-실습', ['Credit-Lecture-', 'Practice']), ('강의시간', ['Class Time']), ('강의실', ['Classroom']), ('강의형태', ['On/Off-Line', 'Option']), ('_stop', ['Instructor'])]
PRIVATE = re.compile(r'@|\b0\d{1,2}[- ]\d{3,4}[- ]\d{4}\b|상담|연락처|office hours|phone|contact', re.I)


def parse(raw, r, english):
    texts = [e.text or '' for e in ET.fromstring(raw).iter('TL')]
    fields, runs = {}, {}
    if not english:
        for label in KO:
            if label not in texts:
                continue
            vals = []
            for v in texts[texts.index(label) + 1:]:
                if v in KO_BOUND:
                    break
                vals.append(v)
            runs[label] = vals; fields[label] = (', ' if label == '강의실' else ' ').join(vals).strip()
        ev = [t for t in texts if re.search(r'집중수업|수강제한|수강불가|이수불가|(?:\d{1,2}\s*월\s*\d{1,2}\s*일)|(?:\d{1,2}[.]\d{1,2}\s*[(~～-])', t) and not PRIVATE.search(t)]
    else:
        ts = [t.strip() for t in texts]; loc = []
        for key, seq in EN:
            for i in range(len(ts) - len(seq) + 1):
                if ts[i:i + len(seq)] == seq:
                    loc.append((i, key, len(seq))); break
        loc.sort()
        for j, (i, key, n) in enumerate(loc):
            if key == '_stop':
                break
            if j + 1 >= len(loc):
                raise ValueError('영문 학사 머리글 경계 없음')
            vals = texts[i + n:loc[j + 1][0]]; fields[key] = (', ' if key == '강의실' else ' ').join(vals).strip(); runs[key] = vals
        ev = [t for t in texts if re.search(r'intensive|accelerated|block[ -]teaching|prerequisite|restriction|not eligible|only for|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*[ .]+\d{1,2}|20\d{2}[-/.]\d{1,2}[-/.]\d{1,2}', t, re.I) and not PRIVATE.search(t)]
    if fields.get('학수번호') != r['COURSE_NO'] or fields.get('분반') != r['DCLSS_NO']:
        raise ValueError('문서 학수번호·분반 불일치')
    # 원문이 직접 적은 시각(HH:MM)·수업 단위(50/75분)·교시 문구만 남긴다(연락처 줄 제외).
    clock = [t[:300] for t in texts if re.search(r'\d{1,2}\s*:\s*\d{2}|\d{1,2}\s*시\s*\d{0,2}\s*분|\b(?:50|75)\s*분|수업\s*단위|교시|\b(?:50|75)\s*min', t, re.I) and not PRIVATE.search(t)]
    return {'identity': r['COURSE_NO'] + '-' + r['DCLSS_NO'], 'fields': fields, 'fieldTextRuns': runs, 'sourceLanguage': 'en' if english else 'ko',
            'periodRestrictionEvidence': ev, 'clockUnitEvidence': clock, 'verifiedAt': time.strftime('%Y-%m-%dT%H:%M:%S%z'), 'rawBodyStored': False,
            'source': 'irumi 공개 강의계획서 embed + ReportingServer opcode700 (robots.txt 차단 경로를 사용자 결정에 따라 직접 조회)'}


def session_id():
    for line in jar.read_text().splitlines():
        p = line.split('\t')
        if len(p) >= 7 and p[5] == 'JSESSIONID':
            return p[6]
    return ''


def run_list():
    combined, errors = {}, []
    for dept in depts:
        dst = out / 'list' / (dept + '.xml')
        if not dst.exists():
            dst.write_bytes(curl(LIST_URL, list_request(dept), ['Content-Type: text/xml', 'ezclienttype: nexacro17']))
        root = ET.parse(dst); err = root.find('.//{*}Parameter[@id="ErrorCode"]')
        if err is None or err.text != '0':
            errors.append(dept); continue
        for row in root.findall('.//{*}Row'):
            x = {c.attrib['id']: c.text for c in row}
            if x.get('UNIV_GRSC_CLSF') == '학부':
                combined[x['COURSE_NO'] + '-' + x['DCLSS_NO']] = x
    (out / 'latest-rows.json').write_text(json.dumps(list(combined.values()), ensure_ascii=False, indent=1))
    (out / 'list-audit.json').write_text(json.dumps({'departments': len(depts), 'uniqueUndergraduate': len(combined), 'errors': errors,
                                                      'closedY': sorted(k for k, v in combined.items() if v.get('CLS_CLSS_YN') != 'N')}, ensure_ascii=False, indent=1))
    print('LIST', len(combined), 'errors', errors, flush=True)


def run_syllabus():
    rows = json.loads((out / 'latest-rows.json').read_text())
    node = '/Users/kimhwi/.local/node/bin/node'
    dec = subprocess.Popen([node, str(HERE / 'pknu-report-decode-stream.js')], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    enc = lambda x: urllib.parse.quote(urllib.parse.quote(x, safe=''), safe='')
    stats = {}
    try:
        for i, r in enumerate(rows):
            ident = r['COURSE_NO'] + '-' + r['DCLSS_NO']; dst = out / 'syllabus' / (ident + '.json')
            if dst.exists():
                stats['cached'] = stats.get('cached', 0) + 1; continue
            if r.get('KOR_YN') != 'Y' and r.get('ENG_YN') != 'Y':
                dst.write_text(json.dumps({'identity': ident, 'unavailable': True, 'reason': '공개 목록에 국문·영문 강의계획서 버튼 없음'}, ensure_ascii=False))
                stats['notPublished'] = stats.get('notPublished', 0) + 1; continue
            english = r.get('KOR_YN') != 'Y'
            failed = None
            for attempt in range(2):
                try:
                    params = {'YY': '2026', 'SHTM_CD': 'U0003002', 'IN_PARAM': "('%s','%s','%s','%s')" % (r['COURSE_NO'], r['DCLSS_NO'], r['STAFF_NO'], 'U0253002' if english else 'U0253001'),
                              '_CLIENT_USER_INFO': {}, '_PROG_INFO': {'PGM_PATH': 'uni::cour/open/LtPdocInq.xfdl', 'MENU_ID': 'U020913', 'MENU_NM': '강의계획서조회'}}
                    report = {'reportPath': enc('uni/cour/open/LtPdocMngtPrn.mrd'), 'reportParam': enc(json.dumps(params, ensure_ascii=False, separators=(',', ':'))),
                              'reportOption': enc('{"ds":"uni"}'), 'beforeDraw': '', 'afterDraw': '', 'sessionId': session_id()}
                    h = curl(EMBED, urllib.parse.urlencode({'report': json.dumps(report, separators=(',', ':')), 'key': ''}),
                             ['Content-Type: application/x-www-form-urlencoded', 'Referer: ' + ENTRY]).decode('utf-8')
                    a = re.search(r"viewer.openFile\('([^']*)','([^']*)',option\)", h)
                    if not a:
                        raise ValueError('openFile 응답 없음')
                    dec.stdin.write(json.dumps({'path': a[1], 'param': a[2]}) + '\n'); dec.stdin.flush(); d = json.loads(dec.stdout.readline())
                    if d.get('error'):
                        raise ValueError('공개 클라이언트 변환 실패')
                    raw = curl(SERVICE, urllib.parse.urlencode({'opcode': '700', 'mrd_path': d['path'], 'mrd_param': d['param'], 'mrd_plain_param': '', 'mrd_data': '',
                                                               'runtime_param': '', 'mmlVersion': '0', 'protocol': 'sync'}),
                               ['Content-Type: application/x-www-form-urlencoded', 'Referer: ' + ENTRY])
                    dst.write_text(json.dumps(parse(raw, r, english), ensure_ascii=False, indent=1))
                    stats['success'] = stats.get('success', 0) + 1; failed = None; break
                except Stop:
                    raise
                except Exception as e:
                    failed = {'identity': ident, 'type': type(e).__name__, 'message': str(e)[:200], 'attempt': attempt + 1}
                    time.sleep(5)
            if failed:
                (out / 'syllabus' / (ident + '.error.json')).write_text(json.dumps(failed, ensure_ascii=False)); stats['errors'] = stats.get('errors', 0) + 1
            if i % 50 == 0:
                print(json.dumps({'index': i, 'total': len(rows), 'stats': stats}), flush=True)
    finally:
        dec.terminate()
    print('SYLLABUS DONE', json.dumps(stats), flush=True)


if not jar.exists():
    curl(ENTRY)
if mode in ('list', 'all'):
    run_list()
if mode in ('syllabus', 'all'):
    run_syllabus()
