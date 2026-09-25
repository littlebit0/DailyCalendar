#!/usr/bin/env python3
"""Import Dankook's public undergraduate course search without a student login.

The three official search groups (major, general education and foundational)
are fetched separately for each campus and merged by course code/section.
Unknown or absent meeting times remain visible as explicitly unschedulable
courses; no time, room, professor, classification or lecture mode is invented.

Example:
  python3 tool/timetable/import_dankook.py --campus jukjeon --year 2026 \
    --semester 2 --source-dir work/university-expansion --download \
    --fetched-date 2026-09-26 --output assets/timetable/dku-jukjeon-2026-2.json
"""

import argparse
from collections import Counter
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import subprocess
from tempfile import TemporaryDirectory
import time
from urllib.parse import urlencode


BASE = 'https://webinfo.dankook.ac.kr/tiac/univ/lssn/lpci/views/lssnPopup/'
CAMPUS = {'jukjeon': ('1', 'tmtbl.do'), 'cheonan': ('2', 'tmtbl2.do')}
GROUPS = {'major': '1', 'general': '2', 'basic': '3'}
DAYS = '월화수목금토일'
HEADERS = (
    '학년', '이수구분', '교과목번호', '교과목명', '분반', '영어', '학점(설계)',
    '교강사', '요일/교시/강의실', '변경내역', '수업방법및비고', '수업유형', '수강조직',
)
PERIOD_SOURCES = {
    'jukjeon': (
        'https://www.dankook.ac.kr/documents/20118/523334/'
        '2026-2학기%20종합강의시간표%20안내자료(죽전)_0805.pdf/'
        '01393e68-46a9-f866-4e54-7feba0f6e312?version=1.0', 153),
    'cheonan': (
        'https://www.dankook.ac.kr/documents/20118/12232463/'
        '2026학년도%201학기%20종합강의시간표_업로드용260119.pdf/'
        '0ecd0cf2-f64b-5986-a0c2-d01235678d4b?version=13.0', 138),
}


def _cell_text(parts):
    return '\n'.join(
        line for part in ''.join(parts).split('\n')
        if (line := re.sub(r'\s+', ' ', part).strip())
    )


class CourseTableParser(HTMLParser):
    """Keep official line breaks, skip syllabus buttons and private staff IDs."""

    def __init__(self):
        super().__init__()
        self.inside = False
        self.row = None
        self.cell = None
        self.kind = None
        self.skip_anchor = 0
        self.rows = []
        self.headers = []
        self.identities = []
        self.identity = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'table' and attrs.get('id') == 'mjLctTmtblDscTbl':
            self.inside = True
        if not self.inside:
            return
        if tag == 'tr':
            self.row = []
            self.identity = {}
        elif tag in ('td', 'th'):
            self.cell = []
            self.kind = tag
        elif tag == 'a':
            self.skip_anchor += 1
        elif tag in ('br', 'p') and self.cell is not None:
            self.cell.append('\n')
        elif tag == 'input' and attrs.get('name') in ('yy', 'semCd', 'subjId', 'dvclsNb'):
            self.identity[attrs['name']] = attrs.get('value', '')

    def handle_endtag(self, tag):
        if not self.inside:
            return
        if tag == 'a':
            self.skip_anchor -= 1
        elif tag in ('td', 'th') and self.cell is not None:
            text = _cell_text(self.cell)
            if self.kind == 'th':
                self.headers.append(re.sub(r'\s+', '', text))
            else:
                self.row.append(text)
            self.cell = None
        elif tag == 'tr' and self.row:
            self.rows.append(self.row)
            self.identities.append(self.identity)
            self.row = None
        elif tag == 'table':
            self.inside = False

    def handle_data(self, value):
        if self.inside and self.cell is not None and not self.skip_anchor:
            self.cell.append(value)


