"""Source-only SKU blank-room reservations; preserve other held boundaries."""
import collections
import datetime as dt
import hashlib
import json
import re
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
SOURCE = OUT.parent


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


proof = json.loads((SOURCE / 'sku-current-native-education-proof-v1.json').read_text())
clocks = {int(k): v for k, v in proof['clocks'].items()}
closed = {(r['courseCode'], r['section']) for r in proof['closureRows']}
holidays = {'2026-09-24', '2026-09-25', '2026-10-05', '2026-10-09', '2026-10-23'}
changed = []
queue = []
counts = {}
for campus in ('main', 'unknown'):
    path = ROOT / f'assets/timetable/sku-{campus}-2026-2.json'
    data = json.loads(path.read_text())
    write(OUT / f'{path.stem}.baseline.json', data)
    for course in data['courses']:
        metadata = course.get('metadata') or {}
        if course.get('schedules'):
            continue
        reason = metadata.get('heldReason')
        if reason != '원문 강의실 미공개':
            queue.append({'sourceId': course['sourceId'], 'heldReason': reason})
            continue
        if course.get('sourceClassroom') or metadata.get('closureMatched') or (course['courseCode'], course['section']) in closed:
            raise ValueError('Blank-room scope or closure mismatch')
        raw = re.sub(r'\s+', '', course['sourceSchedule'])
        groups = list(re.finditer(r'([월화수목금토일]+)(\d+(?:\.\d+)*)', raw))
        if ''.join(g[0] for g in groups) != raw:
            raise ValueError('Unparsed native weekday/period')
        spans = []
        for group in groups:
            for day in group[1]:
                for period in group[2].split('.'):
                    start, end = clocks[int(period)]
                    spans.append({'weekday': '월화수목금토일'.index(day) + 1,
                                  'startMinute': start, 'endMinute': end, 'classroom': ''})
        appointments = []
        date = dt.date(2026, 9, 1)
        while date <= dt.date(2026, 12, 7):
            if date.isoformat() not in holidays and not dt.date(2026, 10, 20) <= date <= dt.date(2026, 10, 26):
                appointments.extend(dict(span, date=date.isoformat()) for span in spans if span['weekday'] == date.isoweekday())
            date += dt.timedelta(days=1)
        course['schedules'] = appointments
        course['scheduleStatus'] = 'scheduled'
        course['remarks'] = course['remarks'].replace(' / 예약 보류: 원문 강의실 미공개', '')
        course['remarks'] += '\n강의실은 원문 미공개로 빈값을 유지합니다. 공개 요일·교시의 정규 예약만 반영하며 개인별 실제 출석·최신 변경 확인을 의미하지 않습니다.'
        metadata.pop('heldReason', None)
        metadata['blankRoomReservationEvidence'] = {
            'nativeClockProof': 'work/university-research/catalog-r/sku/sku-current-native-education-proof-v1.json',
            'sameOwnCalendarAsExistingReservations': True,
            'sourceClassroomUnpublished': True,
            'actualAttendanceConfirmed': False,
            'individualOperatingDatesConfirmed': False,
        }
        changed.append({'sourceId': course['sourceId'], 'nativeSchedule': course['sourceSchedule'],
                        'appointments': len(appointments), 'classroom': ''})
    data.update(researchOnly=True, productionIntegrationEnabled=False, completionClaim=False)
    counts[campus] = {'whole': len(data['courses']), 'scheduled': sum(bool(c['schedules']) for c in data['courses']),
                      'appointments': sum(len(c['schedules']) for c in data['courses'])}
    write(OUT / f'{path.stem}.blank-room-candidate.json', data)
write(OUT / 'proof.json', {'changed': changed, 'heldQueue': queue, 'counts': counts,
                         'addedCourses': len(changed), 'addedReservations': sum(c['appointments'] for c in changed),
                         'sdkVerification': 'not_run', 'completionClaim': False})
write(OUT / 'SHA256SUMS.json', {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.iterdir() if p.name != 'SHA256SUMS.json'})
print('Prepared SKU blank-room courses:', len(changed), 'reservations:', sum(c['appointments'] for c in changed))
