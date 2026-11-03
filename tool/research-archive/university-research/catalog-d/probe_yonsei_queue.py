"""Participate in official anonymous queue; retain all queue values in memory only.

Published netfunnel.js getTidChkEnterProc/chkEnterProc/setComplete are the source.
No school data query occurs before the server explicitly returns code 200.
No bypass, synthetic admission, browser-cookie reuse, or token logging.
"""
import urllib.request
import urllib.parse
import http.cookiejar
import re
import time
import json
import base64
from pathlib import Path

op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
op.addheaders = [('User-Agent', 'Mozilla/5.0')]
op.open('https://underwood1.yonsei.ac.kr/com/lgin/SsoCtr/initExtPageWork.do?link=handbList&locale=ko', timeout=30).read()
host = 'https://nfl.yonsei.ac.kr:443/ts.wseq'

def request(opcode, values):
    params = dict(opcode=str(opcode), nfid='0', prefix=f'NetFunnel.gRtype={opcode};', js='yes')
    params.update(values)
    url = host + '?' + urllib.parse.urlencode(params) + '&' + str(int(time.time() * 1000))
    text = op.open(url, timeout=30).read().decode('utf-8')
    match = re.search(r"result\s*=\s*['\"]([0-9]{4}:[0-9]{3}:[^'\"]*)['\"]", text)
    if not match:
        raise RuntimeError('Unrecognized queue response; no data request will be made')
    typ, code, content = match.group(1).split(':', 2)
    fields = dict(urllib.parse.parse_qsl(content, keep_blank_values=True))
    print('Queue opcode', typ, 'status', code, flush=True)
    return int(code), fields

code, fields = request(5101, dict(sid='service_1', aid='act_2'))
while code == 201:
    ttl = int(fields.get('ttl', '0'))
    if ttl <= 0 or not fields.get('key'):
        raise RuntimeError('Invalid queue poll instruction; stopped')
    time.sleep(min(ttl, 30))
    code, fields = request(5002, dict(key=fields['key'], ttl=str(min(ttl, 30)), sid='service_1', aid='act_2'))
if code != 200:
    raise RuntimeError('Queue admission not granted; no data request will be made')
print('Server granted normal anonymous admission', flush=True)
if not fields.get('key'):
    raise RuntimeError('Granted response missing completion key; stopped')
try:
    # Same public organization request as official handb R(), with queue admission
    # additionally required here before every school request.
    cond = dict(dsNm='dsCampsBusnsCd', level='B', lv1='%', lv2='%', lv3='%',
                sysinstDivCd='%', univGbn='A', syy='2026', smtDivCd='20', findAuthGbn='8')
    body = {'@d1#' + k: str(v) for k, v in cond.items()}
    body.update({'@d#': '@d1#', '@d1#': 'dmCond', '@d1#tp': 'dm'})
    # Public menu/program metadata from anonymous initParameter and the official
    # Submit._encodeMenuId/_encodePgmId arithmetic (not an authentication value).
    menu = (float(105675) * 3 + 46) * 7
    menu = menu * menu * menu + 78
    program = (float(4512) * 5 + 48) * 9
    program = program * program + 782
    body.update(_menuId=base64.b64encode(format(menu, '.0f').encode()).decode(),
                _pgmId=base64.b64encode(format(program, '.0f').encode()).decode(), _menuNm='')
    req = urllib.request.Request(
        'https://underwood1.yonsei.ac.kr/sch/sles/SlescsCtr/findSchSlesHandbList.do',
        data=urllib.parse.urlencode(body).encode(),
        headers={'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
                 'X-Requested-With': 'XMLHttpRequest'})
    with op.open(req, timeout=30) as result:
        data = result.read()
        print('Public response status', result.status, 'content type', result.headers.get('Content-Type'),
              'path', urllib.parse.urlparse(result.url).path, 'bytes', len(data), flush=True)
    try:
        response = json.loads(data)
    except ValueError:
        title = re.search(rb'<title>([^<]*)</title>', data, re.I)
        print('Non JSON response title', title.group(1).decode('utf-8', 'replace') if title else 'none', flush=True)
        raise RuntimeError('Normal admitted query returned non JSON; no further query attempted') from None
    public = {k: v for k, v in response.items() if k.startswith('ds')}
    print('Response keys', list(response), 'metadata success',
          response.get('_METADATA_', {}).get('success'), flush=True)
    metadata = response.get('_METADATA_', {})
    if isinstance(metadata.get('msg'), str) and re.fullmatch(r'[A-Za-z0-9_-]{1,80}', metadata['msg']):
        print('Metadata public error code', metadata['msg'], flush=True)
    print('Public organization response datasets', list(public), flush=True)
    if public:
        (Path(__file__).parent / 'yonsei-public-organizations-probe.json').write_text(
            json.dumps(public, ensure_ascii=False, indent=2))
finally:
    request(5004, dict(key=fields['key']))