def parse_table(html, year, semester):
    parser = CourseTableParser()
    parser.feed(html)
    headers = list(parser.headers)
    if len(headers) > 5 and headers[5] == '원어':
        headers[5] = '영어'
    if tuple(headers) not in (HEADERS, (*HEADERS, '주수강조직')):
        raise ValueError(f'Unexpected official table columns: {parser.headers}')
    declared = re.search(r'fc_orange[^>]*>\s*([\d,]+)건', html)
    if declared is None or int(declared[1].replace(',', '')) != len(parser.rows):
        raise ValueError('Official result count does not match parsed rows')
    for row, identity in zip(parser.rows, parser.identities):
        if len(row) != len(headers):
            raise ValueError(f'Unexpected row width: {len(row)}')
        expected = {'yy': str(year), 'semCd': semester, 'subjId': row[2], 'dvclsNb': row[4]}
        if identity != expected:
            raise ValueError(f'Official row belongs to another term/section: {identity}')
    return parser.rows


def period_times(period):
    # Current official undergraduate guides: Jukjeon 2026-2 p. 153 and
    # Cheonan 2026 version 13 p. 138. Daytime 30 minutes;
    # evening 50-minute periods separated by five minutes. Original minutes
    # stay in the imported JSON; the shared grid aligns to 00/30 boundaries.
    if 1 <= period <= 18:
        start = 540 + (period - 1) * 30
        return start, start + 30
    if 19 <= period <= 24:
        start = 1080 + (period - 19) * 55
        return start, start + 50
    raise ValueError(f'Unknown DKU period: {period}')


SCHEDULE = re.compile(r'([월화수목금토일])(\d+(?:~\d+)?(?:,\d+(?:~\d+)?)*)((?:\([^()]*\))?)')


def meeting_times(source):
    compact = re.sub(r'\s+', '', source)
    if not compact or SCHEDULE.sub('', compact):
        raise ValueError(f'Unknown DKU meeting notation: {source}')
    result = []
    for match in SCHEDULE.finditer(compact):
        day, specification, room = match.groups()
        periods = []
        for piece in specification.split(','):
            bounds = [int(value) for value in piece.split('~')]
            if len(bounds) == 2 and bounds[0] > bounds[1]:
                raise ValueError(f'Reversed DKU period range: {piece}')
            periods.extend(range(bounds[0], bounds[-1] + 1))
        if periods != sorted(set(periods)):
            raise ValueError(f'Overlapping DKU period ranges: {specification}')
        previous = None
        last_period = None
        for period in periods:
            start, end = period_times(period)
            if previous is not None and period == last_period + 1:
                previous['endMinute'] = end
            else:
                previous = {'weekday': DAYS.index(day) + 1, 'startMinute': start,
                            'endMinute': end, 'classroom': room[1:-1]}
                result.append(previous)
            last_period = period
    return sorted(result, key=lambda item: (item['weekday'], item['startMinute'], item['endMinute'], item['classroom']))


def source_path(directory, campus, group):
    return Path(directory) / f'dku-{campus}-{group}.html'


def fetch_sources(directory, campus, year, semester):
    Path(directory).mkdir(parents=True, exist_ok=True)
    campus_code, page = CAMPUS[campus]
    endpoint = BASE + page
    with TemporaryDirectory() as temp:
        cookie = str(Path(temp) / 'public-cookies.txt')
        subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location',
                        '--max-time', '40', '--cookie-jar', cookie,
                        '--output', str(Path(temp) / 'entry.html'), endpoint], check=True)
        for group, kind in GROUPS.items():
            time.sleep(.5)
            data = urlencode({'yy': year, 'semCd': semester, 'qrySxn': kind,
                              'lesnPlcCd': campus_code, 'colgCd': '', 'dpmtCd': '',
                              'curiCparCd': '', 'mjSubjKnm': '', 'mjDowCd': '',
                              'grade': '', 'pfltNm': ''})
            subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location',
                            '--max-time', '40', '--cookie', cookie, '--data', data,
                            '--output', str(source_path(directory, campus, group)),
                            endpoint], check=True)


