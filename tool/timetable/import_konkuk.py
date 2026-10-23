#!/usr/bin/env python3
"""Build Konkuk Seoul/GLOCAL 2026-2 datasets from fetch_konkuk.py output.

Seoul periods use the regular-semester clock published on
https://www.konkuk.ac.kr/konkuk/2367/subview.do (교시별 시간 안내). GLOCAL rows
publish HHMM-HHMM clocks directly. A schedule text that does not match the
published grammar is kept verbatim as `unrecognized`, never guessed. GLOCAL
집중이수 rows publish weeks (e.g. 8주(1-8주)) but no dates, so they are held as
`unrecognized` too. Closed (폐강) GLOCAL rows are excluded.
"""
import argparse
import json
from pathlib import Path
import re

DAYS = '월화수목금토일'
# 정규학기 교시별 시간 (start, end) in minutes.
SEOUL_CLOCK = {p: (540 + (p - 1) * 30, 570 + (p - 1) * 30) for p in range(1, 19)}
SEOUL_CLOCK.update({19: (1095, 1140), 20: (1140, 1185), 21: (1185, 1230),
                    22: (1230, 1275), 23: (1275, 1320)})
# A room can carry one nested parenthesis, e.g. 모시래학사(여동)-본관 115.
ROOM = r'\((?:[^()]|\([^()]*\))*\)'
SEOUL_BLOCK = re.compile(r'([월화수목금토일])(\d{2})(?:-(\d{2}))?((?:' + ROOM + r')*)')
# Delivery tags trail the room; they are not rooms.
TAGS = {'b-러닝', 'e-러닝'}
GLOCAL_BLOCK = re.compile(
    r'([월화수목금토일])(\d{2})(\d{2})-(\d{2})(\d{2})((?:' + ROOM + r')*)')


def clean(value):
    return re.sub(r'\s+', ' ', str(value or '')).strip()


def split_blocks(text, pattern):
    parts = [p.strip() for p in text.split(',')]
    matches = [pattern.fullmatch(p) for p in parts]
    return matches if parts and all(matches) else None


def seoul_meetings(text):
    """Returns (status, meetings)."""
    if not text or re.fullmatch(r'\([^()]*\)', text):
        return 'unscheduled', []
    blocks = split_blocks(text, SEOUL_BLOCK)
    if blocks is None:
        return 'unrecognized', []
    result = []
    for block in blocks:
        first = int(block[2])
        last = int(block[3] or block[2])
        if first not in SEOUL_CLOCK or last not in SEOUL_CLOCK or last < first:
            return 'unrecognized', []
        result.append({
            'weekday': DAYS.index(block[1]) + 1,
            'startMinute': SEOUL_CLOCK[first][0],
            'endMinute': SEOUL_CLOCK[last][1],
            'classroom': ' '.join(
                n for n in (r[1:-1] for r in re.findall(ROOM, block[4]))
                if n not in TAGS),
        })
    return 'scheduled', result


def glocal_meetings(text):
    if not text:
        return 'unscheduled', []
    blocks = split_blocks(text, GLOCAL_BLOCK)
    if blocks is None:
        return 'unrecognized', []
    result = []
    for block in blocks:
        start = int(block[2]) * 60 + int(block[3])
        end = int(block[4]) * 60 + int(block[5])
        if int(block[3]) >= 60 or int(block[5]) >= 60 or not 0 <= start < end <= 1440:
            return 'unrecognized', []
        notes = [n[1:-1] for n in re.findall(ROOM, block[6])]
        result.append({
            'weekday': DAYS.index(block[1]) + 1, 'startMinute': start,
            'endMinute': end,
            'classroom': ' '.join(n for n in notes if n not in TAGS),
        })
    return 'scheduled', result


