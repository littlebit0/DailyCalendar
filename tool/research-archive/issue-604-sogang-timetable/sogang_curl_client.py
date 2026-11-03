"""서강대 공개 개설교과목 조회(SAP WebDynpro)를 curl로만 조회한다. 로그인 없음, 요청 간격 1초 이상."""
import hashlib, html, json, re, subprocess, sys, time, urllib.parse
from pathlib import Path

ENTRY = 'https://sis109.sogang.ac.kr/sap/bc/webdynpro/sap/zcmw9016?sap-language=KO'
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36 DailyCalendar/1.0 (+https://github.com/littlebit0/DailyCalendar)'
FIELDS = ['year','semester','division','department','subjectCode','section','title','syllabus','credit','meetingText','hours','professor','enrollment','english','chinese','approval','CU','HUSS','CI','oddEven','international','honors','cyber','exam','target','recommendedGrade','registrationRemarks','description','remarks']
SOURCE_LABELS = ['학년도','학기','소속','학과','과목번호','분반','과목명','강의계획서','학점','수업시간/강의실','시간','교수진','수강생수','영어강의','중국어강의','승인과목','CU','HUSS','CI','홀짝구분','국제학생','Honors','사이버강의','시험일자','수강대상','권장학년','수강신청 참조사항','과목 설명','비고']


def rendered(response):
    parts = re.findall(r'<!\[CDATA\[(.*?)\]\]>', response, re.S)
    return '\n'.join(parts) if parts else response


def rows(response):
    result = []
    content = rendered(response)
    clean = lambda v: re.sub(r'\s+', ' ', html.unescape(re.sub('<[^>]+>', ' ', v)).replace('\xa0', ' ')).strip()
    headers = [clean(v) for v in re.findall(r'<th\b[^>]*role="columnheader"[^>]*>(.*?)</th>', content, re.S)]
    if not headers:
        return []
    mapping = dict(zip(SOURCE_LABELS, FIELDS))
    if len(headers) != len(set(headers)) or any(h not in mapping for h in headers):
        raise ValueError('Unrecognized public table headers: %r' % headers)
    fields = [mapping[h] for h in headers]
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>', content, re.S):
        cells = re.findall(r'<td\b[^>]*role="gridcell"[^>]*>(.*?)</td>', row, re.S)
        if len(cells) != len(fields):
            continue
        values = [html.unescape(re.sub('<[^>]+>', ' ', c)).replace('\xa0', ' ').strip() for c in cells]
        record = dict(zip(fields, values))
        if not re.fullmatch(r'[A-Z]+\d+', record.get('subjectCode', '')):
            continue
        record.pop('enrollment', None)
        record.pop('syllabus', None)
        plan_cell = cells[fields.index('syllabus')] if 'syllabus' in fields else ''
        button = re.search(r'<div\b[^>]*id="([^"]+)"[^>]*role="button"', plan_cell)
        result.append((record, button.group(1) if button else None))
    return result


class CurlClient:
    def __init__(self, jar):
        self.jar = str(jar)
        Path(self.jar).write_text('')
        self.action = ENTRY
        self.data = {}
        self.response = ''
        self.last = 0.0
        self.count = 0
        self._request(ENTRY)
        self.events([('LoadingPlaceHolder', 'Load', {'Id': '_loadingPlaceholder_'})])

    def _wait(self):
        delay = 1.1 - (time.monotonic() - self.last)
        if delay > 0:
            time.sleep(delay)
        self.last = time.monotonic()
        self.count += 1

    def _curl(self, url, payload=None, extra=(), max_bytes=32000000):
        self._wait()
        cmd = ['curl', '-sS', '--fail-with-body', '-m', '60', '--max-filesize', str(max_bytes), '-A', UA,
               '-b', self.jar, '-c', self.jar, '-H', 'Accept-Language: ko-KR,ko;q=0.9',
               '-H', 'Accept: text/html,application/xml,*/*', '-e', ENTRY, *extra]
        if payload is not None:
            cmd += ['-H', 'Origin: https://sis109.sogang.ac.kr', '-H', 'X-Requested-With: XMLHttpRequest',
                    '-H', 'X-XHR-Logon: accept', '-H', 'Content-Type: application/x-www-form-urlencoded',
                    '--data-binary', '@-']
        cmd.append(url)
        out = subprocess.run(cmd, input=payload, capture_output=True, timeout=90)
        if out.returncode != 0:
            raise RuntimeError('curl failed %s: %s %r' % (out.returncode, out.stderr.decode()[:300], out.stdout[:300]))
        return out.stdout

    def _request(self, url, payload=None):
        text = self._curl(url, payload).decode('utf-8')
        if any(m in text.lower() for m in ('access denied', 'web application firewall', 'too many requests')):
            raise ValueError('Protection response; stop collection')
        self.response = text
        form = re.search(r'<form\b[^>]*action="([^"]+)"[^>]*>(.*?)</form>', text, re.S) or \
            re.search(r'<form\b[^>]*action="([^"]+)"[^>]*>(.*?)</form>', rendered(text), re.S)
        if form:
            self.action = urllib.parse.urljoin(ENTRY, html.unescape(form.group(1)))
            self.data = {html.unescape(n): html.unescape(v) for n, v in re.findall(r'name="([^"]+)" value="([^"]*)"', form.group(2))}
        return text

    def events(self, events):
        queue = ''.join(c + '_' + e + '' + ''.join(k + '' + str(v) for k, v in p.items()) + '' for c, e, p in events)
        queue += 'ResponseDatadeltaClientActionsubmit'
        self.data['SAPEVENTQUEUE'] = ''.join(ch if ch.isascii() and (ch.isalnum() or ch in '-_.') else '~' + format(ord(ch), '04X') for ch in queue)
        return self._request(self.action, urllib.parse.urlencode(self.data).encode())

    def whole(self):
        self.events([('ComboBox', 'Select', {'Id': 'WD88', 'Key': '30000002', 'ByEnter': 'false'})])
        return rows(self.events([('Button', 'Press', {'Id': 'WDCA'})]))

    def course(self, code):
        if not getattr(self, 'code_mode', False):
            self.events([('RadioButton', 'Change', {'Id': 'WD6C', 'Checked': 'true'})])
            self.code_mode = True
        self.events([('InputField', 'Change', {'Id': 'WD7D', 'Value': code})])
        return rows(self.events([('Button', 'Press', {'Id': 'WDCA'})]))

    def close_plan(self):
        buttons = [m.group(1) for m in re.finditer(r'<div[^>]*id="([^"]+)"[^>]*role="button"[^>]*>(.*?)</div>', rendered(self.response), re.S)
                   if re.sub(r'\s+', ' ', html.unescape(re.sub('<[^>]+>', ' ', m.group(2)))).strip() == '확인 강조']
        if len(buttons) != 1:
            raise ValueError('modal close button not identified')
        self.events([('Button', 'Press', {'Id': buttons[0]})])

    def plan_pdf(self, button):
        response = self.events([('Button', 'Press', {'Id': button})])
        links = [html.unescape(v) for v in re.findall(r'href="([^"]+)"', rendered(response))]
        links = [v for v in links if urllib.parse.urlsplit(v).hostname == 'sis139.sogang.ac.kr' and urllib.parse.urlsplit(v).path == '/ContentServer/ContentServer.dll']
        if len(links) != 1:
            return None, 'public document link not uniquely identified'
        content = self._curl(links[0], max_bytes=12000000)
        if not content.startswith(b'%PDF-'):
            return None, 'public plan was not a PDF'
        return content, None
