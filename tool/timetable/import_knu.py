#!/usr/bin/env python3
"""Normalize audited, anonymous KNU public rows without inventing meetings.

This consumes the complete source/adjudication snapshot; it is not a crawler.
Unverified delivery or dates stay blocked even when a source grid has clocks.
"""
import argparse
from collections import Counter, defaultdict
from datetime import date
import html
import json
from pathlib import Path
import re

DAYS = '월화수목금토일'
CAMPUSES = {'daegu': '대구캠퍼스', 'sangju': '상주캠퍼스',
            'dongin': '동인동캠퍼스', 'downtown': '대구광역시 도심',
            'unassigned': '캠퍼스 미게시'}
PREFIXES = {'산격동 캠퍼스': 'daegu', '상주캠퍼스': 'sangju',
            '동인동 캠퍼스': 'dongin', '대구광역시 도심': 'downtown'}
DATED = {'AAAA0901-001', 'AAAA0912-001'}
RUNTIME_FIELDS = {
    'sourceId', 'universityId', 'campus', 'academicYear', 'semester',
    'courseCode', 'section', 'courseName', 'professor', 'credits',
    'sourceSchedule', 'sourceClassroom', 'scheduleStatus', 'schedules',
    'departments', 'departmentCredits', 'departmentClassifications',
    'departmentRemarks',
}


def runtime_course(course):
    """Keep education metadata, without raw aliases or research-file paths."""
    result = {key: value for key, value in course.items() if key in RUNTIME_FIELDS}
    result['departmentRemarks'] = {
        key: html.unescape(re.sub(r'<[^>]+>', '',
             re.sub(r'<br\s*/?>', '\n', value, flags=re.I))).strip()
        for key, value in result['departmentRemarks'].items()
    }
    return result


def text(value):
    return '' if value is None else str(value)


def clock(value):
    if not re.fullmatch(r'\d{2}:\d{2}', value):
        raise ValueError('Invalid actual KNU clock')
    h, m = map(int, value.split(':'))
    if h > 23 or m > 59:
        raise ValueError('Invalid actual KNU clock')
    return h * 60 + m


def campus_for(identity, raw):
    location = text(raw.get('lctrmInfo')).strip()
    matched = [campus for prefix, campus in PREFIXES.items() if location.startswith(prefix)]
    if len(matched) > 1:
        raise ValueError('Ambiguous source campus')
    if matched:
        return matched[0]
    # Exact current source remark and visually checked current official map #115.
    if identity in {'SMMB0220-001', 'SMMB0221-001'} and 'IT융합산업빌딩 504호' in text(raw.get('rmrk')):
        return 'daegu'
    return 'unassigned'


