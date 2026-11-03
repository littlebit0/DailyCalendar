"""Two current Korean literature plans with individually printed teaching dates."""
import datetime as dt
import hashlib
import json
import re
from pathlib import Path

root = Path(__file__).parent
base = root / 'sogang-unknown-2026-2.seventeen-individual-and-published-plan-next.json'
catalog = json.loads(base.read_text())
proofs = []
for code, start, room in [('KOR2200', 720, 'J207'), ('KOR3203', 900, 'J327')]:
    source = root / 'sogang-current-public-plan-education' / (code + '-01.json')
    data = json.loads(source.read_text())
    text = re.sub(r'\s+', '', data['educationalText'])
    row = data['currentPublicRow']
    assert '2026학년2학기' in text and '황윤정' in text and code in text
    assert row['professor'] == '황윤정' and row['subjectCode'] == code
    assert row['year'] == '2026 학년도' and row['semester'] == '2학기'
    assert row['meetingText'] == f'화,목 {start//60:02}:{start%60:02}~{(start+75)//60:02}:{(start+75)%60:02} [{room}]'
    assert '1주차(9월1,3일)' in text and '15주차(12월8,10일)' in text
    assert '8주차(10월20,22일)' in text and '중간고사' in text
    assert '16주차(12월15,17일)' in text and '기말' in text
    assert text.count('수업방법:대면강의') == 14
    assert row['exam'] == f'10.20(화){start//60:02}:{start%60:02}~{(start+75)//60:02}:{(start+75)%60:02}[{room}]'
    meetings = []
    date = dt.date(2026, 9, 1)
    while date <= dt.date(2026, 12, 10):
        if date.weekday() in (1, 3) and date != dt.date(2026, 9, 24) and not dt.date(2026, 10, 20) <= date <= dt.date(2026, 10, 26):
            meetings.append({'date': date.isoformat(), 'weekday': date.isoweekday(), 'startMinute': start, 'endMinute': start + 75, 'classroom': room, 'deliveryMode': 'inPerson'})
        date += dt.timedelta(days=1)
    assert len(meetings) == 27
    meetings.append({'date': '2026-10-20', 'weekday': 2, 'startMinute': start, 'endMinute': start + 75, 'classroom': room, 'deliveryMode': 'inPerson'})
    meetings.sort(key=lambda m: m['date'])
    course = next(c for c in catalog['courses'] if c['courseCode'] == code and c['section'] == '01')
    assert not course['schedules']
    course.update(schedules=meetings, scheduleStatus='scheduled', partialSchedule=True,
        period={'startDate': '2026-09-01', 'endDate': '2026-12-10'},
        scheduleEvidence={'basis':'currentPublicPlanPrintedWeekDates', 'ordinaryDateCount':27, 'publishedExamDateCount':1, 'actualAttendanceConfirmed':False})
    note = '\n현재 분반의 공개 계획서에 기재된 대면 수업 날짜 27회와 공개된 10/20 중간시험 1회를 반영했습니다. 추석 휴강은 제외하고 중간시험의 다른 날짜 및 기말시험의 미확정 일시는 생성하지 않습니다. 개별 실제 출석 기록이 아닌 학교 공시 수업 계획이며 변경 사항은 학교 공지를 확인하세요.'
    for department in course['departmentRemarks']:
        course['departmentRemarks'][department] += note
    proofs.append({'offering':code+'-01','ordinaryDates':27,'publishedMidterm':'2026-10-20','sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'coverYearSemesterCodeTeacherAndTimeMatched':True,'ordinaryDatesPrintedInSource':True})
output = root / 'sogang-unknown-2026-2.nineteen-reviewed-next.json'
output.write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n')
old = json.loads(base.read_text())['courses']
assert all(a == b for a,b in zip(old,catalog['courses']) if a['courseCode'] not in {'KOR2200','KOR3203'})
assert sum(bool(c['schedules']) for c in catalog['courses']) == 19
assert sum(len(c['schedules']) for c in catalog['courses']) == 457
(root/'sogang-nineteen-reviewed-next-audit.json').write_text(json.dumps({'whole':1541,'scheduled':19,'datedMeetings':457,'priorSeventeenUnchanged':True,'proofs':proofs,'candidateSHA256':hashlib.sha256(output.read_bytes()).hexdigest(),'productionRegistered':False,'completionClaim':False},ensure_ascii=False,indent=2)+'\n')
print('Research19/457; previous17 unchanged')
