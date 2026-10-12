#!/usr/bin/env python3
"""Import Ajou's official public undergraduate course-plan search.

Uses public.html's normal session and read-only nt/cvt.do requests. No student
login, enrollment, write endpoint or retained session credentials are used.
"""
import argparse
import hashlib
from decimal import Decimal
import json
from pathlib import Path
import re
import subprocess
from tempfile import TemporaryDirectory
import time

BASE = 'https://mhaksa.ajou.ac.kr:30443'
GROUPS = ['U0209001', 'U0209002', 'U0209003', 'U0209004', 'U0209005', 'U0209007', 'U0209029']
# Official class-hour reference (2026-2):
# https://help.ajou.ac.kr/gs/community/notice.do?articleNo=372627&mode=view
# Additional symbols are kept unparsed until their published bounds are verified.
LETTER_PERIODS = {letter: (540 + index * 90, 615 + index * 90) for index, letter in enumerate('ABCDEFGH')}
TERM_CODES = {'1': 'U0002001', '여름': 'U0002002', '2': 'U0002003', '겨울': 'U0002004'}


def meetings(text):
    if not text.strip():
        return [], 'unscheduled'
    result = []
    cursor = 0
    for match in re.finditer(r'([월화수목금토일])(\d{2}:\d{2}~\d{2}:\d{2}|[A-H]|\d{1,2}(?:\.5)?)\s*(?:\(([^()]*)\))?', text):
        if text[cursor:match.start()].strip():
            return [], 'unparsed'
        cursor = match.end()
        period = match[2].strip()
        if period in LETTER_PERIODS:
            start, end = LETTER_PERIODS[period]
        elif re.fullmatch(r'\d{1,2}(?:\.5)?', period):
            start = 540 + int((Decimal(period) - 1) * 60)
            end = start + 50
        elif (times := re.fullmatch(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})', period)):
            if int(times[2]) > 59 or int(times[4]) > 59:
                raise ValueError('Invalid Ajou clock minute')
            start = int(times[1]) * 60 + int(times[2])
            end = int(times[3]) * 60 + int(times[4])
        else:
            return [], 'unparsed'
        if not (0 <= start < end <= 1440):
            raise ValueError('Invalid Ajou meeting interval')
        result.append({'weekday': '월화수목금토일'.index(match[1]) + 1, 'startMinute': start, 'endMinute': end, 'classroom': match[3] or ''})
    if cursor != len(text.rstrip()) or not result:
        return [], 'unparsed'
    # Merge adjacent numeric periods while preserving the official classroom.
    merged = []
    for row in sorted(result, key=lambda r: (r['weekday'], r['startMinute'], r['classroom'])):
        previous = merged[-1] if merged else None
        if previous and previous['weekday'] == row['weekday'] and previous['classroom'] == row['classroom'] and previous['endMinute'] <= row['startMinute'] <= previous['endMinute'] + 10:
            previous['endMinute'] = row['endMinute']
        elif row not in merged:
            merged.append(row)
    return merged, 'scheduled'


