#!/usr/bin/env python3
"""Prepare current public KMU educational rows without registering support.

Use clocks printed in each offering, not an inferred period cadence. Field,
practicum and intensive offerings with printed clocks are confirmed as weekly
meetings even though their operating dates are unpublished (2026-11-23 user
decision); see tool/timetable/apply_kmu_official_times.py.
"""
import argparse
import json
from pathlib import Path
import re

DAYS = '월화수목금토일'
CAMPUS = {'1': 'seongseo', '2': 'daemyeong', '8': 'other'}
SPECIAL = re.compile(r'임상실습|현장실습|실무실습|동계|하계')
CONFIRMED = '공식 요일·시각 기준 확정(실습·집중수업 운영 기간 미표기는 주간 대면으로 간주)'
TIME = re.compile(r'([월화수목금토일])(\d{2}):(\d{2})~(\d{2}):(\d{2})')


def meetings(raw):
    if raw is None or raw.startswith('원격수업('):
        return []
    blocks = list(re.finditer(r'([^()]+)\(([^()]*)\)', raw))
    if not blocks or ''.join(m[0] for m in blocks) != raw:
        raise ValueError('Unrecognized published KMU room/time groups')
    slots = []
    for block in blocks:
        times = list(TIME.finditer(block[1]))
        if not times or TIME.sub('', block[1]).strip():
            raise ValueError('Unrecognized published KMU clock')
        for clock in times:
            day, sh, sm, eh, em = clock.groups()
            sh, sm, eh, em = map(int, (sh, sm, eh, em))
            if not (0 <= sh < 24 and 0 <= eh < 24 and 0 <= sm < 60 and 0 <= em < 60):
                raise ValueError('Invalid published KMU clock component')
            start, end = sh * 60 + sm, eh * 60 + em
            if start >= end:
                raise ValueError('Invalid published KMU time range')
            slots.append({'weekday': DAYS.index(day) + 1, 'startMinute': start,
                          'endMinute': end, 'classroom': block[2]})
    slots.sort(key=lambda m: (m['weekday'], m['startMinute']))
    for previous, current in zip(slots, slots[1:]):
        if (previous['weekday'] == current['weekday'] and
                current['startMinute'] < previous['endMinute']):
            raise ValueError('Overlapping published KMU meetings')
    return slots


def convert(rows):
    courses, identities, audit = [], set(), []
    for row in rows:
        if row['yy'] != '2026' or row['tmGbn'] != '2':
            raise ValueError('Wrong current KMU semester')
        campus = CAMPUS[row['campGbn']]
        code, section = row['scCd'], row['ltNo']
        if (not re.fullmatch(r'\d+', code) or
                not re.fullmatch(r'\d{2}', section) or
                row['scCdLtNo'] != f'{code}-{section}'):
            raise ValueError('Invalid actual KMU identity')
        if row['scCdLtNo'] in identities:
            raise ValueError('Duplicate KMU offering')
        identities.add(row['scCdLtNo'])
        department, name = row['deptNm'], row['scNm']
        if not department or not name or not row['cptnGbnNm']:
            raise ValueError('Missing actual KMU educational metadata')
        credits = float(row['openHp'])
        if not 0 <= credits <= 30:
            raise ValueError('Invalid KMU credits')
        raw = row['lsnTmtablFormaSmryCtnt']
        slots = meetings(raw)
        notes = [row.get('tlsnObjHgCtnt'), row.get('openLtRemark')]
        if slots and SPECIAL.search(name):
            audit.append(row['scCdLtNo'])
            notes.append(CONFIRMED)
        if row['ltTypeGbn'] == '1':
            if slots:
                raise ValueError('Remote public row unexpectedly has physical slots')
            notes.append('공식 원격수업: 개별 출석·시험 일시 미게시')
        courses.append({
            'sourceId': f'kmu/{campus}/2026/2/{code}/{section}',
            'universityId': 'kmu', 'campus': campus, 'academicYear': 2026,
            'semester': '2', 'courseCode': code, 'section': section,
            'courseName': name, 'professor': row['respProfEmpNm'] or '',
            'credits': credits, 'sourceSchedule': raw or '',
            'sourceClassroom': row['eduSpaceNm'] or '',
            'scheduleStatus': 'scheduled' if slots else 'unscheduled',
            'schedules': slots, 'departments': [department],
            'departmentCredits': {department: credits},
            'departmentClassifications': {department: row['cptnGbnNm']},
            'departmentRemarks': {department: '\n'.join(n for n in notes if n)},
        })
    return courses, audit


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = json.loads(args.input.read_text(encoding='utf-8'))
    courses, practicum = convert(source['records'])
    args.output.write_text(json.dumps({
        'schemaVersion': 1, 'academicYear': 2026, 'semester': '2',
        'universityId': 'kmu', 'sourceUrl': source['sourceUrl'],
        'researchOnly': True, 'productionReady': False, 'completionClaim': False,
        'courses': courses, 'confirmedWithoutOperatingPeriod': practicum,
        'remaining': ['active-status semantic and current closure audit',
                      'general semester and actual operating dates'],
    }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Prepared current KMU courses', len(courses), 'confirmed without operating period', len(practicum))
