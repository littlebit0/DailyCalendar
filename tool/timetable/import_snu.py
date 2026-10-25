#!/usr/bin/env python3
"""Import the official, public SNU undergraduate course catalog, page by page.

Only public search is used. No account, enrollment or authenticated requests.
The published total must match unique records before writing a catalog.
"""
import argparse
from html.parser import HTMLParser
import json
import math
from pathlib import Path
import re
import subprocess
import time
from urllib.parse import urlencode

URL = 'https://shine.snu.ac.kr/uni/sugang/cc/cc100.action'


class TableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.table_depth = 0
        self.row = None
        self.cell = None
        self.identity = None
        self.rows = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'table':
            self.table_depth += 1
        if tag == 'tr':
            self.row = []
            self.identity = {}
        if tag == 'td' and self.row is not None:
            self.cell = []
        if tag == 'input' and self.identity is not None and attrs.get('name') in ('openSchyy', 'openShtmFg', 'openDetaShtmFg', 'sbjtCd', 'ltNo'):
            self.identity[attrs['name']] = attrs.get('value')
        if tag == 'br' and self.cell is not None:
            self.cell.append('\n')

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag == 'td' and self.cell is not None:
            self.row.append(re.sub(r'[\t\r ]+', ' ', ''.join(self.cell)).strip())
            self.cell = None
        elif tag == 'tr' and self.row is not None:
            self.rows.append((self.identity, self.row))
            self.row = None
            self.identity = None
        elif tag == 'table':
            self.table_depth -= 1


def parse_page(body, year, semester):
    total = re.search(r'검색건수\s*<span[^>]*>([\d,]+)</span>건', body)
    if not total:
        raise ValueError('Missing official SNU result count')
    parser = TableParser()
    parser.feed(body)
    courses = []
    current = None
    for identity, cells in parser.rows:
        if identity and 'sbjtCd' in identity:
            if len(cells) != 16 or identity['openSchyy'] != str(year) or identity['openShtmFg'] != f'U00020000{semester}' or identity['openDetaShtmFg'] != 'U000300001':
                raise ValueError('Unexpected SNU course row/term')
            department = ' / '.join(cells[1:3])
            credits = float(cells[7].split('-')[0])
            current = {
                'sourceId': f"snu/main/{year}/{semester}/{identity['sbjtCd']}/{identity['ltNo']}",
                'universityId': 'snu', 'campus': 'main', 'academicYear': year, 'semester': str(semester),
                'courseCode': identity['sbjtCd'], 'section': identity['ltNo'],
                'courseName': cells[6], 'professor': cells[11], 'credits': credits,
                'departments': [department], 'departmentCredits': {department: credits},
                'departmentClassifications': {department: cells[0]},
                'departmentRemarks': {department: cells[15]},
                'schedules': [], 'sourceSchedule': '', 'sourceClassroom': '',
                '_meetings': [],
            }
            if not current['courseName'] or cells[4] != identity['sbjtCd'] or cells[5] != identity['ltNo']:
                raise ValueError('Invalid SNU identity')
            current['_meetings'].append(cells[8:11])
            courses.append(current)
        elif current is not None and len(cells) == 3:
            current['_meetings'].append(cells)
        else:
            current = None
    for course in courses:
        meetings = course.pop('_meetings')
        course['sourceSchedule'] = '\n'.join(m[0] for m in meetings)
        course['sourceClassroom'] = '\n'.join(m[2] for m in meetings)
        statuses = []
        for schedule, mode, room in meetings:
            match = re.fullmatch(r'([월화수목금토일])\((\d{2}):(\d{2})~(\d{2}):(\d{2})\)', schedule)
            if not match:
                statuses.append('unscheduled' if not schedule else 'unparsed')
                continue
            start = int(match[2]) * 60 + int(match[3])
            end = int(match[4]) * 60 + int(match[5])
            if int(match[3]) > 59 or int(match[5]) > 59 or start < 0 or end > 1440 or end <= start:
                raise ValueError('Invalid SNU meeting time')
            course['schedules'].append({'weekday': '월화수목금토일'.index(match[1]) + 1, 'startMinute': start, 'endMinute': end, 'classroom': room})
            statuses.append('scheduled')
        course['scheduleStatus'] = 'scheduled' if all(s == 'scheduled' for s in statuses) else 'unparsed' if 'unparsed' in statuses else 'unscheduled'
        # Never let a partially parsed meeting silently create an incomplete schedule.
        if course['scheduleStatus'] != 'scheduled':
            course['schedules'] = []
        else:
            course['schedules'] = merge_adjacent(course['schedules'])
    return int(total[1].replace(',', '')), courses


def merge_adjacent(schedules):
    """Merge same-day, same-room meetings whose gap is under 60 minutes (class + break)."""
    merged = []
    for row in sorted(schedules, key=lambda r: (r['weekday'], r['classroom'], r['startMinute'])):
        previous = next((m for m in merged if m['weekday'] == row['weekday'] and m['classroom'] == row['classroom']
                         and row['startMinute'] - m['endMinute'] < 60 and m['startMinute'] <= row['startMinute']), None)
        if previous:
            previous['endMinute'] = max(previous['endMinute'], row['endMinute'])
        elif row not in merged:
            merged.append(dict(row))
    order = {id(m): min(i for i, r in enumerate(schedules) if r['weekday'] == m['weekday'] and r['classroom'] == m['classroom'] and r['startMinute'] == m['startMinute']) for m in merged}
    return sorted(merged, key=lambda m: order[id(m)])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--year', type=int, required=True)
    ap.add_argument('--semester', type=int, choices=(1, 2), required=True)
    ap.add_argument('--source-dir', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--fetched-date', required=True)
    ap.add_argument('--download', action='store_true')
    args = ap.parse_args()
    args.source_dir.mkdir(parents=True, exist_ok=True)
    all_courses = {}
    total = None
    page = 1
    while total is None or page <= math.ceil(total / 10):
        path = args.source_dir / f'snu-{args.year}-{args.semester}-{page:04d}.html'
        if args.download and not path.exists():
            data = urlencode({'srchCond': '1', 'pageNo': page, 'workType': 'S', 'srchOpenSchyy': args.year,
                'srchOpenShtm': f'U00020000{args.semester}U000300001', 'srchCptnCorsFg': 'C013300001'})
            subprocess.run(['curl', '-fsS', '--max-time', '30', '--retry', '2', '--retry-delay', '2', URL, '--data', data, '-o', str(path)], check=True)
            time.sleep(0.5)
        count, courses = parse_page(path.read_text(), args.year, args.semester)
        if total is None:
            total = count
        if total != count or len(courses) != min(10, total - (page - 1) * 10):
            raise ValueError('SNU count changed or incomplete page')
        for course in courses:
            if course['sourceId'] in all_courses:
                raise ValueError('Repeated SNU course/page')
            all_courses[course['sourceId']] = course
        if page == 1 or page % 25 == 0:
            print(f'Page {page}: {len(all_courses)}/{total} verified courses', flush=True)
        page += 1
    if not total or len(all_courses) != total:
        raise ValueError('Incomplete SNU catalog')
    result = {'schemaVersion': 1, 'universityId': 'snu', 'campus': 'main', 'academicYear': args.year,
        'semester': str(args.semester), 'publishedDate': args.fetched_date, 'sourceUrl': URL,
        'courses': list(all_courses.values())}
    args.output.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(f'Complete: {total} SNU undergraduate courses', flush=True)


if __name__ == '__main__':
    main()
