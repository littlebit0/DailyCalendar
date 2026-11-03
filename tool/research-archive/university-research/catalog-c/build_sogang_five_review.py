"""Current positive printed-date proof, research only; no automatic whole approval."""
from pathlib import Path
import json, re, datetime, hashlib
r = Path(__file__).parent
p = r / 'sogang-current-public-plan-education/COR1012-01.json'
proof = json.loads(p.read_text())
t = proof['educationalText'].replace('\x00', ' ')
row = proof['currentPublicRow']
assert '2026학년도 2학기' in t and '과목번호COR1012-01' in t and ('성명: 전지영' in t) and ('10:30~11:45' in t)
assert row['meetingText'] == '월,수 10:30~11:45 [J202]' and row['professor'] == '전지영'
parts = re.split('(\\d+)\\s*주차', t)
meetings = []
weeks = []
for i in range(1, len(parts), 2):
    week = int(parts[i])
    body = parts[i + 1]
    if week in [8, 13, 14, 15, 16]:
        continue
    dates = re.findall('(\\d{1,2})/(\\d{1,2})', body.split('학습목표')[0])
    assert len(dates) == 2
    assert '수업방법' in body and ('강의' in body or '실습' in body)
    actual = []
    for (m, day) in dates:
        date = datetime.date(2026, int(m), int(day))
        assert date.isoweekday() in [1, 3]
        if date in [datetime.date(2026, 10, 5), datetime.date(2026, 11, 16)]:
            continue
        actual.append(date.isoformat())
        meetings.append({'date': date.isoformat(), 'weekday': date.isoweekday(), 'startMinute': 630, 'endMinute': 705, 'classroom': 'J202', 'deliveryMode': 'inPerson'})
    weeks.append({'week': week, 'confirmedDates': actual})
assert len(meetings) == 20
base = r / 'sogang-unknown-2026-2.four-individual-reviewed-next.json'
d = json.loads(base.read_text())
c = next((c for c in d['courses'] if c['courseCode'] == 'COR1012' and c['section'] == '01'))
assert not c['schedules']
old = json.loads(json.dumps(c))
c.update(schedules=meetings, scheduleStatus='scheduled', partialSchedule=True, classification='교양', period={'startDate': '2026-09-02', 'endDate': '2026-11-23'}, departmentClassifications={dep: '교양' for dep in c['departments']})
for dep in c['departmentRemarks']:
    c['departmentRemarks'][dep] += '\n계획서에 명시된 일반 강의·실습 20회만 반영했습니다. 10/5 공휴일과 장소가 미확정인 11/16 도서관 특강은 생성하지 않습니다. 중간·기말 글쓰기, 13~15주 개별 면담 및12/14 퀴즈의 실제 출석·예약 시각은 확인되지 않아 생성하지 않습니다. 세부 일정은 추후 공지를 확인하세요.'
assert c['sourceEducationalMetadata'] == old['sourceEducationalMetadata']
path = r / 'sogang-unknown-2026-2.five-individual-reviewed-next.json'
path.write_text(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
audit = {'whole': 1541, 'scheduled': 5, 'datedMeetings': 106, 'newCourse': 'COR1012-01', 'actualMeetings': 20, 'weeks': weeks, 'examAttendanceUnconfirmed': True, 'individualAppointmentUnconfirmed': True, 'libraryLocationUnconfirmed': '2026-11-16', 'sourceFileSHA256': hashlib.sha256(p.read_bytes()).hexdigest(), 'candidateSHA256': hashlib.sha256(path.read_bytes()).hexdigest(), 'previousFourUnchanged': all((a == b for (a, b) in zip(json.loads(base.read_text())['courses'], d['courses']) if not (a['courseCode'] == 'COR1012' and a['section'] == '01'))), 'sourceEducationalMetadataUnchanged': True, 'productionRegistered': False, 'completionClaim': False}
assert audit['previousFourUnchanged']
(r / 'sogang-five-individual-reviewed-next-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print('Research5/106 meetings')
