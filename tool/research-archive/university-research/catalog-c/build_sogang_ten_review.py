"""Exact printed ordinary dates of current MGT2002-02; research snapshot."""
import datetime
import hashlib
import json
import re
from pathlib import Path

root = Path(__file__).parent
base = root / 'sogang-unknown-2026-2.nine-individual-reviewed-next.json'
source = root / 'sogang-current-public-plan-education/MGT2002-02.json'
proof = json.loads(source.read_text())
text = proof['educationalText']
row = proof['currentPublicRow']
assert row['subjectCode'] == 'MGT2002' and row['section'] == '02'
assert row['professor'] == '이윤동' and row['meetingText'] == '화,목 13:30~14:45 [MA102]'
compact = re.sub(r'\s+', '', text)
assert 'MGT2002-02' in compact and '2026년2학기' in compact
assert '대면강의로진행' in compact and '중간시험(사이버캠퍼스)' in compact
assert '화/목13:30–14:45' in compact and '(MA102)' in compact and '이윤동' in compact
schedule = text.split('표  1: 2026-2 학기  주차별  강의계획', 1)[1]
printed = re.findall(r'(\d{2})/(\d{2})\s+([화목])', schedule)
assert len(printed) == 32
omitted = {'2026-09-24', '2026-10-20', '2026-10-22', '2026-12-15', '2026-12-17'}
meetings = []
for month, day, weekday in printed:
    date = datetime.date(2026, int(month), int(day))
    assert date.isoweekday() == {'화': 2, '목': 4}[weekday]
    if date.isoformat() in omitted:
        continue
    meetings.append({'date': date.isoformat(), 'weekday': date.isoweekday(),
                     'startMinute': 810, 'endMinute': 885,
                     'classroom': 'MA102', 'deliveryMode': 'inPerson'})
assert len(meetings) == 27 and len({x['date'] for x in meetings}) == 27
catalog = json.loads(base.read_text())
course = next(c for c in catalog['courses'] if c['courseCode'] == 'MGT2002' and c['section'] == '02')
old = json.loads(json.dumps(course))
assert not course['schedules']
course.update(schedules=meetings, scheduleStatus='scheduled',
              period={'startDate': '2026-09-01', 'endDate': '2026-12-10'}, partialSchedule=True)
note = '\n현재 2026년 2학기 분반별 계획서에 명시된 일반 대면 수업 27회를 반영했습니다. 9/24 추석 휴강, 10/20·12/15 수업 없음은 제외했습니다. 10/22 중간시험은 사이버캠퍼스 방식이고 실제 접속·응시 시간은 확인 중이며, 12/17 기말시험도 실제 시각이 미확정이므로 일반 대면 강의로 생성하지 않습니다. 휴강 보강·방역 시 실시간 온라인 전환은 별도 공지 확인이 필요합니다.'
for department in course['departmentRemarks']:
    course['departmentRemarks'][department] += note
assert course['sourceEducationalMetadata'] == old['sourceEducationalMetadata']
output = root / 'sogang-unknown-2026-2.ten-individual-reviewed-next.json'
output.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
audit = {'whole': 1541, 'scheduled': 10, 'datedMeetings': 210,
         'offering': 'MGT2002-02', 'newActualMeetings': 27,
         'printedDates': [f'2026-{m}-{d}' for m, d, _ in printed],
         'excludedDates': sorted(omitted),
         'ordinaryDelivery': 'inPerson', 'examDeliveryOrClockUnconfirmed': True,
         'sourceFileSHA256': hashlib.sha256(source.read_bytes()).hexdigest(),
         'candidateSHA256': hashlib.sha256(output.read_bytes()).hexdigest(),
         'previousNineUnchanged': all(a == b for a, b in zip(json.loads(base.read_text())['courses'], catalog['courses']) if not (a['courseCode'] == 'MGT2002' and a['section'] == '02')),
         'sourceEducationUnchanged': course['sourceEducationalMetadata'] == old['sourceEducationalMetadata'],
         'productionRegistered': False, 'completionClaim': False}
assert audit['previousNineUnchanged'] and audit['sourceEducationUnchanged']
(root / 'sogang-ten-individual-reviewed-next-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print('Research10/210; MGT02 exact27 ordinary dates.')