def normalize(candidates, alias_audit, expected_count=3847):
    if len(candidates) != expected_count or len({r['identity'] for r in candidates}) != expected_count:
        raise ValueError('Incomplete or duplicate KNU whole scope')
    variants = {v['identity']: v['variants'] for v in alias_audit['variants']}
    courses = []
    for row in candidates:
        raw = row['currentSourceRaw']
        identity = row['identity']
        if (raw['estblYear'], raw['estblSmstrSctcd']) != ('2026', 'CMBS001400002'):
            raise ValueError('Wrong KNU year/term')
        if identity != f"{raw['sbjetCd']}-{raw['sbjetDvnno']}" or not re.fullmatch(r'[A-Z]{4}\d{4}-\d{3}', identity):
            raise ValueError('Invalid KNU code/section')
        if raw['mngetEstblYn'] != 'Y':
            raise ValueError('Canonical row must be the actual owning department')
        aliases = variants.get(identity, [raw])
        name_codes = defaultdict(set)
        for alias in aliases:
            name_codes[text(alias['estblDprtnNm']) or text(alias['estblUnivNm'])].add(alias['estblDprtnCd'])
        grouped = defaultdict(list)
        for alias in aliases:
            name = text(alias['estblDprtnNm']) or text(alias['estblUnivNm'])
            if not name:
                raise ValueError('Missing KNU department')
            key = name if len(name_codes[name]) == 1 else f"{name} ({alias['estblDprtnCd']})"
            grouped[key].append(alias)
        classifications, credits, remarks = {}, {}, {}
        for name, aliases_for_name in grouped.items():
            values = {text(a['sbjetSctnm']) for a in aliases_for_name}
            credit_values = {float(a['crdit']) for a in aliases_for_name}
            if len(values) != 1 or len(credit_values) != 1:
                raise ValueError('Conflicting same-code department alias: ' + identity)
            classifications[name] = values.pop()
            credits[name] = credit_values.pop()
            notes = []
            for alias in aliases_for_name:
                for value in [text(alias.get('rmrk')), '학년: ' + text(alias['estblGrade']) if alias.get('estblGrade') else '']:
                    if value and value not in notes:
                        notes.append(value)
            if row['proposedScheduleStatus'] == 'candidate_unrecognized':
                notes.append('실제 수업시간·적용일자 또는 진행 방식 미확인: 시간표 추가 불가')
            remarks[name] = '\n'.join(notes)
        status = row['proposedScheduleStatus']
        if status not in {'candidate_recognized', 'candidate_dated', 'candidate_unrecognized'}:
            raise ValueError('Unknown adjudicated status')
        schedules = []
        if status == 'candidate_unrecognized' and row['meetingCandidates']:
            raise ValueError('Blocked course has candidate meetings')
        for meeting in row['meetingCandidates']:
            start, end = clock(meeting['start']), clock(meeting['end'])
            if start >= end:
                raise ValueError('Reversed actual clock')
            if status == 'candidate_dated':
                if identity not in DATED:
                    raise ValueError('Unverified dated source')
                teaching_date = date.fromisoformat(meeting['date'])
                if not date(2026, 9, 1) <= teaching_date <= date(2026, 12, 18):
                    raise ValueError('Dated meeting outside official semester')
                schedules.append({'date': teaching_date.isoformat(), 'weekday': teaching_date.isoweekday(),
                                  'startMinute': start, 'endMinute': end, 'classroom': '', 'deliveryMode': 'liveOnline'})
            else:
                schedules.append({'weekday': DAYS.index(meeting['day']) + 1, 'startMinute': start,
                                  'endMinute': end, 'classroom': ' / '.join(v for v in
                                  [text(raw.get('lctrmInfo')), text(raw.get('rmnmCd'))] if v)})
        if status != 'candidate_unrecognized' and not schedules:
            raise ValueError('Recognized course without meetings')
        if status == 'candidate_recognized':
            actual = []
            for segment in text(raw.get('lssnsRealTimeInfo')).split(','):
                match = re.fullmatch(r'\s*([월화수목금토일])\s*(\d{2}:\d{2})\s*~\s*(\d{2}:\d{2})\s*', segment)
                if not match:
                    raise ValueError('Unparsed whole current clock: ' + identity)
                actual.append((DAYS.index(match[1]) + 1, clock(match[2]), clock(match[3])))
            converted = [(m['weekday'], m['startMinute'], m['endMinute']) for m in schedules]
            if actual != converted:
                raise ValueError('Candidate clocks disagree with current raw source: ' + identity)
        campus = campus_for(identity, raw)
        courses.append({'sourceId': f"knu/{campus}/2026/2/{raw['sbjetCd']}/{raw['sbjetDvnno']}",
                        'universityId': 'knu', 'campus': campus, 'academicYear': 2026, 'semester': '2',
                        'courseCode': raw['sbjetCd'], 'section': raw['sbjetDvnno'], 'courseName': raw['sbjetNm'],
                        'professor': text(raw.get('totalPrfssNm')), 'credits': float(raw['crdit']),
                        'sourceSchedule': text(raw.get('lssnsRealTimeInfo')),
                        'sourceClassroom': ' / '.join(v for v in [text(raw.get('lctrmInfo')), text(raw.get('rmnmCd'))] if v),
                        'scheduleStatus': 'unrecognized' if status == 'candidate_unrecognized' else 'scheduled',
                        'schedules': schedules, 'departments': list(grouped), 'departmentCredits': credits,
                        'departmentClassifications': classifications, 'departmentRemarks': remarks,
                        'sourceAliases': aliases, 'sourceAdjudicationReasons': row['reasons'],
                        'sourceOverview': row['sourceOverview'], 'sourceWeekly': row['sourceWeekly']})
    audit = {'courseCount': len(courses), 'campusCounts': dict(Counter(c['campus'] for c in courses)),
             'scheduleStatusCounts': dict(Counter(c['scheduleStatus'] for c in courses)),
             'datedCourseCount': sum(any('date' in m for m in c['schedules']) for c in courses),
             'completionClaim': False, 'unverifiedExceptionsIndividuallyBlocked': True}
    return courses, audit


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--research-dir', type=Path, required=True)
    parser.add_argument('--asset-dir', type=Path)
    args = parser.parse_args()
    root = args.research_dir
    courses, audit = normalize(json.loads((root/'knu-safe-meeting-candidates.json').read_text()),
                               json.loads((root/'knu-expanded-owner-alias-audit.json').read_text()))
    (root/'knu-normalized-candidate-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2)+'\n')
    for campus in CAMPUSES:
        payload = {'schemaVersion': 2, 'universityId': 'knu', 'campus': campus, 'campusName': CAMPUSES[campus],
                   'academicYear': 2026, 'semester': '2', 'completionClaim': False,
                   'publishedDate': '2026-10-07', 'sourceCollectedDate': '2026-10-07',
                   'sourceUrl': 'https://knuin.knu.ac.kr/public/stddm/lectPlnInqr.knu',
                   'period': {'startDate': '2026-09-01', 'endDate': '2026-12-18'},
                   'courses': [c for c in courses if c['campus'] == campus]}
        (root/f'knu-{campus}-2026-2.normalized.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2)+'\n')
        if args.asset_dir:
            args.asset_dir.mkdir(parents=True, exist_ok=True)
            payload['courses'] = [runtime_course(c) for c in payload['courses']]
            (args.asset_dir/f'knu-{campus}-2026-2.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(audit, ensure_ascii=False))
