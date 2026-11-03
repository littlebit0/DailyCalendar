"""Individually printed ENG2112/GKS4015 ordinary dates; no guessed finals."""
import datetime
import hashlib
import json
import re
from pathlib import Path

root = Path(__file__).parent
base = root / 'sogang-unknown-2026-2.ten-individual-reviewed-next.json'
catalog = json.loads(base.read_text())
proofs = []
for code, room, start, end, teacher, teacherText in [
    ('ENG2112', 'J102', 630, 705, '허윤석', 'Yoonseok Heo(허윤석)'),
    ('GKS4015', 'X428', 990, 1065, '오준호', 'Junho Oh'),
]:
    source = root / 'sogang-current-public-plan-education' / f'{code}-01.json'
    proof = json.loads(source.read_text())
    text = proof['educationalText']
    row = proof['currentPublicRow']
    assert row['subjectCode'] == code and row['section'] == '01'
    assert row['professor'] == teacher and row['meetingText'].endswith(f'[{room}]')
    assert code in text and '2026' in text and teacherText in text
    if code == 'ENG2112':
        assert 'Mon/Wed 10:30 ~ 11:45' in text and 'conducted in person' in text
        assert '10/21(Wed) – Advance class for Oct. 28.' in text
        assert row['exam'] == '10.26(월)10:30~11:45[J102]'
        schedule = text.split('Ⅶ. Course Schedule', 1)[1].split('Week 16', 1)[0]
        # Include every explicit week header, including dates printed after
        # Week10/14 across page breaks; exclude repeated dates in body notes.
        groups = re.findall(r'Week\s+(\d+)\s*\((\d+/\d+)[,\s]+(\d+/\d+)\)', schedule)
        if len(groups) != 15:
            # PDF extraction places the first topic after Week10 and Week14,
            # but the exact parenthetical date group remains unambiguous.
            groups = re.findall(r'\((\d+/\d+)[,\s]+(\d+/\d+)\)', schedule)
            assert len(groups) == 15
            pairs = groups
        else:
            pairs = [(a, b) for _, a, b in groups]
        dates = [d for pair in pairs for d in pair]
        excluded = {'2026-09-07', '2026-10-05', '2026-10-28'}
        note = '\n현재 분반 계획서에 명시된 일반 대면 수업 26회와 현재 공개된 10/26 중간시험 1회를 반영했습니다. 9/7 녹화영상 대체, 10/5 공휴일, 10/28 국제학회 휴강을 제외하며 10/21은 명시된 앞당긴 수업입니다. 기말시험 실제 일시와 개강일 배포 최종 계획서 변경은 추가 확인이 필요합니다. 실습용 노트북 지참을 권장하며 발표에는 전원 참석해야 합니다.'
    else:
        assert 'Mon. Wed. 16:30-17:45' in text
        schedule = text.split('V. Course Schedule', 1)[1]
        ordinary = schedule.split('12/16 (Wed), 12/21 (Mon)', 1)[0]
        pairs = re.findall(r'(\d{1,2})/(\d{1,2})\s*\((?:Wed|Mon)\)', ordinary)
        assert len(pairs) == 30
        dates = [f'{m}/{d}' for m, d in pairs]
        excluded = {'2026-10-05', '2026-10-21', '2026-10-26'}
        assert 'no regular class' in schedule and 'independently between 9/30 and 10/7' in schedule
        note = '\n현재 분반 계획서에 명시된 일반 수업·발표 27회를 반영했습니다. 10/5 공휴일과 10/21·10/26 중간시험 기간의 조건부 발표 연장은 확정 출석으로 생성하지 않습니다. 12/16·12/21도 발표가 미완료인 경우에만 연장되므로 제외했습니다. 9/30 수업의 현장기록 안내 이후 10/7까지 수행하는 개별 현장조사와 과제 마감은 정규 교실 출석 일정으로 생성하지 않습니다.'
    meetings = []
    printedDates = []
    for day in dates:
        month, number = map(int, day.split('/'))
        date = datetime.date(2026, month, number)
        assert date.isoweekday() in (1, 3)
        printedDates.append(date.isoformat())
        if date.isoformat() in excluded:
            continue
        meetings.append({'date': date.isoformat(), 'weekday': date.isoweekday(),
                         'startMinute': start, 'endMinute': end,
                         'classroom': room, 'deliveryMode': 'inPerson'})
    assert len(meetings) == 27 and len({x['date'] for x in meetings}) == 27
    course = next(c for c in catalog['courses'] if c['courseCode'] == code and c['section'] == '01')
    old = json.loads(json.dumps(course))
    assert not course['schedules']
    course.update(schedules=meetings, scheduleStatus='scheduled',
                  period={'startDate': '2026-09-02', 'endDate': '2026-12-14'}, partialSchedule=True)
    for department in course['departmentRemarks']:
        course['departmentRemarks'][department] += note
    assert course['sourceEducationalMetadata'] == old['sourceEducationalMetadata']
    proofs.append({'offering': code+'-01', 'actualMeetings': 27,
                   'actualCurrentClockRoomTeacherIdentityConfirmed': True,
                   'printedDates': printedDates, 'excludedDates': sorted(excluded),
                   'sourceFileSHA256': hashlib.sha256(source.read_bytes()).hexdigest(),
                   'sourceEducationUnchanged': True})
output = root / 'sogang-unknown-2026-2.twelve-individual-reviewed-next.json'
output.write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n')
audit = {'whole': 1541, 'scheduled': 12, 'datedMeetings': 264, 'newProofs': proofs,
         'candidateSHA256': hashlib.sha256(output.read_bytes()).hexdigest(),
         'previousTenUnchanged': all(a == b for a, b in zip(json.loads(base.read_text())['courses'], catalog['courses']) if a['courseCode'] not in ['ENG2112','GKS4015']),
         'productionRegistered': False, 'completionClaim': False}
assert audit['previousTenUnchanged']
(root/'sogang-twelve-individual-reviewed-next-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2)+'\n')
print('Research12/264; two exact27-date courses. Not production registered.')
