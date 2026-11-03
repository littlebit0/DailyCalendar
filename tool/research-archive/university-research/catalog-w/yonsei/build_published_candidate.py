"""Project only published native reservations; preserve uncertain operation as holds."""
import collections
import datetime as dt
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent
SOURCE = Path('work/university-research/catalog-d/yonsei-2026-2-public-all.json')
source = json.loads(SOURCE.read_text())
assert not source['capped'] and len(source['scopes']) == 329
groups = collections.defaultdict(list)
for row in source['records']:
    assert row['syy'] == '2026' and row['smtDivCd'] == '20'
    groups[(row['sysinstDivCd'], row['subjtnb'], row['corseDvclsNo'], row['prctsCorseDvclsNo'])].append(row)
assert len(groups) == 4926
CAMPUS = {'신촌': 'sinchon', '국제': 'international', '미래': 'mirae'}
FIELDS = ['sysinstDivCd', 'orgSysinstDivCd', 'campsBusnsCd', 'campsDivNm', 'subjtnb', 'corseDvclsNo', 'prctsCorseDvclsNo', 'subjtnbCorsePrcts', 'subjtNm', 'subjtEngNm', 'cgprfNm', 'cgprfEngNm', 'cdt', 'hy', 'rcognHrs', 'subsrtDivNm', 'estblDeprtNm', 'subjtClNm', 'srclnLctreLangDivNm', 'lctreTimeNm', 'lecrmNm', 'atntnMattrDesc', 'lessnSessnDivNm', 'rmvlcYn', 'rmvlcYnNm', 'syy', 'smtDivCd']
CLOCK = {p: ((8 + p) * 60, (8 + p) * 60 + 50) for p in range(11)}
DAYS = '월화수목금토'
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}
DATES = []
current = dt.date(2026, 9, 1)
while current <= dt.date(2026, 12, 7):
    if current.isoformat() not in HOLIDAYS and not dt.date(2026, 10, 20) <= current <= dt.date(2026, 10, 26):
        DATES.append(current)
    current += dt.timedelta(days=1)


def reservations(row):
    if row['sysinstDivCd'] not in {'H1', 'H2'}:
        return [], '교차 개설 소속의 개별 수업 시각과 기간을 확인하지 못했습니다.'
    if row['campsDivNm'] not in CAMPUS:
        return [], '이 강좌의 실제 캠퍼스를 확인하지 못했습니다.'
    if row['lessnSessnDivNm'] != '학기':
        return [], '단기 세션의 개별 수업 날짜를 확인하지 못했습니다.'
    kind = (row['subjtClNm'] or '').strip()
    if kind not in {'대면강의', '비대면(실시간)'}:
        return [], '온라인·혼합 수업의 개별 운영 날짜를 확인하지 못했습니다.'
    notes = row['atntnMattrDesc'] or ''
    if '75분' in notes or any(t in notes for t in ['집중이수', '격주', '블록수업', '실제수업시간', '실제 수업시간']):
        return [], '별도 수업 시각 또는 운영 조건을 확인해야 합니다.'
    if row['subjtnb'].startswith('UCR') or 'Residential' in (row['subjtEngNm'] or ''):
        return [], 'RC 활동의 개별 운영 날짜를 확인하지 못했습니다.'
    times = (row['lctreTimeNm'] or '').strip()
    rooms = (row['lecrmNm'] or '').strip()
    if not times or not rooms:
        return [], '공개 자료에 수업 시각 또는 강의실이 없습니다.'
    if any(t in rooms for t in ['미정', '미배정', '동영상', '콘텐츠', '온라인(중복']):
        return [], '강의실 또는 녹화 수업 운영을 확인해야 합니다.'
    time_parts = times.split('/')
    room_parts = rooms.split('/')
    if len(room_parts) == 1:
        room_parts = room_parts * len(time_parts)
    if len(room_parts) != len(time_parts):
        return [], '여러 수업 시각과 강의실의 대응을 확인해야 합니다.'
    slots = []
    for part, room in zip(time_parts, room_parts):
        normalized = re.sub(r'\s+', '', part)
        matches = list(re.finditer(r'([월화수목금토])(\d+(?:,\d+)*)', normalized))
        rebuilt = ','.join(m.group(0) for m in matches)
        if rebuilt != normalized:
            return [], '공개 수업시간 표기의 의미를 확인해야 합니다.'
        for match in matches:
            weekday = DAYS.index(match[1]) + 1
            for period in map(int, match[2].split(',')):
                if period not in CLOCK:
                    return [], '공식 편람에 해당 교시의 시작·종료 시각이 없습니다.'
                start, end = CLOCK[period]
                slots.append({'weekday': weekday, 'startMinute': start, 'endMinute': end, 'classroom': room, 'nativePeriod': period})
    if not slots or len({(s['weekday'], s['nativePeriod'], s['classroom']) for s in slots}) != len(slots):
        return [], '중복되거나 비어 있는 시간 표기를 확인해야 합니다.'
    meetings = []
    for date in DATES:
        for slot in slots:
            if slot['weekday'] == date.isoweekday():
                meetings.append({k: v for k, v in slot.items() if k != 'nativePeriod'} | {'date': date.isoformat()})
    return meetings, None


