#!/usr/bin/env python3
"""Convert the University of Ulsan public course listing (uwins MCB07S,
frame=oebu, 2026-2) crawled by fetch_ulsan.py into the bundled dataset.

Each listing row is kept as published. A course (code + section) listed under
several official 소속 keeps every 소속 label with that listing's 이수구분.
Courses only reachable through the 영역별 listing (e.g. 대학 공통 교양, rows
with 학년 0) are added under their published 개설 소속.

The listing prints 교시 numbers only. A clock table is applied only to the
courses an official document prints with clock times (--clock-scope); every
other timed course stays unrecognized instead of guessing period clocks.
"""
import argparse
import json
import re
from pathlib import Path

DAYS = '월화수목금토일'
GROUP = re.compile(r'([월화수목금토일])((?:\d+,?)+)')


def meetings(raw, rooms, clock):
    """Return (status, meetings) for a published 강의시간 such as 월5,금6,7."""
    if not raw:
        return 'unscheduled', []
    groups = list(GROUP.finditer(raw))
    if not groups or ''.join(g[0] for g in groups).rstrip(',') != raw.rstrip(','):
        return 'unrecognized', []
    room_parts = rooms.split(',') if rooms else []
    if len(room_parts) != len(groups):
        room_parts = [rooms] * len(groups)
    out = []
    for group, room in zip(groups, room_parts):
        day = DAYS.index(group[1]) + 1
        periods = [int(p) for p in group[2].split(',') if p]
        if any(str(p) not in clock for p in periods):
            return 'unrecognized', []
        periods.sort()
        runs = [[periods[0]]]
        for p in periods[1:]:
            if p == runs[-1][-1] + 1:
                runs[-1].append(p)
            else:
                runs.append([p])
        for run in runs:
            start = clock[str(run[0])][0]
            end = clock[str(run[-1])][1]
            out.append({'weekday': day, 'startMinute': start,
                        'endMinute': end, 'classroom': room})
    out.sort(key=lambda m: (m['weekday'], m['startMinute']))
    for a, b in zip(out, out[1:]):
        if a['weekday'] == b['weekday'] and b['startMinute'] < a['endMinute']:
            # e.g. 목6,목6,목7,목7: the same period printed twice (two rooms);
            # which room meets when is not stated, so keep it unresolved.
            return 'unrecognized', []
    return 'scheduled', out


def convert(listings, areas, owners, clock, scope):
    courses = {}
    in_major = {(r['cells'][1], r['cells'][3]) for l in listings for r in l['rows']}
    tagged = [(l['sosog'][1], r) for l in listings for r in l['rows']]
    for area in areas:
        for r in area['rows']:
            if (r['cells'][1], r['cells'][3]) not in in_major:
                tagged.append((owners[r['setParam'][8]], r))
    out = []
    for group, room in zip(groups, room_parts):
        day = DAYS.index(group[1]) + 1
        periods = [int(p) for p in group[2].split(',') if p]
        if any(str(p) not in clock for p in periods):
            return 'unrecognized', []
        periods.sort()
        runs = [[periods[0]]]
        for p in periods[1:]:
            if p == runs[-1][-1] + 1:
                runs[-1].append(p)
            else:
                runs.append([p])
        for run in runs:
            start = clock[str(run[0])][0]
            end = clock[str(run[-1])][1]
            out.append({'weekday': day, 'startMinute': start,
                        'endMinute': end, 'classroom': room})
    out.sort(key=lambda m: (m['weekday'], m['startMinute']))
    for a, b in zip(out, out[1:]):
        if a['weekday'] == b['weekday'] and b['startMinute'] < a['endMinute']:
            # e.g. 목6,목6,목7,목7: the same period printed twice (two rooms);
            # which room meets when is not stated, so keep it unresolved.
            return 'unrecognized', []
    return 'scheduled', out


