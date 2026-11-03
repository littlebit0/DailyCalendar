"""Audit published current course plans without retaining contact information."""
import json
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'hansung-public-plans'
OUT.mkdir(exist_ok=True)
BASE = 'https://info.hansung.ac.kr/jsp_21/student/kyomu/'
FIELDS = ['data_year', 'hakgi', 'kwamok', 'kwamokname', 'bunban', 'timeclassroom',
          'daesang', 'offlineyn', 'onlinetype', 'onoffhakjum', 'gita']
FIELDS += [f'j{i}{suffix}' for i in range(1, 16)
           for suffix in ['d', 'f', 'fh', 'bogang1', 'bogang2']]


def main():
    rows = json.loads((ROOT / 'hansung-unique-2026-2.json').read_text())
    errors = []
    for index, row in enumerate(rows, 1):
        target = OUT / f"{row['kwamokcode']}-{row['bunban']}.json"
        if not target.exists():
            code = row['plan'].strip()
            if not code or code == 'x':
                result = {'status': 'notPublished'}
            else:
                req = urllib.request.Request(
                    BASE + 'suupplan_main_view_data.jsp',
                    urllib.parse.urlencode({'type': 'view', 'yearhakgi': '20262',
                                            'code': code}).encode(),
                    headers={'User-Agent': 'Mozilla/5.0',
                             'Referer': BASE + 'suupplan_main_view.jsp?code=' + code})
                try:
                    with urllib.request.urlopen(req, timeout=35) as response:
                        body = response.read()
                    data = json.loads(body.decode('cp949'))
                    result = {'insertYn': data.get('insertYn'),
                              'data': [{key: value.get(key) for key in FIELDS}
                                       for value in data.get('data', [])]}
                except urllib.error.HTTPError as error:
                    if error.code in (401, 403, 429):
                        raise RuntimeError(f'Public access stopped with HTTP {error.code}') from None
                    errors.append({'code': row['kwamokcode'], 'section': row['bunban'],
                                   'error': f'HTTP {error.code}'})
                    result = None
                except (OSError, UnicodeError, ValueError) as error:
                    errors.append({'code': row['kwamokcode'], 'section': row['bunban'],
                                   'error': type(error).__name__})
                    result = None
            if result is not None:
                target.write_text(json.dumps(result, ensure_ascii=False, indent=2))
            time.sleep(.75)
        if index % 100 == 0:
            print(f'Checked {index}/{len(rows)} published course plans; errors {len(errors)}', flush=True)
            (OUT / 'errors.json').write_text(json.dumps(errors, ensure_ascii=False, indent=2))
    (OUT / 'errors.json').write_text(json.dumps(errors, ensure_ascii=False, indent=2))
    print(f'All {len(rows)} public plan checks finished; errors {len(errors)}', flush=True)


if __name__ == '__main__':
    main()
