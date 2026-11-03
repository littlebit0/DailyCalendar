import json, re, datetime, hashlib
from pathlib import Path
r = Path('work/university-research/catalog-c')
p = r / 'sogang-current-public-plan-education/COR1012-17.json'
proof = json.loads(p.read_text())
t = proof['educationalText']
row = proof['currentPublicRow']
assert '2026년도 2학기' in t and '과목번호COR1012-17' in t and ('성명: 염수민' in t) and ('화, 목 15:00~16:15' in t)
assert row['meetingText'] == '화,목 15:00~16:15 [J325]' and row['professor'] == '염수민'
blocks = re.split('(\\d+)\\s*주차\\((\\d+/\\d+)\\)\\((\\d+/\\d+)\\)', t)
assert len(blocks) == 65
meetings = []
evidence = []
for i in range(1, len(blocks), 4):
    week = int(blocks[i])
    dates = [datetime.date(2026, *map(int, blocks[j].split('/'))) for j in [i + 1, i + 2]]
    body = blocks[i + 3]
    if week in (8, 16):
        assert '과제 제출' in body
        continue
    if week in (14, 15):
        assert '비대면 개별 면담' in body
        continue
    assert '수업방법' in body and ('강의' in body or '실습' in body)
    for date in dates:
        assert date.isoweekday() in (2, 4)
        if date == datetime.date(2026, 9, 24):
            continue
        meetings.append({'date': date.isoformat(), 'weekday': date.isoweekday(), 'startMinute': 900, 'endMinute': 975, 'classroom': 'J325', 'deliveryMode': 'inPerson'})
    evidence.append({'week': week, 'actualPrintedDates': [x.isoformat() for x in dates]})
assert len(meetings) == 23
base = r / 'sogang-unknown-2026-2.chs-cor-two-notes-reviewed-next.json'
d = json.loads(base.read_text())
c = next((c for c in d['courses'] if c['courseCode'] == 'COR1012' and c['section'] == '17'))
old = json.loads(json.dumps(c))
assert not c['schedules']
c['schedules'] = meetings
c['scheduleStatus'] = 'scheduled'
c['classification'] = '교양'
c['departmentClassifications'] = {dep: '교양' for dep in c['departments']}
c['period'] = {'startDate': '2026-09-01', 'endDate': '2026-11-26'}
notes = '\n계획서에 명시된 일반 수업일만 반영했습니다. 중간·기말은 글쓰기 과제 제출로 안내되어 시험 예약 시각을 출석 일정으로 생성하지 않습니다. 12/1·3·8·10 비대면 개별 면담과 12/10 퀴즈의 실제 예약 시각은 확인되지 않아 생성하지 않습니다. 도서관 연계 특강 및 추후 공지에 따라 변경될 수 있습니다.'
for dep in c['departmentRemarks']:
    c['departmentRemarks'][dep] += notes
assert c['sourceEducationalMetadata'] == old['sourceEducationalMetadata']
nextp = r / 'sogang-unknown-2026-2.three-individual-reviewed-next.json'
nextp.write_text(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
audit = {'whole': 1541, 'scheduled': 3, 'datedMeetings': 74, 'newCourse': 'COR1012-17', 'actualMeetings': 23, 'sourceFileSHA256': hashlib.sha256(p.read_bytes()).hexdigest(), 'candidateSHA256': hashlib.sha256(nextp.read_bytes()).hexdigest(), 'ordinaryDateProof': evidence, 'exclusions': {'holiday': ['2026-09-24'], 'assignmentOnlyWeeks': [8, 16], 'unknownIndividualRemoteWeeks': [14, 15]}, 'classificationProof': 'Same current COR1012 common-required group already independently verified, not guessed from prefix', 'previousTwoCoursesUnchanged': all((a == b for (a, b) in zip(json.loads(base.read_text())['courses'], d['courses']) if a['section'] != '17' or a['courseCode'] != 'COR1012')), 'sourceEducationUnchanged': True, 'productionRegistered': False, 'completionClaim': False}
assert audit['previousTwoCoursesUnchanged']
(r / 'sogang-three-individual-reviewed-next-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print('research immutable3courses/74meetings; actual17=23')
