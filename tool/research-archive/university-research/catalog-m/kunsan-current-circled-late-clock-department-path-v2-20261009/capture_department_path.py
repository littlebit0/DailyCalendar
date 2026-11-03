import hashlib
from html.parser import HTMLParser
import json
import pathlib
import importlib.util
import re
from urllib.parse import urljoin
import urllib.request

out = pathlib.Path(__file__).resolve().parent
url = 'https://www.kunsan.ac.kr/board/view.kunsan?menuCd=DOM_000013106001000000&boardId=BBS_0001103&dataSid=1384451'
class PublicParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.skip = 0
        self.text = []
        self.links = []
        self.anchor = None
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ('script', 'style'):
            self.skip += 1
        if tag == 'a' and 'download.kunsan' in attrs.get('href', ''):
            self.anchor = {'href': attrs['href'], 'parts': []}
    def handle_data(self, data):
        value = ' '.join(data.split())
        if not self.skip and value:
            self.text.append(value)
            if self.anchor is not None:
                self.anchor['parts'].append(value)
    def handle_endtag(self, tag):
        if tag in ('script', 'style'):
            self.skip = max(0, self.skip - 1)
        if tag == 'a' and self.anchor is not None:
            self.links.append({'url': self.anchor['href'], 'label': ' '.join(self.anchor['parts'])})
            self.anchor = None
with urllib.request.urlopen(url, timeout=40) as response:
    body = response.read()
    status = response.status
    final_url = response.url
parser = PublicParser()
parser.feed(body.decode('utf-8'))
matches = [i for i, value in enumerate(parser.text) if value == '2026년 2학기 수강신청안내']
assert status == 200 and matches
start = next(i for i in range(matches[-1], len(parser.text)) if parser.text[i].startswith('1. 관련:'))
education_intro = parser.text[start:start + 28]
assert not any(re.search(r'\d{2,3}-\d{3,4}-\d{4}|@', line) for line in education_intro)
receipt = {'sourceUrl': url, 'normalStatus': status, 'bytes': len(body),
    'sha256': hashlib.sha256(body).hexdigest(), 'noticeTitle': '2026년 2학기 수강신청안내',
    'publishedDate': '2026-07-16', 'educationalIntro': education_intro,
    'observedPublishedAttachmentLinks': parser.links, 'fullResponseSaved': False}
guide_link = parser.links[0]['url']
assert 'fileSid=187371' in guide_link
guide_url = urljoin(url, guide_link)
with urllib.request.urlopen(guide_url, timeout=40) as response:
    guide = response.read()
    guide_status = response.status
root = out.parents[3]
spec = importlib.util.spec_from_file_location('public_hwp', root / 'work/university-research/catalog-g/read_skku_published_office_plan.py')
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
text = reader.hwp_text(guide)
lines = text.splitlines()
clock_lines = [line.strip() for line in lines if any(token in line for token in ['교시', '수업시간', '강의시간', '09:10', '①', '⑬'])]
clock_start = next(i for i, line in enumerate(lines) if line.strip() == '강의시간 안내')
clock_fragment = lines[clock_start:clock_start + 28]
assert not any(re.search(r'\d{2,3}-\d{3,4}-\d{4}|@', line) for line in clock_lines)
assert not any(re.search(r'\d{2,3}-\d{3,4}-\d{4}|@', line) for line in clock_fragment)
receipt['currentGuide'] = {'sourceUrl': guide_url, 'normalStatus': guide_status,
    'bytes': len(guide), 'sha256': hashlib.sha256(guide).hexdigest(),
    'nativeClockAndCircledMarkerParagraphs': clock_lines,
    'nativeDocumentOpeningEducationLines': lines[:12],
    'nativeClockEducationFragment': clock_fragment,
    'circledPeriodSymbolsPresentInReadableText': sorted(set(text) & set('①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬')),
    'fullDocumentSaved': False}
(out/'current-science-registration-guide-education.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(receipt['currentGuide'],ensure_ascii=False))
