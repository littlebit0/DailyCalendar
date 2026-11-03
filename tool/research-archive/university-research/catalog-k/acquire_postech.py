"""Collect only educational fields from POSTECH's published guest course list."""
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parent
URL = 'https://plms.postech.ac.kr/local/ubion/course/lists.php'
FIELDS = ['code', 'section', 'title', 'classification', 'language', 'schedule',
          'classroom', 'theoryPracticeCredits', 'grading', 'exchangeRecommended',
          'professor']


class CourseTable(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_table = False
        self.row = None
        self.cell = None
        self.link = None
        self.rows = []

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if tag == 'table' and 'table-coursemos' in attrs.get('class', ''):
            self.in_table = True
        if not self.in_table:
            return
        if tag == 'tr':
            self.row = []
            self.link = None
        elif tag == 'td':
            self.cell = []
        elif tag == 'br' and self.cell is not None:
            self.cell.append('\n')
        elif tag == 'a':
            url = urllib.parse.urlparse(attrs.get('href', ''))
            if (url.path.endswith('/lists_view.php') and
                    urllib.parse.parse_qs(url.query).get('id')):
                self.link = attrs['href']

    def handle_data(self, value):
        if self.in_table and self.cell is not None:
            self.cell.append(value)

    def handle_endtag(self, tag):
        if not self.in_table:
            return
        if tag == 'td' and self.cell is not None:
            self.row.append(''.join(self.cell).strip())
            self.cell = None
        elif tag == 'tr' and self.row:
            if len(self.row) != len(FIELDS) or not self.link:
                raise ValueError('Unexpected published course columns')
            self.rows.append({**dict(zip(FIELDS, self.row)), 'detailUrl': self.link})
            self.row = None
        elif tag == 'table':
            self.in_table = False


def page(group, number):
    query = urllib.parse.urlencode({'year': '2026', 'semester': '20',
                                   'groupcode': group, 'page': number})
    req = urllib.request.Request(URL + '?' + query,
                                 headers={'User-Agent': 'Mozilla/5.0',
                                          'Referer': URL})
    with urllib.request.urlopen(req, timeout=40) as response:
        body = response.read().decode('utf-8')
    match = re.search(r'paging-info.*?text-info">(\d+)</span>.*?(\d+) / (\d+)',
                      body, re.S)
    if not match or int(match[2]) != number:
        raise ValueError('Missing actual result count or page identity')
    parser = CourseTable()
    parser.feed(body)
    return int(match[1]), int(match[3]), parser.rows


def main():
    for group, label in [('', 'all'), ('U', 'undergraduate')]:
        count, pages, rows = page(group, 1)
        for number in range(2, pages + 1):
            time.sleep(.5)
            next_count, next_pages, next_rows = page(group, number)
            if (next_count, next_pages) != (count, pages):
                raise ValueError('Public result set changed during pagination')
            rows.extend(next_rows)
        (ROOT / f'postech-2026-2-{label}.json').write_text(
            json.dumps(rows, ensure_ascii=False, indent=2))
        keys = {(row['code'], row['section']) for row in rows}
        identities = {urllib.parse.parse_qs(urllib.parse.urlparse(
            row['detailUrl']).query)['id'][0] for row in rows}
        (ROOT / f'postech-2026-2-{label}-audit.json').write_text(json.dumps({
            'publishedCount': count, 'pages': pages, 'displayRows': len(rows),
            'courseSectionKeys': len(keys), 'publicDetailIds': len(identities),
            'productionActivationComplete': False}, indent=2))
        if len(rows) != count or len(identities) != count:
            raise ValueError('Incomplete or repeated published course identity')
        print(f'{label}: {count} courses, {pages} actual pages, no duplicates',
              flush=True)


if __name__ == '__main__':
    main()