def parse_rows(rows, year, semester):
    result = {}
    for row in rows:
        if row.get('yy') != str(year) or row.get('shtmCd') != TERM_CODES[semester]:
            raise ValueError('Wrong Ajou course term')
        code, section, title = (row.get(k, '') for k in ['sbjtCd', 'clssNo', 'sbjtKorNm'])
        if not all(isinstance(v, str) and v.strip() for v in [code, section, title]):
            raise ValueError('Invalid Ajou course identity')
        department = ' / '.join(dict.fromkeys(v for v in [row.get('sustCdNm'), row.get('mjCdNm')] if v))
        department = department or row.get('submattFgNm') or ''
        if not department or (row.get('pnt') is not None and not isinstance(row['pnt'], (float, int))):
            raise ValueError('Invalid Ajou course department/credits')
        schedule = row.get('ltTmNm') or ''
        parsed, status = meetings(schedule)
        offering = row.get('openLtNo')
        if not isinstance(offering, str) or not offering.isdigit():
            raise ValueError('Missing Ajou offering identity')
        teacher = row.get('maLecturerEmplNo') or row.get('maLecturerEmplNm') or 'unassigned'
        teacher_key = hashlib.sha256(teacher.encode()).hexdigest()[:16]
        identity = f'ajou/main/{year}/{semester}/{offering}/{section}/{teacher_key}'
        remarks = '\n'.join(v for v in [row.get('ltFgNm'), row.get('coopLt')] if v)
        current = {'sourceId': identity, 'universityId': 'ajou', 'campus': 'main', 'academicYear': year,
            'semester': semester, 'courseCode': code, 'section': section, 'courseName': title,
            'professor': row.get('maLecturerEmplNm') or '', 'credits': row['pnt'],
            'sourceSchedule': schedule, 'sourceClassroom': row.get('ltRoomNm') or '',
            'scheduleStatus': status, 'schedules': parsed, 'departments': [department],
            'departmentCredits': {department: row['pnt']} if row['pnt'] is not None else {},
            'departmentClassifications': {department: row.get('submattFgNm') or ''},
            'departmentRemarks': {department: remarks}}
        previous = result.get(identity)
        if previous is None:
            result[identity] = current
        else:
            for field in ['courseName', 'professor', 'schedules', 'sourceSchedule', 'sourceClassroom']:
                if previous[field] != current[field]:
                    raise ValueError(f'Conflicting Ajou course: {code}-{section} {field}')
            if department not in previous['departments']:
                previous['departments'].append(department)
            for field in ['departmentCredits', 'departmentClassifications', 'departmentRemarks']:
                if department in previous[field] and department in current[field] and previous[field][department] != current[field][department]:
                    raise ValueError(f'Conflicting Ajou departmental data: {identity}')
                previous[field].update(current[field])
    if not result:
        raise ValueError('Empty Ajou course catalog')
    return list(result.values())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--year', required=True, type=int)
    ap.add_argument('--semester', required=True, choices=TERM_CODES)
    ap.add_argument('--source-dir', required=True, type=Path)
    ap.add_argument('--output', required=True, type=Path)
    ap.add_argument('--fetched-date', required=True)
    ap.add_argument('--download', action='store_true')
    args = ap.parse_args()
    args.source_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    with TemporaryDirectory(prefix='daily-ajou-public-') as session:
        cookies = str(Path(session) / 'cookies')
        if args.download:
            subprocess.run(['curl', '-fsS', '--max-time', '30', '-c', cookies, BASE + '/public.html', '-o', str(Path(session) / 'page')], check=True)
        for group in GROUPS:
            path = args.source_dir / f'{args.year}-{args.semester}-{group}.json'
            if args.download and not path.exists():
                param = {'strYy': str(args.year), 'strShtmCd': TERM_CODES[args.semester], 'strSubmattFg': group,
                    'strSustcd': '', 'strMjCd': '', 'strSubmattFldFg': '', 'strEmplNo': '', 'strStaffNm': '', 'strSbjtKorNm': ''}
                body = json.dumps({'url': '/uni/uni/cour/lssn/findCourLecturePlanDocumentReg.action', 'param': param})
                subprocess.run(['curl', '-fsS', '--max-time', '150', '-b', cookies, '-e', BASE + '/public.html',
                    '-H', 'Content-Type: application/json', BASE + '/nt/cvt.do', '--data', body, '-o', str(path)], check=True)
                time.sleep(1)
            response = json.loads(path.read_text())
            if response.get('VariableList', {}).get('ErrorCode') != '0' or not isinstance(response.get('DatasetList', {}).get('DS_COUR120'), list):
                raise ValueError('Ajou source query failed')
            group_rows = response['DatasetList']['DS_COUR120']
            print(group, len(group_rows))
            rows.extend(group_rows)
    courses = parse_rows(rows, args.year, args.semester)
    result = {'schemaVersion': 1, 'universityId': 'ajou', 'campus': 'main', 'academicYear': args.year,
        'semester': args.semester, 'publishedDate': args.fetched_date, 'sourceUrl': BASE + '/public.html#!/e020101', 'courses': courses}
    args.output.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    print('Complete:', len(courses), 'unique Ajou undergraduate courses')


if __name__ == '__main__':
    main()
