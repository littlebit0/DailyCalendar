import hashlib
import json
from html.parser import HTMLParser
from pathlib import Path
from urllib.request import urlopen

OUT = Path(__file__).resolve().parent
BASE = OUT.parent
URL = 'https://fole.chungbuk.ac.kr/board/hb1?category_id=2&findex='
BASELINE = BASE / 'current-whole-public-path-and-politics-partial-v3-20261009/cbnu-main-2026-2.politics-partial-v3.json'


class NoticeRows(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows = []
        self.row = self.cell = None
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag == 'tr':
            self.row = []
            self.links = []
        elif tag in ('td', 'th') and self.row is not None:
            self.cell = []
        elif tag == 'a' and self.row is not None:
            href = dict(attrs).get('href', '')
            if '/post/' in href:
                self.links.append(href)

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self.cell is not None:
            self.row.append(' '.join(''.join(self.cell).split()))
            self.cell = None
        elif tag == 'tr' and self.row is not None:
            if self.links:
                self.rows.append({'nativeListCells': self.row, 'observedPostLinks': self.links})
            self.row = None


def main():
    original = hashlib.sha256(BASELINE.read_bytes()).hexdigest()
    with urlopen(URL, timeout=30) as response:
        status = response.status
        parser = NoticeRows()
        parser.feed(response.read().decode('utf-8'))
    assert status == 200 and parser.rows
    baseline = json.loads(BASELINE.read_text())
    assert len(baseline['courses']) == 14
    assert sum(len(row['schedules']) for row in baseline['courses']) == 555
    assert original == hashlib.sha256(BASELINE.read_bytes()).hexdigest()
    proof = {
        'sourceUrl': URL, 'normalStatus': status,
        'officialVisibleChain': ['https://fole.chungbuk.ac.kr/',
                                 'https://fole.chungbuk.ac.kr/board/hb1', URL],
        'observedFirstPageNoticeRows': parser.rows,
        'scope': 'Actual current category 교양교육 first page, pinned plus ordinary notice rows. Not an exhaustive board or offered-course census.',
        'newNonEnglishRegularTimetablePostObserved': False,
        'decisions': [
            'Current non-English ordinary notices show AI-use guidance and general-education contests, not actual offered sections.',
            '2026-2 스피치 특강 is explicitly 비교과센터 participant recruitment; its title is not regular undergraduate course identity.',
            'Pinned RC activity, writing consultation and discussion notices are not adopted as native section timetables.',
            'The only visible current2term regular timetable title is the already frozen English post282; it was not reopened.',
            'Curriculum credits and course introduction contests do not supply an actual current offered section.',
            'The observed first-page ordinary list reaches February26 2026; older pages were not expanded into a broad query loop.'
        ],
        'webReaderCacheDifference': 'Menu click showed2025 category snapshot and September2026 unfiltered snapshot; normal public HTTP200 category response instead exposes current October8 2026 AI guidance. Cached old rows were not treated as current scope.',
        'notRefetched': ['post282', 'post295', 'guide361676', 'politics freshman allocation', 'known65 closures', 'protected 개신누리'],
        'baselineWholeObjectSHA256BeforeAndAfter': original,
        'baselineCourses': 14, 'baselineMeetings': 555,
        'newScheduledCandidates': 0, 'newOfferingEducationRows': 0,
        'remainingEvidence': 'A current non-English actual offered-row document with native code-section/day-period and source operating scope remains unobserved in this bounded public category path. Whole catalog and latest closures remain unverified.',
        'completionClaim': False, 'impossibleClaim': False, 'sdkExecuted': False
    }
    (OUT / 'non-english-current-notice-scope-education-proof.json').write_text(
        json.dumps(proof, ensure_ascii=False, indent=2) + '\n')
    print(f'PASS: {len(parser.rows)} current public notice rows; new offering0; baseline14/555 SHA unchanged')


if __name__ == '__main__':
    main()
