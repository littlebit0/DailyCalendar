"""Preserve actual current BU identities, exact closures and published changes.

Research only: current undergraduate clock and campus proof are still needed.
No guessed weekly times are emitted. Seven-digit registration identities have
an explicitly documented five-digit subject plus two-digit section boundary.
"""
import json
import html
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).parent
DAYS = '월화수목금토일'


def current_undergraduate_clock_candidates(raw, room):
    """Current 2026 BU undergraduate source explicitly covers periods 1--9.

    Return only a review candidate; the current semester clock is directly
    published for undergraduate contract departments. Wider scope remains
    separately reviewed. Cyber content has no invented
    attendance time. Physical components retain their actual weekday/period.
    """
    if not raw or compact(raw) in {'사', '사이버'}:
        return []
    result = []
    for part in re.split(r'/|,(?=[월화수목금토일])', compact(raw)):
        if compact(part) in {'사', '사이버'}:
            continue
        match = re.fullmatch(r'([월화수목금토일])([0-9,]+)', compact(part))
        if not match:
            return []
        day, periods = match.groups()
        values = [int(v) for v in periods.split(',')]
        if not values or len(set(values)) != len(values) or any(v not in range(1, 10) for v in values):
            return []
        ordered = sorted(values)
        groups = [[ordered[0]]]
        for value in ordered[1:]:
            if value == groups[-1][-1]+1:
                groups[-1].append(value)
            else:
                groups.append([value])
        for group in groups:
            result.append({'weekday': DAYS.index(day)+1,
                           'startMinute': 480+group[0]*60,
                           'endMinute': 530+group[-1]*60,
                           'classroom': room})
    return result


def compact(value):
    return re.sub(r'\s+', '', value or '')


def cells(record):
    result = {compact(h): v or '' for h, v in zip(record['headers'], record['values']) if h}
    if '요일교시' in result:
        result['요일/교시'] = result.pop('요일교시')
    return result


def actual_campus_for_room(room):
    """Match the source's numbered abbreviated building to its official map.

    Missing/externally assigned rooms remain technical unknown. The mapping is
    explicit and never uses the course's department to infer a campus.
    """
    aliases = {'본부': '본부동', '조형': '조형관', '진리': '진리관', '체육': '체육관',
               '지혜': '지혜관', '목양': '목양관', '예술': '예술대학동',
               '글로벌': '글로벌외식산업관', '음악': '음악관', '승리': '승리관', '자유': '자유관'}
    value = compact(room)
    if ',' in value:
        components = [actual_campus_for_room(v) for v in value.split(',')]
        if all(campus == 'cheonan' for campus, _ in components):
            return 'cheonan', {'multipleActualRooms': [evidence for _, evidence in components]}
        return 'unknown', None
    if value in {'백석홀대강당', '백석홀소강당'}:
        building = '백석홀'
    else:
        match = re.fullmatch(r'(본부|조형|진리|체육|지혜|목양|예술|글로벌|음악|승리|자유)B?\d+(?:-\d+)?', value)
        if not match:
            return 'unknown', None
        building = aliases[match.group(1)]
    evidence = json.loads((ROOT/'bu-current-actual-campus-building-addresses.json').read_text())
    matches = [r for r in evidence['records'] if r['building'] == building]
    if len(matches) != 1 or '충청남도 천안시' not in matches[0]['address']:
        raise ValueError('Missing exact official building location')
    return 'cheonan', {'roomAbbreviation': room, 'matchedBuilding': building,
                       'officialAddress': matches[0]['address'],
                       'officialMapArticle': matches[0]['actualPublishedMapArticle'],
                       'source': evidence['publishedCampusPage']}


def schedule_components(value):
    return sorted(compact(value).split('/'))


def published_faculties():
    source = (ROOT/'bu-current-registration.html').read_text()
    labels = {}
    for url, body in re.findall(r'<a[^>]+href="([^"]+2026_2[^"]+\.pdf)"[^>]*>(.*?)</a>', source, re.S):
        label = html.unescape(re.sub(r'<[^>]+>', '', body)).split('☜')[0].strip()
        labels[url.rsplit('/', 1)[-1].replace('.pdf', '.tables.json')] = label
    return labels


