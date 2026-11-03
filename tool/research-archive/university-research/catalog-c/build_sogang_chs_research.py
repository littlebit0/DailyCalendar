"""Research-only current CHS proof; never registers production assets."""
import datetime
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent
proof = json.loads((ROOT / 'sogang-current-public-plan-education/CHS2003-03.json').read_text())
text = proof['educationalText']
assert '2026-2학기' in text and 'CHS2003-03' in text and '화목 12:00-13:15' in text
sections = re.split(r'(\d+)\s*주차\(([^)]+)\)', text)
dates = []
week_proof = []
for offset in range(1, len(sections), 3):
    week = int(sections[offset])
    raw_dates = sections[offset + 1]
    body = sections[offset + 2]
    pairs = re.findall(r'(\d{1,2})/(\d{1,2})', re.sub(r'\s+', '', raw_dates))
    assert len(pairs) in (1, 2)
    if week in (8, 16):
        continue
    assert '수업방법강의' in re.sub(r'\s+', '', body)
    actual = [datetime.date(2026, int(month), int(day)) for month, day in pairs]
    assert all(day.isoweekday() in (2, 4) for day in actual)
    dates.extend(actual)
    week_proof.append({'week': week, 'printedDates': raw_dates, 'dates': [day.isoformat() for day in actual]})
assert len(dates) == len(set(dates)) == 27
assert proof['currentPublicRow']['exam'] == '10.20(화)12:00~13:15[K303]'
assert proof['currentPublicRow']['meetingText'] == '화,목 12:00~13:15 [K303]'

courses = []
for row in json.loads((ROOT / 'sogang-current-educational-20261008.json').read_text())['records']:
    code, section, department = row['subjectCode'], row['section'], row['department']
    credit = float(row['credit']) if row['credit'].strip() else None
    notes = '\n'.join(key + ': ' + row[key] for key in ['registrationRemarks', 'remarks', 'target', 'recommendedGrade', 'cyber', 'exam'] if row.get(key))
    meetings = []
    if (code, section) == ('CHS2003', '03'):
        meetings = [{'date': day.isoformat(), 'weekday': day.isoweekday(), 'startMinute': 720, 'endMinute': 795, 'classroom': 'K303', 'deliveryMode': 'inPerson'} for day in sorted(dates + [datetime.date(2026, 10, 20)])]
        notes += '\n계획서에 명시된 일반 수업일과 현재 공개 중간시험10/20만 반영. 미확인 중간시험10/22·기말시험 시각은 생성하지 않음. 비상시 비대면전환 및 추후 휴강·보강 공지 가능.'
    course = {
        'sourceId': f'sogang/unknown/2026/2/{code}-{section}',
        'campus': 'unknown', 'academicYear': 2026, 'semester': '2',
        'courseCode': code, 'section': section, 'courseName': row['title'],
        'professor': row['professor'], 'credits': credit, 'departments': [department],
        'classification': '교양' if code == 'CHS2003' else '',
        'departmentCredits': {department: credit} if credit is not None else {},
        'departmentClassifications': {department: '교양'} if code == 'CHS2003' else {},
        'departmentRemarks': {department: notes}, 'sourceSchedule': row['meetingText'],
        'sourceEducationalMetadata': row,
        'scheduleStatus': 'scheduled' if meetings else 'unrecognized' if row['meetingText'] else 'unscheduled',
        'schedules': meetings,
    }
    if meetings:
        course['period'] = {'startDate': '2026-09-01', 'endDate': '2026-12-10'}
    courses.append(course)
assert len(courses) == 1541
candidate = {'schemaVersion': 2, 'universityId': 'sogang', 'campus': 'unknown', 'campusName': '위치 미확인', 'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-10-08', 'sourceUrl': proof['sourceUrl'], 'courses': courses}
path = ROOT / 'sogang-unknown-2026-2.chs-one-research.json'
path.write_text(json.dumps(candidate, ensure_ascii=False, indent=2) + '\n')
audit = {
    'wholeCount': len(courses), 'scheduled': 1, 'actualMeetings': 28,
    'ordinaryExplicitDates': 27, 'examDate': '2026-10-20', 'weeks': week_proof,
    'planSHA256': proof['fileSha256'],
    'candidateSHA256': hashlib.sha256(path.read_bytes()).hexdigest(),
    'classificationSource': '2026 official 전인교육과정(교양), CHS2003 인간과사상 elective group. Other codes remain unknown without prefix inference.',
    'missingCreditsPreservedAsNull': sum(course['credits'] is None for course in courses),
    'deferredExamDates': ['2026-10-22', '2026-12-15', '2026-12-17'],
    'operatingCaveat': 'Future announcements/emergency changes not known. No ordinary time copied to unknown exam. Explicit ordinary dates exclude current national holidays.',
    'productionRegistered': False, 'completionClaim': False,
}
(ROOT / 'sogang-chs-one-research-audit-20261008.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print('Research-only candidate', len(courses), 'scheduled1 / meetings28; missing credits', audit['missingCreditsPreservedAsNull'])