def extract(directory, campus, year, semester, fetched_date):
    courses = {}
    counts = {}
    hashes = {}
    row_statuses = Counter()
    for group in GROUPS:
        path = source_path(directory, campus, group)
        content = path.read_bytes()
        hashes[group] = hashlib.sha256(content).hexdigest()
        rows = parse_table(content.decode('utf-8'), year, semester)
        counts[group] = len(rows)
        for row in rows:
            code, title, section, professor, source_schedule = (row[i] for i in (2, 3, 4, 7, 8))
            if not re.fullmatch(r'\d{6}', code) or not section.isdecimal() or not title:
                raise ValueError(f'Invalid course identity: {code}-{section}')
            credit_match = re.fullmatch(r'(\d*\.?\d+)(?:\(\d*\.?\d+\))?', row[6])
            if credit_match is None:
                raise ValueError(f'Unknown credit notation: {row[6]}')
            credits = float(credit_match[1])
            department = ' / '.join(row[12].splitlines())
            if not department:
                raise ValueError(f'Missing official organization: {code}-{section}')
            remarks = '\n'.join(filter(None, [
                row[10],
                f'원어강의: {row[5]}' if row[5] else '',
                f'변경내역: {row[9]}' if row[9] else '',
                f'수업유형: {row[11]}' if row[11] else '',
                f'주수강조직: {row[13]}' if len(row) == 14 and row[13] else '',
            ]))
            status = 'unscheduled'
            schedules = []
            if source_schedule:
                try:
                    schedules = meeting_times(source_schedule)
                    status = 'scheduled'
                except ValueError:
                    status = 'unrecognized'
            row_statuses[status] += 1
            source_id = f'dku/{campus}/{year}/{semester}/{code}/{int(section)}'
            item = {
                'sourceId': source_id, 'universityId': 'dku', 'campus': campus,
                'academicYear': year, 'semester': semester, 'courseCode': code,
                'courseName': title, 'section': str(int(section)), 'professor': professor,
                'credits': credits, 'schedules': schedules, 'sourceSchedule': source_schedule,
                'scheduleStatus': status,
            }
            if source_id in courses:
                previous = courses[source_id]
                if any(previous[key] != value for key, value in item.items()):
                    raise ValueError(f'Conflicting official section: {source_id}')
                for field, value in [('departmentCredits', credits),
                                     ('departmentClassifications', row[1]),
                                     ('departmentRemarks', remarks)]:
                    if department in previous[field] and previous[field][department] != value:
                        if field != 'departmentRemarks':
                            raise ValueError(f'Conflicting {field} for {source_id}: {department}')
                        # The foundational view also publishes its primary
                        # organization. Keep the union of exact official lines
                        # when the same row appears in another search group.
                        value = '\n'.join(dict.fromkeys(
                            previous[field][department].splitlines() + value.splitlines()))
                    previous[field][department] = value
                if department not in previous['departments']:
                    previous['departments'].append(department)
                if group not in previous['sourceGroups']:
                    previous['sourceGroups'].append(group)
            else:
                item.update(departments=[department], departmentCredits={department: credits},
                            departmentClassifications={department: row[1]},
                            departmentRemarks={department: remarks}, sourceGroups=[group])
                courses[source_id] = item
    return {
        'schemaVersion': 1, 'universityId': 'dku', 'campus': campus,
        'academicYear': year, 'semester': semester,
        'sourceUrl': BASE + CAMPUS[campus][1], 'publishedDate': fetched_date,
        'retrievedDate': fetched_date, 'dateBasis': 'public catalogue retrieved date',
        'periodSourceUrl': PERIOD_SOURCES[campus][0],
        'periodSourcePage': PERIOD_SOURCES[campus][1],
        'sourceRowCount': sum(counts.values()),
        'sourceGroupCounts': counts, 'sourceHashes': hashes,
        'sourceScheduleStatusCounts': dict(row_statuses),
        'courseScheduleStatusCounts': dict(Counter(c['scheduleStatus'] for c in courses.values())),
        'courses': list(courses.values()),
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--campus', choices=CAMPUS, required=True)
    parser.add_argument('--year', type=int, required=True)
    parser.add_argument('--semester', choices=('1', '2', '3', '4'), required=True)
    parser.add_argument('--source-dir', required=True)
    parser.add_argument('--fetched-date', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--download', action='store_true')
    args = parser.parse_args()
    if args.download:
        fetch_sources(args.source_dir, args.campus, args.year, args.semester)
    result = extract(args.source_dir, args.campus, args.year, args.semester, args.fetched_date)
    Path(args.output).write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(args.campus, result['sourceGroupCounts'], 'sections', len(result['courses']),
          result['courseScheduleStatusCounts'])
