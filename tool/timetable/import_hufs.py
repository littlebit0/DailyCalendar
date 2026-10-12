#!/usr/bin/env python3
"""Import full public HUFS queries without guessing unpublished period times.

The supplied clock must be verified against official campus publications.
An unknown period fails the import rather than silently dropping a class.
"""
import argparse
from html import unescape
import json
from pathlib import Path
import re

DAYS = '월화수목금토일'
CAMPUS_NAMES = {'H1': '서울캠퍼스', 'H2': '글로벌캠퍼스'}
CAMPUS_IDS = {'H1': 'seoul', 'H2': 'global'}


def clean(value):
    return re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', unescape(value or ''))).strip()


def meetings(text, clock):
    """A trailing classroom applies to all day groups preceding it."""
    text = clean(text)
    if not text:
        return []
    result = []
    blocks = list(re.finditer(r'([^()]+)\(([^()]*)\)', text))
    if ' '.join(match[0].strip() for match in blocks) != text:
        raise ValueError('Unrecognized HUFS schedule: ' + text)
    for block in blocks:
        times, room = block[1].strip(), block[2].strip()
        groups = list(re.finditer(r'([월화수목금토일])\s+((?:\d+\s*)+)', times))
        if ' '.join(match[0].strip() for match in groups) != times:
            raise ValueError('Unrecognized HUFS day/period: ' + times)
        for group in groups:
            day = DAYS.index(group[1]) + 1
            periods = [int(value) for value in group[2].split()]
            if len(set(periods)) != len(periods) or periods != sorted(periods):
                raise ValueError('Invalid HUFS period order')
            previous = None
            previous_period = None
            for period in periods:
                if str(period) not in clock:
                    raise ValueError('Unverified HUFS period: ' + str(period))
                start, end = clock[str(period)]
                if not 0 <= start < end <= 1440:
                    raise ValueError('Invalid HUFS published clock')
                if previous is not None and period == previous_period + 1:
                    previous['endMinute'] = end
                else:
                    previous = {
                        'weekday': day, 'startMinute': start,
                        'endMinute': end, 'classroom': room,
                    }
                    result.append(previous)
                previous_period = period
    return result


def parse_rows(rows, clocks, year=2026, semester='2'):
    if semester != '2':
        raise ValueError('Only collected HUFS second-semester scope supported')
    courses = {}
    for record in rows:
        row = record['row']
        campus = record['queryCampus']
        category = record['queryCategory']
        if campus not in CAMPUS_IDS or category not in {'1', '2', '3', '4'}:
            raise ValueError('Invalid HUFS query scope')
        if (row['ledgYear'], row['ledgSessn'], row['orgSect'], row['campus']) != (
            str(year), '3', 'A', campus,
        ):
            raise ValueError('Wrong HUFS undergraduate term/campus')
        identity = row['lssnCd']
        if not re.fullmatch(r'[A-Za-z0-9]{7}\d{2}', identity):
            raise ValueError('Invalid HUFS identity')
        code, section = identity[:7], identity[7:]
        name = clean(row['subjtNaKr'])
        credits = float(row['unitNum'])
        if not name or not 0 <= credits <= 30:
            raise ValueError('Invalid HUFS course metadata')
        schedule = clean(row['dayTimeDisplay'])
        scheduled = meetings(schedule, clocks[campus])
        label = clean(record['queryDepartment'])
        if not label:
            raise ValueError('Missing HUFS query department')
        prefix = {'1': '', '2': '교양 · ', '3': '대학기초 · ', '4': '마이크로전공 · '}[category]
        department = prefix + label
        original_classification = clean(row['comptFldNm'])
        classification = {'2': '교양', '3': '대학기초'}.get(category, original_classification)
        if row['encessFlag'] == 'Y' and classification in {'전공', '이중(부)전공', '이중(제2)'}:
            classification = '전공필수'
        remarks = [clean(row.get(key)) for key in ['etc', 'etc2']]
        if classification != original_classification:
            remarks.append('공식 이수구분: ' + original_classification)
        if row['cyberFlag'] == 'Y':
            remarks.append('온라인 강좌')
        if row['wongangFlag'] == 'Y':
            remarks.append('원어 강의: ' + clean(row['lang']))
        source_id = f'hufs/{CAMPUS_IDS[campus]}/{year}/{semester}/{code}/{section}'
        current = {
            'sourceId': source_id, 'universityId': 'hufs',
            'campus': CAMPUS_IDS[campus], 'academicYear': year, 'semester': semester,
            'courseCode': code, 'section': section, 'courseName': name,
            'professor': clean(row['empNm']), 'credits': credits,
            'sourceSchedule': schedule,
            'sourceClassroom': ' / '.join(dict.fromkeys(m['classroom'] for m in scheduled)),
            'scheduleStatus': 'scheduled' if scheduled else 'unscheduled',
            'schedules': scheduled, 'departments': [department],
            'departmentCredits': {department: credits},
            'departmentClassifications': {department: classification},
            'departmentRemarks': {department: ' · '.join(dict.fromkeys(filter(None, remarks)))},
        }
        previous = courses.get(source_id)
        if previous is None:
            courses[source_id] = current
            continue
        for field in ['courseName', 'professor', 'credits', 'sourceSchedule', 'schedules']:
            if previous[field] != current[field]:
                raise ValueError(f'Conflicting HUFS course {source_id}: {field}')
        if department not in previous['departments']:
            previous['departments'].append(department)
        for field in ['departmentCredits', 'departmentClassifications', 'departmentRemarks']:
            if department in previous[field] and previous[field][department] != current[field][department]:
                raise ValueError(f'Conflicting HUFS department data: {source_id}')
            previous[field].update(current[field])
    if not courses:
        raise ValueError('Empty HUFS catalog')
    return list(courses.values())


def load_complete(directory):
    manifest = json.loads((directory / 'manifest.json').read_text())
    rows = json.loads((directory / 'courses.json').read_text())
    expected = {f'{campus}/{category}' for campus in CAMPUS_IDS for category in '1234'}
    if manifest.get('complete') is not True or set(manifest['counts']) != expected:
        raise ValueError('Incomplete HUFS campus/category scope')
    if sum(scope['courses'] for scope in manifest['counts'].values()) != len(rows):
        raise ValueError('Incomplete HUFS results')
    for scope, count in manifest['counts'].items():
        actual = sum(r['queryCampus'] + '/' + r['queryCategory'] == scope for r in rows)
        if count['groups'] <= 0 or actual != count['courses']:
            raise ValueError('Incomplete HUFS scope: ' + scope)
    return manifest, rows


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--raw', type=Path, required=True)
    parser.add_argument('--clock', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--checked-at', required=True)
    args = parser.parse_args()
    manifest, rows = load_complete(args.raw)
    clocks = json.loads(args.clock.read_text())
    courses = parse_rows(rows, clocks, manifest['year'], manifest['semester'])
    args.output.mkdir(parents=True, exist_ok=True)
    for campus, campus_id in CAMPUS_IDS.items():
        selected = [c for c in courses if c['campus'] == campus_id]
        document = {
            'schemaVersion': 1, 'universityId': 'hufs', 'campus': campus_id,
            'campusName': CAMPUS_NAMES[campus], 'academicYear': manifest['year'],
            'semester': manifest['semester'], 'publishedDate': args.checked_at,
            'sourceUrl': manifest['sourceUrl'], 'courses': selected,
        }
        filename = f'hufs-{campus_id}-{manifest["year"]}-{manifest["semester"]}.json'
        (args.output / filename).write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n')
        print(campus_id, len(selected), sum(bool(c['schedules']) for c in selected))
