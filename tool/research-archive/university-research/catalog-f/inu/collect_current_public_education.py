"""Anonymous published whole XLSX: preserve whitelisted educational cells only."""
from pathlib import Path
from collections import Counter
import hashlib
import io
import json
import re
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parent
NOTICE = 'https://www.inu.ac.kr/inu/1516/subview.do?enc=Zm5jdDF8QEB8JTJGYmJzJTJGaW51JTJGMjQ2JTJGNDI3OTkwJTJGYXJ0Y2xWaWV3LmRvJTNG'
TABLE = 'https://www.inu.ac.kr/bbs/inu/246/393179/download.do'
NS = {'x': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
FIELDS = ['대학(원)', '학과(부)', '학년', '이수구분', '이수영역', '학수번호', '교과목명', '교과목명(영문)', '담당교수', '강의실', '시간표(교시)', '시간표(시간)', '교시유형', '학점', '수업구분', '수업유형', '집중이수제', '성적평가', '원어강의', '원어강의구분', '수강대상', '수업방법']

def fetch(url):
    return urllib.request.urlopen(url, timeout=45).read()

def educational_rows(body):
    archive = zipfile.ZipFile(io.BytesIO(body))
    shared = [''.join(i.itertext()) for i in ET.fromstring(archive.read('xl/sharedStrings.xml')).findall('x:si', NS)]
    rows = []
    for item in ET.fromstring(archive.read('xl/worksheets/sheet1.xml')).findall('.//x:row', NS):
        cells = {}
        for cell in item.findall('x:c', NS):
            key = re.sub(r'\d+', '', cell.get('r'))
            v = cell.find('x:v', NS)
            value = v.text if v is not None else ''.join(cell.itertext())
            value = shared[int(value)] if cell.get('t') == 's' and value else value
            cells[key] = value
        rows.append(cells)
    return rows

if __name__ == '__main__':
    notice_body = fetch(NOTICE)
    assert '16차업데이트' in notice_body.decode() and '2026. 9. 4.' in notice_body.decode()
    body = fetch(TABLE)
    rows = educational_rows(body)
    assert rows[0]['A'] == '2026학년도 2학기 종합강의시간표(기준일자: 2026. 9. 4.)'
    headers = rows[1]
    columns = {key: value for key, value in headers.items() if value in FIELDS}
    assert set(columns.values()) == set(FIELDS)
    education = []
    redacted_contacts = 0
    for row in rows[2:]:
        if not row.get('G', '').strip():
            continue
        out = {}
        for column, field in columns.items():
            value = row.get(column, '')
            value, count = re.subn(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|0\d{1,2}[- )]?\d{3,4}[- ]\d{4}', '[연락처 제외]', value)
            redacted_contacts += count
            out[field] = value
        assert re.fullmatch(r'[A-Z0-9]{10}', out['학수번호']), out['학수번호']
        education.append(out)
    assert len(education) == 2437
    source = {'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-09-04', 'noticeUrl': NOTICE, 'noticeSHA256': hashlib.sha256(notice_body).hexdigest(), 'tableUrl': TABLE, 'tableSHA256': hashlib.sha256(body).hexdigest(), 'nativeHeading': rows[0]['A'], 'educationRows': education, 'contactRedactions': redacted_contacts, 'hiddenFieldsSaved': False, 'rawBodySaved': False, 'wholeSourceAcquired': True, 'wholeOperatingVerified': False, 'completionClaim': False}
    path = ROOT / 'inu-current-whole2437-education-20261008.json'
    path.write_text(json.dumps(source, ensure_ascii=False, indent=2) + '\n')
    summary = {'educationSHA256': hashlib.sha256(path.read_bytes()).hexdigest(), 'nativeRows': len(education), 'uniqueNativeCourseIds': len({r['학수번호'] for r in education}), 'fieldCounts': {field: dict(Counter(r[field] for r in education)) for field in ['대학(원)', '수업유형', '수업구분', '집중이수제', '교시유형', '수업방법']}, 'contactRedactions': redacted_contacts}
    (ROOT / 'inu-current-whole2437-field-audit.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    print(summary)
