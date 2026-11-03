"""Current accounting time changes, school-specific integer reservation grid."""
import hashlib
import json
import re
from datetime import date, timedelta
from pathlib import Path
from prepare_sch_accounting_candidate import DAY, HOLIDAYS, EXAM

ROOT = Path(__file__).parent
PRIOR = ROOT / 'sch-unknown-2026-2.accounting-five-status-next.json'
PRIOR_SHA = '0f5a5a853ff460831c7812e612c17e05fff685706a98ee5a21ddd1382ebec959'
assert hashlib.sha256(PRIOR.read_bytes()).hexdigest() == PRIOR_SHA
obj = json.loads(PRIOR.read_text())
changed_ids = {'10640', '12796', '10648', '10649', '10650', '12798', '10653'}
review = json.loads((ROOT / 'sch-current-accounting-clock-operating-review-20261008.json').read_text())
conflicts = {r['CORS_NO']: r for r in review['courses'] if r['departmentImageComparison'] == 'conflicting-Aug11-image-current-Oct7-public-source'}
assert set(conflicts) == changed_ids
trace = []
for c in obj['courses']:
    if c['courseCode'] not in changed_ids:
        continue
    raw = c['sourceEducationalMetadata']
    assert raw['OPEN_ORGN_NM'] == '회계학과' and raw['TM_CNT'] == '3' and c['credits'] == 3
    blocks = []
    profile = 'current-major-75-minute-AB-block-rule'
    if re.fullmatch(r'[월화수목금][1-9](?:,[1-9])*', raw['DAY_TM_NM']):
        profile = 'integer-hour-reservation-two-school-half-hour-slots-per-hour'
        day = raw['DAY_TM_NM'][0]
        numbers = [int(n) for n in raw['DAY_TM_NM'][1:].split(',')]
        assert numbers == list(range(numbers[0], numbers[-1] + 1)) and len(numbers) == 3
        # Current school grid nA/nB spans the same numbered hour. The
        # yearbook explicitly defines one lecture hour as two half-hour slots.
        # Preserve reservation interval, never invent a50minute contact end.
        start = 540 + (numbers[0] - 1) * 60
        end = 540 + numbers[-1] * 60
        blocks.append({'weekday': DAY[day], 'startMinute': start, 'endMinute': end, 'classroom': c['sourceClassroom']})
    else:
        for part in raw['DAY_TM_NM'].split('/'):
            m = re.fullmatch(r'([월화수목금])([1-9][AB])-([1-9][AB])', part)
            assert m
            day, first, last = m.groups()
            start = 540 + (int(first[0]) - 1) * 60 + (30 if first[1] == 'B' else 0)
            reserve_end = 540 + (int(last[0]) - 1) * 60 + (60 if last[1] == 'B' else 30)
            assert reserve_end - start == 90
            blocks.append({'weekday': DAY[day], 'startMinute': start, 'endMinute': start + 75, 'classroom': c['sourceClassroom']})
    meetings = []
    current = date(2026, 8, 31)
    while current <= date(2026, 12, 6):
        day = current.isoformat()
        if day not in HOLIDAYS and day not in EXAM:
            meetings += [dict(b, date=day) for b in blocks if b['weekday'] == current.isoweekday()]
        current += timedelta(days=1)
    c['scheduleStatus'] = 'scheduled'
    c['schedules'] = meetings
    c['sourceClockReviewProfile'] = profile
    c['sourceCurrentTimeChangeProof'] = conflicts[c['courseCode']]['exactDifference']
    c['departmentRemarks']['회계학과'] = '\n'.join([
        '회계학과 현재학기 전 과목 대면 원칙(2026-08-11 공식공지)',
        '원표 최신 2026-10-07 요일/교시/강의실 보존; 이전 8월 이미지의 과목 시각을 덮어쓰지 않음.',
        '학교 현재 30분 교시표와 최신 공개 2023 학부 요람 규칙 적용: 정수교시는 해당 번호 A/B 두 칸의 예약 구간이며 실제 접촉50분을 임의 추정하지 않음. A/B3시간 전공 블록은 학교 명시75분 접촉·표시90분을 구분.',
        '일반수업만: 중간·기말평가 및 별도 보강 시각 미생성. 개별 강의계획 추가 비고 미확인.',
        conflicts[c['courseCode']]['exactDifference'],
    ])
    trace.append({'courseCode': c['courseCode'], 'currentLiteral': c['sourceSchedule'], 'profile': profile, 'blocks': blocks, 'datedMeetings': len(meetings)})
assert len(trace) == 7
old = {c['sourceId']: c for c in json.loads(PRIOR.read_text())['courses']}
for c in obj['courses']:
    assert c['sourceEducationalMetadata'] == old[c['sourceId']]['sourceEducationalMetadata']
    for field in ['courseCode','section','courseName','professor','credits','sourceSchedule','sourceClassroom','classification','departments','departmentCredits','departmentClassifications']:
        assert c[field] == old[c['sourceId']][field]
    if c['courseCode'] not in changed_ids:
        assert c == old[c['sourceId']]
path = ROOT / 'sch-unknown-2026-2.accounting-twelve-next.json'
path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n')
audit = {'reviewDate':'2026-10-08','wholeMetadata':2598,'scheduled':12,'unscheduled':235,'unrecognized':2351,
         'added':7,'addedIntegerReservation':4,'addedAB':3,'datedMeetings':sum(len(c['schedules']) for c in obj['courses']),
         'newDatedMeetings':sum(r['datedMeetings'] for r in trace),'metadataMismatches':0,
         'originalSHA256':PRIOR_SHA,'candidateSHA256':hashlib.sha256(path.read_bytes()).hexdigest(),
         'educationClockRulesSource':'sch-latest-public-yearbook-clock-review-20261008.json',
         'currentGridSource':'sch-current-accounting-clock-operating-review-20261008.json',
         'dateSource':'sch-accounting-five-status-next-audit-20261008.json',
         'courses':trace,'productionRegistered':False,'completionClaim':False,
         'limits':['Current source data acquiredOct7; olderAug11 images establish currentsemestercommonclock and departmentmode, not latestcourse times.',
                   'Integer reservation180min is not assertion of180contact minutes; 50minutecontactend has not been inferred.',
                   'Remaining811wholeAB notapproved; other3accountingrowsnotyetadded; nofullindividualplan read.']}
(ROOT / 'sch-accounting-twelve-next-audit-20261008.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:audit[k] for k in ['scheduled','unscheduled','unrecognized','datedMeetings','newDatedMeetings','candidateSHA256']}))