def course(campus, number, title, professor, credits, schedule, status,
           meetings, department, classification, remarks):
    if not title or not number or not 0 <= credits <= 30:
        raise ValueError(f'Invalid Konkuk course {campus}/{number}')
    item = {
        'sourceId': f'konkuk/{campus}/2026/2/{number}',
        'universityId': 'konkuk', 'campus': campus, 'academicYear': 2026,
        'semester': '2', 'courseCode': number, 'section': '',
        'courseName': title, 'professor': professor, 'credits': credits,
        'sourceSchedule': schedule,
        'sourceClassroom': ' / '.join(dict.fromkeys(
            m['classroom'] for m in meetings if m['classroom'])),
        'scheduleStatus': status, 'schedules': meetings,
    }
    remark = ' · '.join(dict.fromkeys(r for r in remarks if r))
    if department:
        item.update({
            'departments': [department],
            'departmentCredits': {department: credits},
            'departmentClassifications': {department: classification},
            'departmentRemarks': {department: remark},
        })
    else:
        item.update({'departments': [], 'departmentCredits': {},
                     'classification': classification, 'remarks': remark})
    return item


def seoul_courses(raw):
    if raw.get('complete') is not True:
        raise ValueError('Incomplete Seoul collection')
    courses = []
    for number, entry in sorted(raw['offerings'].items()):
        row = entry['row']
        schedule = clean(row['room_nm'])
        status, meetings = seoul_meetings(schedule)
        department = clean(row['open_sust_nm'])
        if not department:
            raise ValueError('Missing Seoul opening unit: ' + number)
        remarks = [
            clean(row['remk']), '학수번호 ' + clean(row['haksu_id']),
            # 일반 is ordinary in-person teaching; only other kinds add information.
            '강의종류: ' + clean(row['lt_knd_nm']) if clean(row['lt_knd_nm']) not in ('', '일반') else '',
            '원어: ' + clean(row['lang_type_nm']) if clean(row['lang_type_nm']) else '',
            '교양영역: ' + clean(row['cult_cors_fld']) if clean(row['cult_cors_fld']) else '',
            '개설학년: ' + clean(row['open_shyr']) if clean(row['open_shyr']) else '',
        ]
        courses.append(course(
            'seoul', number, clean(row['typl_nm']), clean(row['kor_nm']),
            float(row['pnt']), schedule, status, meetings, department,
            clean(row['pobt_div_nm']), remarks))
    return courses


def glocal_courses(raw):
    if raw.get('complete') is not True:
        raise ValueError('Incomplete GLOCAL collection')
    names = raw['unitNames']
    courses = []
    for number, entry in sorted(raw['offerings'].items()):
        row = entry['row']
        if row['clse_fg'] != '0':
            continue
        schedule = clean(row['lec_tm'])
        status, meetings = glocal_meetings(schedule)
        intensive = clean(row['intensive_nm'])
        if intensive and status == 'scheduled':
            # Weeks are published, dates are not: never repeat all term.
            status, meetings = 'unrecognized', []
        areas = sorted({s[2] for s in entry['scopes'] if s[0] in '4 11 12 13'.split()})
        remarks = [
            clean(row['sugang_remk']), clean(row['remk']),
            '학수번호 ' + clean(row['haksu_id']),
            '집중이수제: ' + intensive if intensive else '',
            '수강학과: ' + clean(row['sust_list']) if clean(row['sust_list']) else '',
            '언어구분: ' + clean(row['lt_type_nm']) if clean(row['lt_type_nm']) else '',
            '교양영역: ' + ', '.join(areas) if areas else '',
            '학년: ' + clean(row['shyr']) if clean(row['shyr']) else '',
        ]
        courses.append(course(
            'glocal', number, clean(row['lec_nm']), clean(row['prof']),
            float(row['pnt']), schedule, status, meetings,
            names.get(row['open_sust'], ''), clean(row['isu_nm']), remarks))
    return courses


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--raw', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--checked-at', required=True)
    args = parser.parse_args()
    for campus, name, build in (
        ('seoul', '서울캠퍼스', seoul_courses),
        ('glocal', 'GLOCAL(글로컬)캠퍼스', glocal_courses),
    ):
        raw = json.loads((args.raw / f'{campus}.json').read_text())
        courses = build(raw)
        document = {
            'schemaVersion': 1, 'universityId': 'konkuk', 'campus': campus,
            'campusName': name, 'academicYear': 2026, 'semester': '2',
            'publishedDate': args.checked_at, 'sourceUrl': raw['sourceUrl'],
            'courses': courses,
        }
        path = args.output / f'konkuk-{campus}-2026-2.json'
        path.write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n')
        counts = {}
        for c in courses:
            counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
        print(campus, len(courses), counts)


if __name__ == '__main__':
    main()