def prepare(rows, closure, changes):
    faculty_changes = json.loads((ROOT/'bu-current-freedom-faculty-exact-code-changes.tables.json').read_text())[0][1:]
    faculty_changes_by_code = {row[0]: row for row in faculty_changes}
    teaching_dates = json.loads((ROOT/'bu-current-official-teaching-date-records.json').read_text())
    faculty_labels = published_faculties()
    full_changes = json.loads((ROOT/'bu-current-full-change-records.json').read_text())
    changes_by_code = defaultdict(list)
    for record in full_changes:
        changes_by_code[record['combinedCode']].append(record)
    grouped = defaultdict(list)
    for row in rows:
        code = row['publishedCombinedCode']
        if not re.fullmatch(r'\d{7}', code):
            raise ValueError('Invalid actual published registration code')
        grouped[code].append(row)
    if len(rows) != 3211 or len(grouped) != 2613:
        raise ValueError('Changed complete published package scope')
    closed = set(closure['exactCombinedCodes'])
    if len(closed) != 55:
        raise ValueError('Changed official closure source scope')
    updates = {r['combinedCode']: r for r in changes}
    result = []
    audit = {'closedPresent': sorted(closed & grouped.keys()),
             'closedNotInInitialSource': sorted(closed - grouped.keys()),
             'nameAliases': [], 'missingCredit': [], 'timeChangesApplied': [],
             'professorChangesApplied': [], 'additionalPublishedIdentities': [], 'facultyChangesValidated': []}
    for code, sources in grouped.items():
        if code in closed:
            continue
        values = [cells(r) for r in sources]
        names = list(dict.fromkeys(v['과목명'] for v in values if v.get('과목명')))
        # The current package repeats the same exchange course with a literal
        # (교류) suffix. Keep both source names instead of deleting the suffix.
        if len({compact(n).removesuffix('(교류)') for n in names}) != 1:
            raise ValueError('Conflicting actual names for one registration code')
        if len(names) > 1:
            audit['nameAliases'].append({'combinedCode': code, 'names': names})
        schedules = {compact(v['요일/교시']) for v in values if '요일/교시' in v}
        rooms = {compact(v['강의실']) for v in values if '강의실' in v}
        if len(schedules) > 1 or len(rooms) > 1:
            raise ValueError('Conflicting source time/room for one actual code')
        schedule = next((v['요일/교시'] for v in values if '요일/교시' in v), '')
        initial_schedule = schedule
        room = next((v['강의실'] for v in values if '강의실' in v), '')
        change = updates.get(code)
        if change:
            if schedule_components(schedule) != schedule_components(change['officialPreviousSchedule']):
                raise ValueError('Changed course does not match the official previous time')
            schedule = change['officialNewSchedule']
            audit['timeChangesApplied'].append(code)
        credit_values = {compact(v.get('학점', '')) for v in values} - {''}
        if len(credit_values) > 1:
            raise ValueError('Conflicting actual credit value')
        credit = next(iter(credit_values), '')
        if credit and not re.fullmatch(r'\d+(?:\.\d+)?', credit):
            raise ValueError('Unrecognized published credit value')
        if not credit:
            audit['missingCredit'].append(code)
        departments = list(dict.fromkeys(faculty_labels[r['source']] for r in sources))
        scoped_classifications = defaultdict(list)
        scoped_remarks = defaultdict(list)
        professors = list(dict.fromkeys(v.get('담당교수', '') for v in values if v.get('담당교수')))
        for record, value in zip(sources, values):
            department = faculty_labels[record['source']]
            classification = value.get('구분') or value.get('2018이후입학자') or value.get('영역') or ''
            if classification and classification not in scoped_classifications[department]:
                scoped_classifications[department].append(classification)
            remark = value.get('특이사항') or value.get('비고') or ''
            if remark and remark not in scoped_remarks[department]:
                scoped_remarks[department].append(remark)
        official_changes = changes_by_code.get(code, [])
        professor_updates = [c for c in official_changes if c['newProfessor']]
        if professor_updates:
            new_values = {compact(c['newProfessor']) for c in professor_updates}
            if len(new_values) != 1 or not any(compact(c['previousProfessor']) in {compact(p) for p in professors} for c in professor_updates):
                raise ValueError('Official professor change does not match actual source')
            professors = [professor_updates[-1]['newProfessor']]
            audit['professorChangesApplied'].append(code)
        faculty_change = faculty_changes_by_code.get(code)
        if faculty_change:
            if (compact(names[0]) != compact(faculty_change[2])
                    or float(credit) != float(faculty_change[3])
                    or compact(professors[0]) != compact(faculty_change[4])
                    or compact(schedule) != compact(faculty_change[5])
                    or compact(room) != compact(faculty_change[6])):
                raise ValueError('Exact current faculty change does not match original source')
            professors = [faculty_change[7]]
            department = '자유전공학부'
            if faculty_change[8] not in scoped_remarks[department]:
                scoped_remarks[department].append(faculty_change[8])
            audit['facultyChangesValidated'].append(code)
        campus, campus_evidence = actual_campus_for_room(room)
        clock_candidates = current_undergraduate_clock_candidates(schedule, room)
        date_candidates = []
        for meeting in clock_candidates:
            for teaching in teaching_dates['records']:
                if teaching['sourceWeekday'] == meeting['weekday'] and teaching['kind'] != '원격수업':
                    date_candidates.append({**meeting, 'weekday': teaching['weekday'], 'date': teaching['date']})
        result.append({
            'sourceId': f'baekseok/2026/2/{code}',
            'universityId': 'baekseok', 'academicYear': 2026, 'semester': '2',
            'publishedCombinedCode': code, 'courseCode': code[:5], 'section': code[5:],
            'courseName': names[0], 'sourceNames': names,
            'credits': float(credit) if credit else None,
            'professor': ' / '.join(professors), 'departments': departments,
            'departmentCredits': {d: float(credit) for d in departments} if credit else {},
            'departmentClassifications': {d: ' / '.join(v) for d, v in scoped_classifications.items()},
            'departmentRemarks': {d: ' / '.join(v) for d, v in scoped_remarks.items()},
            'publishedClassificationValues': dict(scoped_classifications),
            'officialChangeRecords': official_changes,
            'officialExactFacultyChange': faculty_change,
            'sourceSchedule': schedule, 'initialSourceSchedule': initial_schedule,
            'sourceClassroom': room,
            'currentYearClockReviewMeetings': clock_candidates,
            'currentSemesterActualDateReviewMeetings': date_candidates,
            'clockEvidenceScope': 'BU official 2026-2 contract undergraduate periods 1--9, agrees with 2026 summer 1--8; wider department applicability under review',
            'campus': campus, 'campusEvidence': campus_evidence, 'scheduleStatus': 'unrecognized', 'schedules': [],
            'remarks': '현재 학부 교시의 실제 시각·캠퍼스 및 최종 강의실 변경 확인 필요',
            'sourceOccurrences': sources,
            'appliedTimeChange': change,
        })
    for code, records in changes_by_code.items():
        if code in grouped or code in closed:
            continue
        names = {compact(r['courseName']) for r in records}
        if len(names) != 1:
            raise ValueError('Conflicting additional published course names')
        record = records[-1]
        credit = float(record['credits'])
        # "변동 X" supplies no actual weekday/period. Preserve the real code,
        # current credits and professor, but do not invent attendance.
        result.append({
            'sourceId': f'baekseok/2026/2/{code}', 'universityId': 'baekseok',
            'academicYear': 2026, 'semester': '2', 'publishedCombinedCode': code,
            'courseCode': code[:5], 'section': code[5:], 'courseName': record['courseName'],
            'sourceNames': [record['courseName']], 'credits': credit,
            'professor': record['newProfessor'], 'departments': [record['department']],
            'departmentCredits': {record['department']: credit},
            'departmentClassifications': {record['department']: record['classification']},
            'departmentRemarks': {record['department']: record['remarks']},
            'sourceSchedule': '', 'initialSourceSchedule': '', 'sourceClassroom': '',
            'currentYearClockReviewMeetings': [], 'campus': 'unknown',
            'scheduleStatus': 'unrecognized', 'schedules': [],
            'remarks': '공식 변경표의 실제 강좌. 원 시간표/강의실은 공개 변경표에 없음',
            'sourceOccurrences': [], 'officialChangeRecords': records,
        })
        audit['additionalPublishedIdentities'].append(code)
    return {'productionReady': False, 'completionClaim': False,
            'countIsFinalActiveCount': False, 'courses': result, 'audit': audit,
            'teachingPeriodEvidence': {
                'url': 'https://bhm.bu.ac.kr/bbs/web/788/58632/artclView.do',
                'start': '2026-09-01', 'end': '2026-12-21',
                'remoteVideoReplacement': {'start': '2026-10-15', 'end': '2026-10-21'},
                'actualDateSource': teaching_dates['url'],
                'status': '75 actual weekday teaching dates; 5 video replacement dates not assigned synchronous attendance; special-course exceptions remain unverified'},
            'remainingVerification': ['current clock scope outside undergraduate contract departments', 'actual campus scope',
                'room changes excluded from central change notice', 'current final active source',
                'special attendance dates and remote replacement week']}


if __name__ == '__main__':
    candidate = prepare(json.loads((ROOT/'bu-all-published-code-rows.json').read_text()),
                        json.loads((ROOT/'bu-exact-closure-audit.json').read_text()),
                        json.loads((ROOT/'bu-current-exact-time-changes.json').read_text()))
    (ROOT/'bu-current-whole-candidate-unregistered.json').write_text(
        json.dumps(candidate, ensure_ascii=False, indent=2) + '\n')
    print('Preserved actual identities', len(candidate['courses']))
    print({k: len(v) for k, v in candidate['audit'].items()})
