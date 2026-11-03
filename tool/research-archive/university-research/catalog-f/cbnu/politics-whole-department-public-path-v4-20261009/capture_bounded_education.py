import hashlib
import json
import pathlib
import urllib.request
from html.parser import HTMLParser

class EducationParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables = []
        self.links = []
        self.attachments = []
        self.table = None
        self.row = None
        self.cell = None
        self.anchor = None
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'table':
            self.table = []
        elif tag == 'tr' and self.table is not None:
            self.row = []
        elif tag in ('td', 'th') and self.row is not None:
            self.cell = []
        elif tag == 'a' and attrs.get('href', '').startswith('/post/'):
            self.anchor = {'href': attrs['href'], 'labelParts': []}
        if 'file_download' in attrs.get('onclick', ''):
            self.attachments.append({'publishedAction': attrs['onclick']})
    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)
        if self.anchor is not None:
            self.anchor['labelParts'].append(data)
    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self.cell is not None:
            self.row.append(' '.join(' '.join(self.cell).split()))
            self.cell = None
        elif tag == 'tr' and self.row is not None:
            self.table.append(self.row)
            self.row = None
        elif tag == 'table' and self.table is not None:
            self.tables.append(self.table)
            self.table = None
        elif tag == 'a' and self.anchor is not None:
            self.links.append({'href': self.anchor['href'], 'label': ' '.join(' '.join(self.anchor['labelParts']).split())})
            self.anchor = None

out = pathlib.Path(__file__).resolve().parent
observed = [
    ('undergraduateNoticeList', 'https://politics.chungbuk.ac.kr/board/department_notice'),
    ('currentRegistrationNotice', 'https://politics.chungbuk.ac.kr/post/952'),
    ('currentCurriculum', 'https://politics.chungbuk.ac.kr/department/process'),
]
receipts = []
for kind, url in observed:
    with urllib.request.urlopen(url, timeout=30) as response:
        body = response.read()
        status = response.status
        final = response.url
    assert status == 200 and final.startswith('https://politics.chungbuk.ac.kr/')
    parser = EducationParser()
    parser.feed(body.decode('utf-8'))
    tables = parser.tables
    links = parser.links
    attachments = parser.attachments
    receipt = {'kind': kind, 'sourceUrl': url, 'normalStatus': status,
        'bytes': len(body), 'fullResponseSha256': hashlib.sha256(body).hexdigest(),
        'fullResponseSaved': False, 'educationTablesOnly': tables,
        'observedPublicNoticeAnchors': links, 'observedPublishedAttachments': attachments}
    receipts.append(receipt)
(out / 'politics-public-path-education.json').write_text(json.dumps(receipts, ensure_ascii=False, indent=2) + '\n')
print('PASS bounded normal public paths', len(receipts),
    [(r['kind'], [len(t) for t in r['educationTablesOnly']]) for r in receipts])
