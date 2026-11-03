"""Audit public undergraduate detail rows; never retain sessions or account data."""
from html.parser import HTMLParser
import json
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'postech-public-details'
OUT.mkdir(exist_ok=True)
KEEP = {'강좌명', '영문 강좌명', '학수번호', '분반', '학수번호 + 분반',
        '이수구분', '학과', '강의유형코드', '학점', '이론-실습-학점', '단위',
        '성적부여방법', '수강정원', '대상', '언어', '과목 공유', '공유 과목'}


class Details(HTMLParser):
    def __init__(self):
        super().__init__()
        self.cell = None
        self.kind = None
        self.label = None
        self.data = {}

    def handle_starttag(self, tag, attributes):
        if tag in ('th', 'td'):
            self.cell = []
            self.kind = tag
        elif tag == 'br' and self.cell is not None:
            self.cell.append('\n')

    def handle_data(self, value):
        if self.cell is not None:
            self.cell.append(value)

    def handle_endtag(self, tag):
        if tag in ('th', 'td') and self.cell is not None:
            value = ' '.join(''.join(self.cell).split())
            if self.kind == 'th':
                self.label = value
            elif self.label in KEEP:
                self.data[self.label] = value
            self.cell = None
            self.kind = None
        elif tag == 'tr':
            self.label = None


def main():
    rows = json.loads((ROOT / 'postech-2026-2-undergraduate.json').read_text())
    errors = []
    for index, row in enumerate(rows, 1):
        query = urllib.parse.parse_qs(urllib.parse.urlparse(row['detailUrl']).query)
        identity = query['id'][0]
        target = OUT / (identity + '.json')
        if not target.exists():
            try:
                req = urllib.request.Request(row['detailUrl'], headers={
                    'User-Agent': 'Mozilla/5.0',
                    'Referer': 'https://plms.postech.ac.kr/local/ubion/course/lists.php'})
                with urllib.request.urlopen(req, timeout=40) as response:
                    body = response.read().decode('utf-8')
                parser = Details()
                parser.feed(body)
                if (parser.data.get('학수번호'), parser.data.get('분반')) != (
                        row['code'], row['section']):
                    raise ValueError('Public detail identity mismatch')
                target.write_text(json.dumps(parser.data, ensure_ascii=False, indent=2))
            except urllib.error.HTTPError as error:
                if error.code in (401, 403, 429):
                    raise RuntimeError('Public access stopped') from None
                errors.append({'id': identity, 'error': 'HTTP ' + str(error.code)})
            except (OSError, ValueError) as error:
                errors.append({'id': identity, 'error': type(error).__name__})
            time.sleep(.75)
        if index % 50 == 0:
            (OUT / 'errors.json').write_text(json.dumps(errors, indent=2))
            print(f'Public details {index}/{len(rows)}, errors {len(errors)}', flush=True)
    (OUT / 'errors.json').write_text(json.dumps(errors, indent=2))
    print(f'All {len(rows)} public details checked; errors {len(errors)}', flush=True)


if __name__ == '__main__':
    main()
