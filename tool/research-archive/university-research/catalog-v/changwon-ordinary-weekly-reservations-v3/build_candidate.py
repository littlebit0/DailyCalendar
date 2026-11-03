# coding: utf-8
"""Current own-clock weekly reservation subset; prior eleven dated plans retained."""
import collections
import copy
import datetime as dt
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent
SOURCE = ROOT.parent


def read(path):
    return json.loads(path.read_text())


def save(name, value):
    (ROOT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


base = read(SOURCE / 'changwon-unknown-2026-2.eleven-dated-v2.json')
candidate = copy.deepcopy(base)
clock_proof = read(ROOT / 'current-undergraduate-native-clock-education.json')
clock = {r['nativePeriod']: (r['startMinute'], r['endMinute']) for r in clock_proof['nativePublishedPeriodClockRows']}
calendar = read(SOURCE / 'changwon-current-semester-calendar-20261008.json')
assert any(r['schdulTitle'] == '2026-2학기 개강' and r['bgnde'] == '2026/09/01' for r in calendar['rows'])
assert any(r['schdulTitle'] == '보강주' and r['bgnde'] == '2026/12/08' for r in calendar['rows'])
assert any(r['schdulTitle'] == '기말고사' and r['bgnde'] == '2026/12/14' for r in calendar['rows'])
assert any('1AB 임시휴강' in r['schdulTitle'] and r['bgnde'] == '2026/11/19' for r in calendar['rows'])
assert any('임시휴강 예정' in r['schdulTitle'] and r['bgnde'] == '2026/11/24' for r in calendar['rows'])
holiday_reference = read(ROOT.parent.parent / 'catalog-w' / 'sookmyung-expanded-public-partial-v16' / 'national-holiday-date-reference.json')
holiday_dates = set(holiday_reference['conservativeUnknownOperationHoldDates'])
start, end = dt.date(2026, 9, 1), dt.date(2026, 12, 7)
token = re.compile(r'([월화수목금토일])(\d{1,2})([AB])(?:\(([^()]*)\))?')
exception = re.compile(r'집중이수|비연속|현장실습|현장학습|현장조사|견학|답사|비대면\s*(?:강의|수업)|온라인\s*(?:강의|수업)|녹화\s*강의|동영상\s*강의')
accepted_types = {'일반강의', '영어강의', '제2외국어강의', '외국인전용강좌', '팀티칭'}
plans = []
decisions = []
closed = read(SOURCE / 'changwon-current-closures-20261008.json')
closed_keys = {(r['code'], r['section']) for r in closed}
assert len(candidate['courses']) == 1754

for c in candidate['courses']:
    key = c['courseCode'] + '-' + c['section']
    path = SOURCE / 'public-plans-20261008' / (key + '.json')
    plan = read(path)
    fields = plan['fields']
    records = c['sourceEducation']['originalPublicRows']
    assert fields['학수번호'] == c['courseCode'] and fields['분반'] == c['section']
    assert all(fields['강의시간(장소)'] == r['schedule'] and fields['강의진행방식'] == r['lectureType'] and fields['수업운영방식'] == r['deliveryMode'] for r in records)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    plans.append({'key': key, 'sourceFile': str(path.relative_to(SOURCE)), 'sha256': digest})
    if c['schedules']:
        decisions.append({'key': key, 'kind': 'priorExplicitDatedPlanPreserved', 'count': len(c['schedules'])})
        continue
    hold = []
    if (c['courseCode'], c['section']) in closed_keys:
        hold.append('current published undergraduate closure')
    if fields['강의진행방식'] not in accepted_types:
        hold.append('native special delivery/intensive/practice type: ' + fields['강의진행방식'])
    if fields['수업운영방식'] != '대면':
        hold.append('native remote/mixed operation, individual weekly session mapping unknown')
    conflicts = [field for field in ['professor', 'schedule', 'credits', 'lectureType', 'deliveryMode'] if len({r[field] for r in records}) > 1]
    # Public marker differences remain original query variants, not invented identities.
    if len({r['title'].rstrip(' ★') for r in records}) > 1:
        conflicts.append('title excluding only trailing published star marker')
    if conflicts:
        hold.append('native query field conflict: ' + ', '.join(conflicts))
    operation_rows = [w for w in plan['weekly'] if exception.search(' '.join(w['education']))]
    if operation_rows:
        hold.append('individual explicit intensive/field/remote operation evidence; exact ordinary versus exception dates not mapped from week numbers')
    text = c['sourceSchedule']
    matches = list(token.finditer(text))
    if not matches or token.sub('', text).strip(', '):
        hold.append('native weekly clock tokens unavailable')
    parts = []
    rooms = {}
    for m in matches:
        weekday = '월화수목금토일'.index(m[1]) + 1
        period = m[2] + m[3]
        if period not in clock:
            hold.append('current own period clock not published: ' + period)
            continue
        if m[4]:
            rooms[weekday] = m[4]
        room = rooms.get(weekday, '')
        if not room:
            hold.append('native weekday classroom unavailable, no cross-day room inference')
        a, b = clock[period]
        parts.append({'weekday': weekday, 'startMinute': a, 'endMinute': b, 'classroom': room, 'nativePeriod': period})
    merged = []
    for part in parts:
        if merged and all(merged[-1][k] == part[k] for k in ['weekday', 'classroom']) and merged[-1]['endMinute'] == part['startMinute']:
            merged[-1]['endMinute'] = part['endMinute']
            merged[-1]['nativePeriods'].append(part['nativePeriod'])
        else:
            merged.append({**{k: part[k] for k in ['weekday', 'startMinute', 'endMinute', 'classroom']}, 'nativePeriods': [part['nativePeriod']]})
    identities = [(r['weekday'], r['startMinute'], r['endMinute'], r['classroom']) for r in merged]
    if len(identities) != len(set(identities)):
        hold.append('duplicate/ambiguous native weekly blocks')
    for i, a in enumerate(merged):
        if any(a['weekday'] == b['weekday'] and a['startMinute'] < b['endMinute'] and b['startMinute'] < a['endMinute'] for b in merged[i+1:]):
            hold.append('overlapping native blocks/room assignment ambiguity')
    hold = list(dict.fromkeys(hold))
    exam_dates = sorted(set(re.findall(r'2026\.(\d{1,2})\.(\d{1,2})', fields.get('시험일시', ''))))
    exam_dates = ['2026-' + month.zfill(2) + '-' + day.zfill(2) for month, day in exam_dates]
    slots = []
    if not hold:
        for block in merged:
            date = start
            while date <= end:
                if date.isoweekday() == block['weekday'] and date.isoformat() not in holiday_dates and date.isoformat() not in exam_dates and date.isoformat() != '2026-11-24':
                    a, b = block['startMinute'], block['endMinute']
                    if date.isoformat() == '2026-11-19':
                        a = max(a, 600)  # Published temporary 1A/1B hold only.
                    if a < b:
                        slots.append({'weekday': block['weekday'], 'startMinute': a, 'endMinute': b, 'classroom': block['classroom'], 'date': date.isoformat()})
                date += dt.timedelta(days=1)
    c['sourceEducation']['currentPublicPlanFields'] = fields
    c['sourceEducation']['currentPublicPlanReceipt'] = {'sourceFile': str(path.relative_to(SOURCE)), 'sha256': digest, 'sourceURL': plan['sourceURL'], 'checkedAt': plan['checkedAt']}
    c['sourceEducation']['weeklyOperationEvidence'] = operation_rows
    c['sourceEducation']['regularReservationReview'] = {'kind': 'held' if hold else 'publicWeeklyReservation', 'holdReasons': hold, 'nativeClockBlocks': merged, 'individualPublishedExamDateHold': exam_dates, 'actualAttendanceConfirmed': False, 'noWeekToAttendanceInference': True}
    note = '공개 정규 시간표 예약의 부분범위9/1–12/7이며 실제 출석·개별강의/시험 구분·최신변경 완료 확인이 아닙니다. 자체9/1개강과12/8보강주에 따라12/7을 파생했으며 printed최종수업일이 아닙니다. 현재학부안내의1A–9B30분/10A–14B25분 원문clock만 사용했고15AB는추정하지 않았습니다. 원문대면 표기는 보존하되 사용자 수업방식3모드 선택을 유지합니다. 법정휴일과11/24임시휴강예정·11/19 1AB예정은 미확정운영 보수적예약보류입니다. 명시된 개인시험날짜는 수업예약에서 제외하고 시험약속을 발명하지 않습니다. 자체중간시험주가별도게시되지않아 임의학교시험주나 주차별날짜를 만들지 않았습니다. 실제class/exam운영과Campus는미확인입니다.'
    if hold:
        note += ' 예약보류: ' + '; '.join(hold)
    elif exam_dates:
        note += ' 개별시험 원문날짜 보류: ' + ', '.join(exam_dates)
    c['remarks'] = c['remarks'].split('일반·집중·원격 수업의 개별 날짜')[0] + note
    if fields.get('선수과목 및 수강필수조건'):
        c['remarks'] += '\n선수과목 및 수강필수조건 원문: ' + fields['선수과목 및 수강필수조건']
    c['departmentRemarks'] = {department: c['remarks'] for department in c['departmentRemarks']}
    c['sourceClassroom'] = ' / '.join(dict.fromkeys(r['classroom'] for r in parts if r['classroom']))
    c['schedules'] = slots
    c['scheduleStatus'] = 'scheduled' if slots else ('unscheduled' if not text else 'unrecognized')
    if slots:
        c['period'] = {'startDate': start.isoformat(), 'endDate': end.isoformat()}
    decisions.append({'key': key, 'kind': 'newRegularReservation' if slots else 'held', 'count': len(slots), 'holdReasons': hold})

candidate.update(candidateRevision='ordinary-weekly-reservations-v3', researchOnly=True, completionClaim=False)
save('changwon-unknown-2026-2.ordinary-weekly-v3.json', candidate)
save('source-period-operation-proof.json', {'researchOnly': True, 'completionClaim': False, 'currentOwnCalendar': calendar, 'currentPublishedUndergraduateClosures': closed, 'nationalDateReferenceOnly': holiday_reference, 'allCurrentPublicPlanReceipts': plans, 'decisions': decisions, 'derivedRegularReservationBoundary': {'start': start.isoformat(), 'end': end.isoformat(), 'meaning': 'own opening through day before own makeup week; not printed final lecture day'}, 'wholeOperatingComplete': False})
print('native', len(candidate['courses']), 'scheduled', sum(bool(c['schedules']) for c in candidate['courses']), 'datedSlots', sum(len(c['schedules']) for c in candidate['courses']), 'decisions', dict(collections.Counter(r['kind'] for r in decisions)))