buckets = {c: [] for c in ['sinchon', 'international', 'mirae', 'unknown']}
closed, held = [], []
for key, values in sorted(groups.items()):
    first = values[0]
    for field in ['subjtNm', 'cgprfNm', 'lctreTimeNm', 'lecrmNm', 'cdt', 'campsDivNm', 'atntnMattrDesc', 'rmvlcYn']:
        assert len({json.dumps(r.get(field), ensure_ascii=False) for r in values}) == 1, (key, field)
    identity = '/'.join(key)
    native = first['subjtnbCorsePrcts']
    assert native == '-'.join(key[1:])
    if first['rmvlcYn'] == '1':
        closed.append({'identity': identity, 'nativeReference': native, 'sourceEducation': {k: first.get(k) for k in FIELDS}})
        continue
    campus = CAMPUS.get(first['campsDivNm'], 'unknown')
    meetings, hold = reservations(first)
    if hold:
        held.append({'identity': identity, 'nativeReference': native, 'reason': hold})
    departments = sorted({r['estblDeprtNm'] for r in values if r['estblDeprtNm']})
    classifications = collections.defaultdict(set)
    for row in values:
        if row['estblDeprtNm']:
            classifications[row['estblDeprtNm']].add(row['subsrtDivNm'] or '')
    # Different source category entries for the same department remain explicitly separate.
    classification_map = {}
    for department, labels in classifications.items():
        for label in labels:
            label_key = department if len(labels) == 1 else f'{department} ({label})'
            classification_map[label_key] = label
    note = (first['atntnMattrDesc'] or '') + '\n공개 예약 계획이며 실제 출석 날짜 확정이 아닙니다. 원문 강좌번호·분반·실습분반·학점·학과별 이수구분·수강 유의사항·강의실·교시를 보존합니다. 원문 실습분반: ' + key[3] + '; 수업 유형: ' + (first['subjtClNm'] or '미공개') + '; 소속학년: ' + str(first['hy']) + '.\n2026-10-07 정상 공개 조회의 자료이며 이후 전체 변경은 미확인입니다. 일반 예약은 9/1~12/7, 공휴일과 중간시험 기간 제외; 자율학습·보충수업12/8~14와 기말12/15~21의 개별 수업은 생성하지 않았습니다. 12/21학기 경계는 공식12/22겨울방학 전날입니다. 수업 방식은 사용자의 선택을 유지합니다.'
    if hold:
        note += '\n일정 보류: ' + hold
    course = {'sourceId': f'yonsei/{key[0]}/2026-2/{native}', 'campus': campus, 'academicYear': 2026, 'semester': '2', 'courseCode': key[1], 'courseName': first['subjtNm'], 'section': key[2], 'professor': first['cgprfNm'] or '', 'credits': first['cdt'], 'classification': first['subsrtDivNm'] or '', 'departments': departments, 'departmentCredits': {d: first['cdt'] for d in departments if first['cdt'] is not None}, 'departmentClassifications': classification_map, 'departmentRemarks': {d: note for d in departments}, 'sourceSchedule': first['lctreTimeNm'] or '', 'sourceClassroom': first['lecrmNm'] or '', 'remarks': note, 'scheduleStatus': 'scheduled' if meetings else 'unrecognized', 'schedules': meetings, 'period': {'startDate': '2026-09-01', 'endDate': '2026-12-21'}, 'sourceEducation': [{k: r.get(k) for k in FIELDS} for r in values], 'nativePracticumSection': key[3], 'referenceKind': 'publishedSubjectCodeAndClassAndPracticum', 'actualAttendanceConfirmed': False}
    buckets[campus].append(course)

names = {'sinchon': '신촌캠퍼스', 'international': '국제캠퍼스', 'mirae': '미래캠퍼스', 'unknown': '캠퍼스 미확인'}
manifest = []
for campus, courses in buckets.items():
    dataset = {'schemaVersion': 2, 'universityId': 'yonsei', 'campus': campus, 'campusName': names[campus], 'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-10-07', 'publishedDateMeaning': 'Public department acquisition date, not original whole-course publication date or subsequent freshness proof', 'sourceUrl': 'https://underwood1.yonsei.ac.kr/com/lgin/SsoCtr/initExtPageWork.do?link=handbList&locale=ko', 'researchOnly': True, 'completionClaim': False, 'wholeOperatingVerified': False, 'courses': courses}
    path = ROOT / f'yonsei-{campus}-2026-2.published-partial-v1.json'
    path.write_text(json.dumps(dataset, ensure_ascii=False, indent=2) + '\n')
    manifest.append({'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'courses': len(courses), 'scheduled': sum(bool(c['schedules']) for c in courses), 'meetings': sum(len(c['schedules']) for c in courses)})
assert sum(len(v) for v in buckets.values()) + len(closed) == 4926
assert len(closed) == 216
receipt = {'sourceSha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'nativeOfferingKeys': 4926, 'closed': closed, 'holds': held, 'manifest': manifest, 'clockSource': {'sinchon': 'work/university-research/catalog-d/yonsei-sinchon-2026-2-guide.pdf#page=64', 'mirae': 'work/university-research/catalog-d/yonsei-mirae-2026-2-guide.pdf#page=119'}, 'completionClaim': False}
(ROOT / 'candidate-audit-v1.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(manifest, ensure_ascii=False))