def convert(listings, areas, owners, clock, scope):
    courses = {}
    in_major = {(r['cells'][1], r['cells'][3]) for l in listings for r in l['rows']}
    tagged = [(l['sosog'][1], r) for l in listings for r in l['rows']]
    for area in areas:
        for r in area['rows']:
            if (r['cells'][1], r['cells'][3]) not in in_major:
                tagged.append((owners[r['setParam'][8]], r))
    if True:
        for label, row in tagged:
            c = row['cells']
            code, name, section, grade, course_kind = c[1], c[2], c[3], c[4], c[5]
            credits, raw_time, prof, rooms, grading, note = c[6], c[7], c[8], c[9], c[10], c[11]
            sp = row['setParam']
            if sp[1:3] != ['2026', '2'] or sp[5] != code or sp[7].strip() != section:
                raise ValueError(f'unexpected row identity {sp}')
            if not re.fullmatch(r'[A-Z]{1,2}\d{4,5}', code) or not re.fullmatch(r'[0-9A-Z]{1,2}', section):
                raise ValueError(f'invalid identity {code}-{section}')
            key = f'{code}-{section}'
            base = {'courseName': name, 'professor': prof, 'credits': float(credits),
                    'sourceSchedule': raw_time, 'sourceClassroom': rooms,
                    'courseKind': course_kind, 'grading': grading,
                    'note': note}
            entry = courses.setdefault(key, {'base': base, 'labels': {}, 'grades': set()})
            entry['grades'].add(grade)
            if entry['base'] != base:
                raise ValueError(f'conflicting rows for {key}: {entry["base"]} != {base}')
            prev = entry['labels'].get(label)
            if prev is not None and prev != row['isu']:
                raise ValueError(f'conflicting 이수구분 for {key} under {label}')
            entry['labels'][label] = row['isu']
    out = []
    for key in sorted(courses):
        b, labels = courses[key]['base'], courses[key]['labels']
        grades = ','.join(sorted(courses[key]['grades']))
        code, section = key.split('-')
        status, slots = meetings(b['sourceSchedule'], b['sourceClassroom'],
                                 clock if key in scope else {})
        held = None
        if status == 'unrecognized':
            held = ('공식 원문에 교시별 시각이 없어 수업 시각 미확정 (원문 강의시간: '
                    f"{b['sourceSchedule']})")
        remark = '\n'.join(x for x in [
            f"과정구분 {b['courseKind']} · 학년 {grades} · 성적평가 {b['grading']}",
            b['note'], held,
            '학교 공시의 정규 수업 계획입니다. 시험·보강·변경 사항은 학교 공지를 확인하세요.',
        ] if x)
        out.append({
            'sourceId': f'ulsan/main/2026/2/{code}/{section}',
            'universityId': 'ulsan', 'campus': 'main', 'academicYear': 2026,
            'semester': '2', 'courseCode': code, 'section': section,
            'courseName': b['courseName'], 'professor': b['professor'],
            'credits': b['credits'], 'sourceSchedule': b['sourceSchedule'],
            'sourceClassroom': b['sourceClassroom'], 'scheduleStatus': status,
            'schedules': slots, 'departments': list(labels),
            'departmentCredits': {l: b['credits'] for l in labels},
            'departmentClassifications': dict(labels),
            'departmentRemarks': {l: remark for l in labels},
        })
    return out


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--major', type=Path, required=True)
    ap.add_argument('--area', type=Path, required=True)
    ap.add_argument('--tree', type=Path, required=True)
    ap.add_argument('--clock', type=Path, required=True,
                    help='JSON {"clock": {period: [start, end]}, "scope": ["CODE-SECTION", ...]}')
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--published', required=True)
    a = ap.parse_args()
    spec = json.loads(a.clock.read_text())
    tree = json.loads(a.tree.read_text())
    owners = {code: name for t in tree for code, name in t['sosog']}
    owners.update({code: name for t in tree for code, name in [t['daehag']]})
    owners['10000'] = '대학(공통)'
    courses = convert(json.loads(a.major.read_text()), json.loads(a.area.read_text()),
                      owners, spec['clock'], set(spec['scope']))
    a.output.write_text(json.dumps({
        'schemaVersion': 2, 'universityId': 'ulsan', 'campus': 'main',
        'campusName': '울산대학교', 'academicYear': 2026, 'semester': '2',
        'publishedDate': a.published,
        'sourceUrl': 'https://uwins.ulsan.ac.kr/LESN/B/MCB07S.aspx?MenuID=MCB07S!1&frame=oebu',
        'researchOnly': False, 'productionIntegrationEnabled': True,
        'completionClaim': False, 'wholeOperatingVerified': False,
        'courses': courses,
    }, ensure_ascii=False, indent=1) + '\n')
    from collections import Counter
    print(len(courses), Counter(c['scheduleStatus'] for c in courses))
