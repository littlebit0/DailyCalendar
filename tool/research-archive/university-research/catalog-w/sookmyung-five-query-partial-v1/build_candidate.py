import collections
import datetime as dt
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent
PARENT = ROOT.parent / 'sookmyung'
QUERIES = ['IT공학전공', 'IP·콘텐츠전공', 'K-POP산업경영전공', '경제학부', '가족자원경영학과']
HEADERS = ['강의형태', '과목명', '과목번호', '분반', '교과구분', '강의시간', '담당교수', '이수단계', '학점/이론/실습', '교수법', '언어', '진로/산학연계', '수강자격', '수강유의사항', '주관학과', '코드쉐어', 'P/F', '학점교류생수강불가', '과목난이도', '특성화영역1', '특성화영역2', '특성화영역3']


def save(name, value):
    (ROOT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


calendar = json.loads((PARENT / 'sookmyung-current-calendar-campus-proof-v2.json').read_text())
originals = []
receipts = []
for query in QUERIES:
    filename = query + '-2026-2-public-education.json'
    b = (PARENT / filename).read_bytes()
    source = json.loads(b)
    assert source['year'] == '2026' and source['semester'] == '2' and source['query'] == query
    receipts.append({'file': filename, 'query': query, 'rows': len(source['rows']), 'sha256': hashlib.sha256(b).hexdigest()})
    for index, row in enumerate(source['rows']):
        assert len(row) == 22
        assert not re.search(r'@|\b(?:010|02|031)-\d', ' '.join(row))
        originals.append({'query': query, 'sourceFile': filename, 'sourceRowIndex0': index, 'nativeEducationalCells': row, 'values': dict(zip(HEADERS, row))})
assert len(originals) == 128
groups = collections.defaultdict(list)
for row in originals:
    groups[(row['values']['과목번호'], row['values']['분반'])].append(row)
assert len(groups) == 123
proof = {'researchOnly': True, 'completionClaim': False, 'retrievedDate': '2026-10-08', 'scope': 'exactly five explicit undergraduate 2026-2 public query snapshots; future parent files excluded', 'sourceUrl': 'https://www.sookmyung.ac.kr/kr/index.do', 'sourceUrlExactObserved': False, 'parentPublicUIProvenance': 'Parent normal anonymous visitor SAP table WDF2-contentTBody, direct 28 child cells; remove selection/plan/video/capacity/application/vacancy cells, retain these 22 educational cells. No additional query by child.', 'nativeHeaders': HEADERS, 'sourceFiles': receipts, 'nativeRows': originals, 'calendarCampusProof': calendar, 'reservationScope': {'start': '2026-09-01', 'end': '2026-09-21', 'status': 'selected initial three weeks only, not semester-wide schedule support', 'derivation': 'official opening Sep1 and explicitly dated fourth week Sep22–28; chosen preceding three weeks. No claim full published lecture-week table exists.'}, 'wholeLatestClosureVerified': False}
# Exact SAP entry URL must be supplied by parent; avoid inventing host/path.
proof['sourceUrl'] = 'https://www.sookmyung.ac.kr/kr/index.do'
save('five-query-educational-proof.json', proof)
datasets = collections.defaultdict(list)
pattern = re.compile(r'([월화수목금토일]+)(\d\d?:\d\d)-(\d\d?:\d\d)\(([^)]+)\)')
known = {'명신관': 'first', '순헌관': 'first', '진리관': 'first', '새힘관': 'first', '학생회관': 'first', '프라임관': 'second', '과학관': 'second', '백주년기념관': 'second', '사회교육관': 'second', '미술대학': 'second', '음악대학': 'second', '약학대학': 'second'}
minute = lambda s: int(s.split(':')[0]) * 60 + int(s.split(':')[1])
for (code, section), rows in groups.items():
    native = rows[0]['values']
    conflicts = [field for field in ['과목명', '강의시간', '담당교수', '학점/이론/실습'] if len({x['values'][field] for x in rows}) > 1]
    schedule = native['강의시간']
    matches = list(pattern.finditer(schedule))
    parsed = bool(matches) and not pattern.sub('', schedule).strip()
    rooms = list(dict.fromkeys(m[4] for m in matches))
    campuses = {known.get(re.match(r'^[가-힣]+', room)[0], 'unknown') if re.match(r'^[가-힣]+', room) else 'unknown' for room in rooms}
    campus = next(iter(campuses)) if len(campuses) == 1 else 'unknown'
    hold = []
    if conflicts:
        hold.append('native source field conflict: ' + ', '.join(conflicts))
    if not parsed:
        hold.append('exact current clock/room unavailable')
    for x in rows:
        v = x['values']
        if v['강의형태'] != '대면':
            hold.append('remote recorded course: dated lecture operation unverified')
        if v['교수법'] == 'BL':
            hold.append('BL individual physical/remote sessions unpublished')
        if re.search(r'주차|집중|비연속|외부실습|현장실습|건강가정실습|연락', v['과목명'] + ' ' + v['수강유의사항']):
            hold.append('explicit week/intensive/external practice/individual operation held')
    hold = list(dict.fromkeys(hold))
    slots = []
    if not hold:
        for m in matches:
            assert minute(m[2]) < minute(m[3])
            for day in m[1]:
                date = dt.date(2026, 9, 1)
                while date <= dt.date(2026, 9, 21):
                    if date.isoweekday() == '월화수목금토일'.index(day) + 1:
                        slots.append({'weekday': date.isoweekday(), 'startMinute': minute(m[2]), 'endMinute': minute(m[3]), 'classroom': m[4], 'date': date.isoformat()})
                    date += dt.timedelta(days=1)
    categories = list(dict.fromkeys(x['values']['교과구분'] for x in rows))
    departments = list(dict.fromkeys(x['values']['주관학과'] for x in rows if x['values']['주관학과']))
    provenance_notes = '\n'.join(x['query'] + ': 교과구분 ' + x['values']['교과구분'] + '; 이수단계 ' + x['values']['이수단계'] + '; 수강자격 ' + (x['values']['수강자격'] or '원문 빈값') + '; 수강유의사항 ' + (x['values']['수강유의사항'] or '원문 빈값') for x in rows)
    note = '공개 예약 계획의 선택 범위 2026-09-01–09-21(앞선 3주)만 포함하며 학기 전체 지원·실제 출석 완료 주장이 아닙니다. 자체 개강9/1 및 4주차9/22–28 원문을 근거로 앞부분만 선택했습니다. 대면 표기는 원문이며 개별 방식·최신 변경·폐강은 미확인입니다. 수업방식 override 없이 사용자 선택을 유지합니다. 공식 과목번호·분반·요일·HH:mm·강의실·조회전공별 분류/이수단계/제한을 보존했습니다. ' + ('물리캠퍼스 미확인. ' if campus == 'unknown' else '') + ('예약 보류: ' + '; '.join(hold) + '. ' if hold else '') + provenance_notes
    course = {'sourceId': f'sookmyung/{campus}/2026-2/five-query-{code}-{section}', 'campus': campus, 'academicYear': 2026, 'semester': '2', 'courseCode': code, 'section': section, 'courseName': native['과목명'], 'professor': native['담당교수'], 'classification': categories[0] if len(categories) == 1 else '', 'credits': float(native['학점/이론/실습'].split('/')[0]), 'departments': departments, 'departmentCredits': {}, 'departmentClassifications': {}, 'sourceSchedule': schedule, 'sourceClassroom': ' / '.join(rooms), 'remarks': note, 'scheduleStatus': 'scheduled' if slots else 'unrecognized', 'schedules': slots, 'metadata': {'originalEducationalRecords': rows, 'queryClassifications': {x['query']: x['values']['교과구분'] for x in rows}, 'queryGradeEligibility': {x['query']: {'이수단계': x['values']['이수단계'], '수강자격': x['values']['수강자격'], '수강유의사항': x['values']['수강유의사항']} for x in rows}, 'classificationConflictAcrossQuery': len(categories) > 1, 'sourceFieldConflicts': conflicts, 'holdReasons': hold, 'sourceCodePublished': True, 'sourceSectionPublished': True, 'publishedDeliveryModes': list(dict.fromkeys(x['values']['강의형태'] for x in rows)), 'actualAttendanceConfirmed': False, 'latestWholeClosureConfirmed': False, 'publicationDateKnown': False, 'internalIdKind': 'five-query snapshot plus native code-section; sourceId is internal'}}
    datasets[campus].append(course)
for campus, courses in datasets.items():
    save(f'sookmyung-{campus}-2026-2.partial-planned.json', {'schemaVersion': 2, 'universityId': 'sookmyung', 'campus': campus, 'campusName': {'first': '제1캠퍼스', 'second': '제2창학캠퍼스', 'unknown': '물리 캠퍼스 미확인'}[campus], 'academicYear': 2026, 'semester': '2', 'publishedDate': '', 'sourceUrl': proof['sourceUrl'], 'researchOnly': True, 'completionClaim': False, 'courses': courses})
print('rows', len(originals), 'unique', len(groups), 'campuses', {k: len(v) for k,v in datasets.items()}, 'scheduled', sum(bool(c['schedules']) for a in datasets.values() for c in a), 'meetings', sum(len(c['schedules']) for a in datasets.values() for c in a))
