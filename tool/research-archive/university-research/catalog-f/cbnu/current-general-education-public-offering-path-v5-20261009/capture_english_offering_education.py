import hashlib
import json
import re
from collections import defaultdict
from html.parser import HTMLParser
from pathlib import Path
from urllib.request import urlopen


OUT = Path(__file__).resolve().parent
BASE = OUT.parent
SOURCE = 'https://fole.chungbuk.ac.kr/post/282'
BASELINE = BASE / 'current-whole-public-path-and-politics-partial-v3-20261009/cbnu-main-2026-2.politics-partial-v3.json'
CLOCK = BASE / 'current-whole-public-path-and-politics-partial-v3-20261009/current-undergraduate-guide-native-clock-fragment.json'
CLOSURES = BASE / 'cbnu-current-closure-education-20261008.json'


class EducationTables(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables = []
        self.table = self.row = self.cell = None

    def handle_starttag(self, tag, attrs):
        if tag == 'table':
            self.table = []
        elif tag == 'tr' and self.table is not None:
            self.row = []
        elif tag in ('td', 'th') and self.row is not None:
            self.cell = []
        elif tag == 'br' and self.cell is not None:
            self.cell.append('\n')

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self.cell is not None:
            self.row.append(''.join(self.cell))
            self.cell = None
        elif tag == 'tr' and self.row is not None:
            self.table.append(self.row)
            self.row = None
        elif tag == 'table' and self.table is not None:
            self.tables.append(self.table)
            self.table = None


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    before = {str(path.relative_to(BASE)): sha(path) for path in (BASELINE, CLOCK, CLOSURES)}
    with urlopen(SOURCE, timeout=30) as response:
        status, url = response.status, response.url
        parser = EducationTables()
        parser.feed(response.read().decode('utf-8'))
    assert status == 200 and url == SOURCE
    tables = parser.tables
    assert len(tables) == 2 and all(len(table) == 17 for table in tables)
    assert all(len(row) == 8 for table in tables for row in table)
    baseline = json.loads(BASELINE.read_text())
    closed = json.loads(CLOSURES.read_text())['closedCourses']
    old_keys = {(row['courseCode'], row['section']) for row in baseline['courses']}
    closed_keys = {(row['courseCode'], row['section']) for row in closed}
    identities = defaultdict(list)
    rows = []
    for table_index, table in enumerate(tables, 1):
        for row_index, raw in enumerate(table[1:], 1):
            values = [' '.join(cell.split()) for cell in raw]
            number, area, field, code, title, section, schedule, level = values
            locator = f'post282/table{table_index}/row{row_index}'
            identities[(code, section)].append(locator)
            runs = []
            for match in re.finditer(r'([월화수목금])\s*(\d{1,2})\s*,\s*(\d{1,2})', schedule):
                day, first, last = match.groups()
                periods = [int(first), int(last)]
                assert all(0 <= period <= 9 for period in periods)
                runs.append({'nativeDay': day, 'nativePeriods': periods,
                             'independentPeriodHH': [{'period': period,
                                 'start': f'{period + 8:02d}:00',
                                 'end': f'{period + 8:02d}:50'} for period in periods]})
            rows.append({'documentLocator': locator, 'rawEducationalCells': raw,
                         'normalizedEducationalCells': values, 'nativeCode': code,
                         'nativeSection': section, 'nativeTitle': title,
                         'nativeArea': area, 'nativeField': field, 'nativeLevel': level,
                         'nativeSchedule': schedule, 'professor': '', 'classroom': '',
                         'professorPublished': False, 'classroomPublished': False,
                         'physicalCampusPublished': False,
                         'nativeIdentityConflicted': True,
                         'clockCorroborationOnly': runs,
                         'weekdayIncomplete': len(runs) != 2})
    assert len(rows) == 32 and len(identities) == 16
    assert all(len(locators) == 2 for locators in identities.values())
    assert len(baseline['courses']) == 14
    assert sum(len(row['schedules']) for row in baseline['courses']) == 555
    assert not set(identities) & old_keys
    assert before == {str(path.relative_to(BASE)): sha(path) for path in (BASELINE, CLOCK, CLOSURES)}
    proof = {
        'sourceUrl': SOURCE, 'normalStatus': status, 'publishedDate': '2026-07-23',
        'nativeHeading': '2026학년도 2학기 개신기초교양영역 영어분야 레벨반 수업시간표 안내',
        'officialObservedPath': ['https://www.cbnu.ac.kr/www/index.do',
                                 'https://fole.chungbuk.ac.kr/', SOURCE],
        'scope': 'Two English level-class tables only, not all general education or undergraduate offerings',
        'tables': tables, 'rows': rows,
        'nativeCodeSectionConflicts': [{'code': code, 'section': section, 'documentLocators': locators}
                                      for (code, section), locators in identities.items()],
        'counts': {'printedRows': 32, 'nativeCodeSectionKeys': 16,
                   'conflictedKeys': 16, 'weekdayIncompleteRows': 1,
                   'missingProfessorRows': 32, 'missingClassroomRows': 32,
                   'newScheduledCandidates': 0,
                   'baselineCoursesUnchanged': 14, 'baselineMeetingsUnchanged': 555},
        'knownClosureJoin': {'nativeKeysMatched': sorted(set(identities) & closed_keys),
                            'exactCodeSectionTitleMatches': [entry for entry in closed
                                if any((entry['courseCode'], entry['section'], entry['courseName']) ==
                                       (row['nativeCode'], row['nativeSection'], row['nativeTitle'])
                                       for row in rows)],
                            'titleConflictMustNotPropagateClosure': True,
                            'source': str(CLOSURES.relative_to(BASE)),
                            'wholeLatestClosureCoverageComplete': False},
        'clockSource': str(CLOCK.relative_to(BASE)),
        'frozenSourceSHA256BeforeAndAfter': before,
        'holdingReason': 'Both different titles print 0913001 with the same 01–16 sections. Do not correct a code by title or merge incompatible schedules. ACTION06 also omits the second weekday. Professor/room absence alone is not the activation gate.',
        'independentValidationPlan': 'Obtain current official offering row resolving native code-section/title collisions and operating scope. Then compare exact native integer periods against cached 2026-2 undergraduate guide; literal date generation must retain own calendar and known closure evidence, prior14 whole equality and all three mode/full Drive restoration. No SDK fixture is claimed now.',
        'noNetworkPathsRetried': ['protected 개신누리', 'attachment361676', 'politics freshman allocation'],
        'completionClaim': False, 'impossibleClaim': False, 'sdkExecuted': False,
    }
    (OUT / 'current-english-level-offering-education-proof.json').write_text(
        json.dumps(proof, ensure_ascii=False, indent=2) + '\n')
    print('PASS: 32 original rows, 16 conflicted keys, baseline14/555 unchanged; new scheduled0')


if __name__ == '__main__':
    main()
