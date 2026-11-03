"""Individually reviewed current Korean linguistics dates, research-only snapshot."""
from pathlib import Path
import json, re, datetime, hashlib
r = Path(__file__).parent
base = r / 'sogang-unknown-2026-2.five-individual-reviewed-next.json'
catalog = json.loads(base.read_text())
proofs = []
for (code, section, clock, room, teacher) in [('KOR3010', '01', (720, 795), 'J327', '이지영'), ('KORG001', '01', (630, 705), 'J116', '이지영')]:
    p = r / 'sogang-current-public-plan-education' / f'{code}-{section}.json'
    proof = json.loads(p.read_text())
    t = proof['educationalText']
    row = proof['currentPublicRow']
    assert '2026학년도 2학기' in t and f'과목번호{code}' in t and (f'성명: {teacher}' in t) and (f'[{room}]' in t)
    assert row['subjectCode'] == code and row['section'] == section and (row['professor'] == teacher) and row['meetingText'].endswith(f'[{room}]')
    c = next((c for c in catalog['courses'] if c['courseCode'] == code and c['section'] == section))
    assert not c['schedules']
    old = json.loads(json.dumps(c))
    meetings = []
    evidence = []
    schedule = t.split('Ⅶ. 주차별 수업계획')[1]
    if code == 'KOR3010':
        parts = re.split('(\\d+)\\s*주차\\(([^)]+)\\)', schedule)
        assert len(parts) == 49
        for i in range(1, len(parts), 3):
            week = int(parts[i])
            body = parts[i + 2]
            if week in [8, 16]:
                continue
            days = re.findall('(\\d{1,2})/(\\d{1,2})', parts[i + 1])
            assert len(days) == 2
            for (m, day) in days:
                date = datetime.date(2026, int(m), int(day))
                assert date.isoweekday() in [2, 4]
                if date in [datetime.date(2026, 9, 10), datetime.date(2026, 9, 24)]:
                    continue
                meetings.append({'date': date.isoformat(), 'weekday': date.isoweekday(), 'startMinute': clock[0], 'endMinute': clock[1], 'classroom': room, 'deliveryMode': 'inPerson'})
            evidence.append({'week': week, 'printedDates': parts[i + 1]})
        assert row['exam'] == '10.20(화)12:00~13:15[J327]'
        meetings.append({'date': '2026-10-20', 'weekday': 2, 'startMinute': 720, 'endMinute': 795, 'classroom': 'J327', 'deliveryMode': 'inPerson'})
        assert len(meetings) == 27
        note = '\n계획서의 일반 수업일26회와 현재 공개 중간시험10/20만 반영했습니다. 9/10 개강미사 및9/24 추석은 명시된 휴강입니다. 미확인10/22·기말시험 실제 시각은 생성하지 않습니다. 국어학·언어학 관련 전공과목 하나 이상 선수학습을 권장하며 세부 변경은 추후 공지를 확인하세요.'
    else:
        groups = re.findall('\\((\\d+/\\d+(?:,\\s*\\d+/\\d+)*)\\)', schedule)
        assert len(groups) == 11
        for group in groups:
            if group in ['10/20, 10/22', '12/15, 12/17']:
                continue
            dates = []
            for (m, day) in re.findall('(\\d{1,2})/(\\d{1,2})', group):
                date = datetime.date(2026, int(m), int(day))
                assert date.isoweekday() in [2, 4]
                dates.append(date.isoformat())
                meetings.append({'date': date.isoformat(), 'weekday': date.isoweekday(), 'startMinute': clock[0], 'endMinute': clock[1], 'classroom': room, 'deliveryMode': 'inPerson'})
            evidence.append({'explicitGroupDates': dates})
        assert len(meetings) == 25
        note = '\n계획서의 실제 강의·논문리뷰 날짜25회만 반영했습니다. 9/10 개강미사·9/24 추석 휴강과8·16주 자율학습·과제제출은 출석으로 생성하지 않습니다. 계획서에 미기재된9/29를 임의로 추가하지 않습니다. 국어학·언어학 관련 과목2강좌 이상 이수가 선수학습 조건이며 대학원초급과목·아너스 안내를 유지합니다.'
    c.update(schedules=sorted(meetings, key=lambda x: x['date']), scheduleStatus='scheduled', period={'startDate': '2026-09-01', 'endDate': '2026-12-10'})
    for dep in c['departmentRemarks']:
        c['departmentRemarks'][dep] += note
    assert c['sourceEducationalMetadata'] == old['sourceEducationalMetadata']
    proofs.append({'offering': code + '-' + section, 'actualMeetings': len(meetings), 'sourceFileSHA256': hashlib.sha256(p.read_bytes()).hexdigest(), 'datedEvidence': evidence, 'actualTimeRoomProfessorMatched': True, 'sourceEducationUnchanged': True})
p = r / 'sogang-unknown-2026-2.seven-individual-reviewed-next.json'
p.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
audit = {'whole': 1541, 'scheduled': 7, 'datedMeetings': 158, 'proofs': proofs, 'candidateSHA256': hashlib.sha256(p.read_bytes()).hexdigest(), 'classificationUnknownRetainedForNewTwo': True, 'previousFiveUnchanged': all((a == b for (a, b) in zip(json.loads(base.read_text())['courses'], catalog['courses']) if a['courseCode'] not in ['KOR3010', 'KORG001'])), 'productionRegistered': False, 'completionClaim': False}
assert audit['previousFiveUnchanged']
(r / 'sogang-seven-individual-reviewed-next-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print('Research7/158 meetings; new27+25')
