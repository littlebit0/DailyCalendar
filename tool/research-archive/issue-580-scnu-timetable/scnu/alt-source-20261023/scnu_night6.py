"""국립순천대 2026-2: 원문 '야간 4,5,6'만 쓰는 강좌에 교학규정 제52조 야간 6교시 시각을 적용한다.

대상: 보류 사유가 'published period clock absent: 16' 하나뿐이고, 원문 강의시간이
'요일 야간 N,...'(야간 상대 교시 1~6) 표기인 강좌. 숫자 16 직접 표기(예: 수14,15,16,
야간 14,15,16)는 16번과 야간 6교시의 대응을 원문이 적지 않아 그대로 둔다.
"""
import datetime, json, re, sys

asset_path = sys.argv[1]
NIGHT6 = (22 * 60 + 10, 22 * 60 + 55)  # 교학규정 제52조② 평일 6교시 22:10~22:55
CLOCK = {11 + i: (1080 + i * 50, 1125 + i * 50) for i in range(5)}  # 수업시간표 야간1(11)~야간5(15)
CLOCK[16] = NIGHT6
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}
EXAMS = {str(datetime.date(2026, 10, 19) + datetime.timedelta(days=i)) for i in range(5)}
REASON = ' 일정 미생성: published period clock absent: 16'
NOTE = ' 야간 6교시(22:10~22:55)는 공개 수업시간표 교시표에 없어 국립순천대학교 교학규정 제52조 야간 수업시간표를 따랐습니다.'
PATTERN = re.compile(r'^([월화수목금토일])야간(\d(?:,\d)*)$')

data = json.load(open(asset_path, encoding='utf-8'))
changed = []
for c in data['courses']:
    if c['scheduleStatus'] != 'unrecognized' or not c['remarks'].endswith(REASON):
        continue
    native = re.sub(r'\s+', '', c['sourceSchedule'])
    m = PATTERN.match(native)
    if not m:
        continue
    periods = [int(p) + 10 for p in m[2].split(',')]
    assert all(1 <= p - 10 <= 6 for p in periods), c['sourceId']
    weekday = '월화수목금토일'.index(m[1]) + 1
    assert weekday <= 5, c['sourceId']  # 표는 평일 기준
    room = c['sourceClassroom']
    assert re.fullmatch(r'[A-E]\d{5}', room), c['sourceId']
    blocks = c['nativePeriodBlocks']
    assert [b['nativePeriod'] for b in blocks] == [p for p in periods if p != 16], c['sourceId']
    for b in blocks:
        assert (b['startMinute'], b['endMinute']) == CLOCK[b['nativePeriod']]
    s, e = NIGHT6
    blocks.append({'weekday': weekday, 'nativePeriod': 16, 'startMinute': s, 'endMinute': e, 'classroom': room})
    meetings = []
    day = datetime.date(2026, 9, 1)
    while day <= datetime.date(2026, 12, 7):
        key = str(day)
        if day.isoweekday() == weekday and key not in HOLIDAYS | EXAMS:
            for p in periods:
                a, b = CLOCK[p]
                meetings.append({'weekday': weekday, 'startMinute': a, 'endMinute': b, 'classroom': room, 'date': key})
        day += datetime.timedelta(days=1)
    c['schedules'] = meetings
    c['scheduleStatus'] = 'scheduled'
    c['remarks'] = c['remarks'][: -len(REASON)] + NOTE
    for d, r in list(c['departmentRemarks'].items()):
        assert r.endswith(REASON)
        c['departmentRemarks'][d] = r[: -len(REASON)] + NOTE
    changed.append((c['sourceId'], c['sourceSchedule'], len(meetings)))

with open(asset_path, 'w', encoding='utf-8') as f:
    f.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
for row in changed:
    print(*row, sep=' | ')
print('changed', len(changed), 'meetings', sum(r[2] for r in changed))
