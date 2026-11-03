import collections
import datetime as dt
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent
PARENT = ROOT.parent / 'sookmyung'
QUERIES = ['IT공학전공', 'IP·콘텐츠전공', 'K-POP산업경영전공', '경제학부', '가족자원경영학과', '게임콘텐츠디자인전공', '경영학부-part1', '경영학부-part2', '경영학부-part3', '교양필수-논리적사고와소프트웨어', '공예과', '교육학부', '기계시스템학부', '법학부', '수학과', '화학과', '컴퓨터과학부', '문헌정보학과', '미디어학부', '영어영문학전공', '중어중문학부', '정치외교학과', '통계학과', '생명시스템학부', '아동복지학부', '전자공학전공', '화공생명공학부', '행정학과', '교양선택-교선핵심1영역', '교양선택-교선핵심2영역']
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
        headers = source.get('headers', json.loads((PARENT / '교양필수-논리적사고와소프트웨어-2026-2-public-education.json').read_text())['headers'] if query in ['교양선택-교선핵심1영역','교양선택-교선핵심2영역'] else HEADERS)
        assert len(row) == len(headers)
        assert len(headers) in (21, 22)
        assert not re.search(r'@|\b(?:010|02|031)-\d', ' '.join(row))
        originals.append({'query': query, 'sourceFile': filename, 'sourceRowIndex0': index, 'nativeEducationalCells': row, 'nativeHeaders': headers, 'values': dict(zip(headers, row))})
assert len(originals) == 858
groups = collections.defaultdict(list)
for row in originals:
    groups[(row['values']['과목번호'], row['values']['분반'])].append(row)
assert len(groups) == 707
proof = {'researchOnly': True, 'completionClaim': False, 'retrievedDate': '2026-10-08', 'scope': 'expanded current public undergraduate queries, thirty final explicit snapshots; ten native master rows excluded from undergraduate course datasets; future parent files excluded', 'sourceUrl': 'https://www.sookmyung.ac.kr/kr/index.do', 'sourceUrlExactObserved': False, 'parentPublicUIProvenance': 'Parent normal anonymous visitor SAP table WDF2-contentTBody, direct 28 major or 27 general child cells; remove selection/plan/video/capacity/application/vacancy cells, retain native 22 major / 21 general educational cells (general has no codeShare column). No additional query by child.', 'nativeHeaders': HEADERS, 'sourceFiles': receipts, 'nativeRows': originals, 'calendarCampusProof': calendar, 'reservationScope': {'start': '2026-09-01', 'end': '2026-12-07', 'status': 'regular semester-date reservation subset with unknown individual holiday/exam days held; not complete semester support', 'derivation': 'official opening Sep1 through day before own Dec8 makeup/finals period. Dec7 is a derived regular reservation boundary, not printed last class date. No full official week table or actual attendance claim.'}, 'wholeLatestClosureVerified': False}
# Exact SAP entry URL must be supplied by parent; avoid inventing host/path.
proof['sourceUrl'] = 'https://www.sookmyung.ac.kr/kr/index.do'
proof['nationalHolidayDateReference'] = json.loads((ROOT / 'national-holiday-date-reference.json').read_text())
proof['individualExamDaysUnknownHold'] = {'start': '2026-10-20', 'end': '2026-10-26', 'meaning': 'conservative reservation hold only; school says dates without exam have normal lectures, so not official closure'}
original_receipts = json.loads((ROOT.parent / 'sookmyung-five-query-partial-v1' / 'five-query-educational-proof.json').read_text())['sourceFiles']
assert receipts[:5] == original_receipts, 'five original source snapshots changed; do not silently blend scope'
v3_receipts=json.loads((ROOT.parent / 'sookmyung-seven-major-plus-general-partial-v3' / 'five-query-educational-proof.json').read_text())['sourceFiles']
assert receipts[:10] == v3_receipts, 'v3 frozen source scopechanged; no silent blend'
v4_receipts=json.loads((ROOT.parent / 'sookmyung-thirteen-major-plus-general-partial-v4' / 'five-query-educational-proof.json').read_text())['sourceFiles']
assert receipts[:16] == v4_receipts, 'v4 frozen source scope changed; do not blend or mutate historical scope'
v5_receipts=json.loads((ROOT.parent / 'sookmyung-twenty-major-plus-general-partial-v5' / 'five-query-educational-proof.json').read_text())['sourceFiles']
assert receipts[:23] == v5_receipts, 'v5 frozen source scope changed'
v6_receipts=json.loads((ROOT.parent / 'sookmyung-expanded-public-partial-v6' / 'five-query-educational-proof.json').read_text())['sourceFiles']
assert receipts[:28] == v6_receipts, 'v6 frozen source scope changed'
proof['newGeneralHeaderProvenance']={'queries':['교양선택-교선핵심1영역','교양선택-교선핵심2영역'],'headers':json.loads((PARENT / '교양필수-논리적사고와소프트웨어-2026-2-public-education.json').read_text())['headers'],'evidence':'Parent normalpublic SAP observation confirms27 total columns and21 educational whitelist without codeShare; raw71+44 immutable JSON has no headersfield and is not modified'}
parts = [json.loads((PARENT / (q+'-2026-2-public-education.json')).read_text()) for q in QUERIES[6:9]]
assert [x['offset'] for x in parts] == [0,36,72] and all(x['totalNativeRows'] == 108 for x in parts)
assert len({(r[2],r[3]) for x in parts for r in x['rows']}) == 108
guide_bytes=(PARENT / '수강가이드94204-2026-2-public-education.json').read_bytes()
proof['currentClosureGuide']={'sha256':hashlib.sha256(guide_bytes).hexdigest(),'originalEducationalReceipt':json.loads(guide_bytes),'meaning':'notice directs final closure verification after Sep7; actual final closure list not acquired, no removal inferred'}
proof['sourceUrl'] = 'https://smap.sookmyung.ac.kr:8443/sap/bc/webdynpro/sap/zcmw2237?sap-language=KO'
proof['sourceUrlExactObserved'] = True
proof['parentObservedPublicQueryEntry'] = {'queryUrl':proof['sourceUrl'], 'entryPageUrl':'https://www.sookmyung.ac.kr/kr/university-life/class-information02.do', 'evidence':'Parent observed official main timetable navigation followed by normal anonymous SAP visitor UI; supplied exact page URL Oct8; no additional request by child. Fragment UI state excluded.', 'academicRawUniversityId':'0000141', 'internalCandidateUniversityId':'sookmyung', 'firstPhysicalCampus':'first'}
proof['sourceFieldConflictPolicy']='Query-specific classification/grade/eligibility differences preserve every source variant; common classification blank when variants differ. Exact title/professor/clock/credits conflicts hold all reservations; native multi-professor cell remains whole without truncation.'
excluded = [x for x in originals if '석사' in x['values']['이수단계']]
assert len(excluded) == 10
proof['excludedGraduateRecords'] = excluded
proof['undergraduateNativeRowCount'] = 848
proof['undergraduateNativeIdentityCount'] = 697
save('five-query-educational-proof.json', proof)
save('excluded-graduate-educational-records.json', {'researchOnly':True,'notUndergraduateSupport':True,'nativeRows':excluded,'excludedIdentityCount':10,'reason':'native이수단계 석사; noUGcourse or reservation created'})
datasets = collections.defaultdict(list)
pattern = re.compile(r'([월화수목금토일]+)(\d\d?:\d\d)-(\d\d?:\d\d)\(([^)]+)\)')
known = {'명신관': 'first', '순헌관': 'first', '진리관': 'first', '새힘관': 'first', '학생회관': 'first', '프라임관': 'second', '과학관': 'second', '백주년기념관': 'second', '사회교육관': 'second', '미술대학': 'second', '음악대학': 'second', '약학대학': 'second'}
minute = lambda s: int(s.split(':')[0]) * 60 + int(s.split(':')[1])
for (code, section), rows in groups.items():
    if any('석사' in x['values']['이수단계'] for x in rows):
        assert all('석사' in x['values']['이수단계'] for x in rows), 'mixed UG/graduateidentitymustreview'
        continue
    native = rows[0]['values']
    conflicts = [field for field in ['과목명', '강의시간', '담당교수', '학점/이론/실습'] if len({x['values'][field] for x in rows}) > 1]
    schedule = native['강의시간']
    matches = list(pattern.finditer(schedule))
    parsed = bool(matches) and not pattern.sub('', schedule).strip()
    rooms = list(dict.fromkeys(m[4] for m in matches))
    campuses = {known.get(re.match(r'^[가-힣]+', room)[0], 'unknown') if re.match(r'^[가-힣]+', room) else 'unknown' for room in rooms}
    campus = next(iter(campuses)) if len(campuses) == 1 else 'unknown'
    hold = []
    native_live = code == '21002656' and section == '001' and not conflicts and all(x['values']['강의형태'] == '원격(실시간)' and x['values']['수강유의사항'] == '연세대와 공동강의로 원격강의로 진행될 예정임/암유전체-유전체학 및 실습 공동강의 / 2학년' for x in rows)
    bounded_intensive = code == '21003187' and section == '001' and not conflicts and all(x['values']['수강유의사항'] == '유연학기제(집중학기) 전반기 : 2026.09.01 ~ 2026.10.26 (8주 수업)' for x in rows)
    bounds = (dt.date(2026, 9, 1),dt.date(2026, 10, 26)) if bounded_intensive else None
    if code == '21105703' and section in {f'{i:03d}' for i in range(1,10)} and not conflicts:
        source_bounds=[]
        for x in rows:
            v=x['values']
            match=re.search(r'집중학기 전반기: 2026\.(\d{2})\.(\d{2})\.-(\d{2})\.(\d{2})\.\(8주 수업\)',v['수강유의사항'])
            if v['강의형태']=='대면' and match:
                source_bounds.append((dt.date(2026,int(match[1]),int(match[2])),dt.date(2026,int(match[3]),int(match[4]))))
        if len(source_bounds)==len(rows) and len(set(source_bounds))==1:
            bounds=source_bounds[0]
            bounded_intensive=True
    reservation_start,reservation_end = bounds or (dt.date(2026,9,1),dt.date(2026,12,7))
    if conflicts:
        hold.append('native source field conflict: ' + ', '.join(conflicts))
    if not parsed:
        hold.append('exact current clock/room unavailable')
    for x in rows:
        v = x['values']
        if v['강의형태'] != '대면' and not native_live:
            hold.append('remote recorded course: dated lecture operation unverified')
        if v['교수법'] == 'BL':
            hold.append('BL individual physical/remote sessions unpublished')
        if re.search(r'주차|집중|비연속|외부실습|현장실습|건강가정실습|연락', v['과목명'] + ' ' + v['수강유의사항']) and not bounded_intensive:
            hold.append('explicit week/intensive/external practice/individual operation held')
    if code == '21000811' and section == '001':
        hold.append('childcare practicum individual outside operation dates unpublished')
    hold = list(dict.fromkeys(hold))
    slots = []
    if not hold:
        for m in matches:
            assert minute(m[2]) < minute(m[3])
            for day in m[1]:
                date = reservation_start
                while date <= reservation_end:
                    if date.isoweekday() == '월화수목금토일'.index(day) + 1 and date.isoformat() not in proof['nationalHolidayDateReference']['conservativeUnknownOperationHoldDates'] and not dt.date(2026, 10, 20) <= date <= dt.date(2026, 10, 26):
                        slots.append({'weekday': date.isoweekday(), 'startMinute': minute(m[2]), 'endMinute': minute(m[3]), 'classroom': m[4], 'date': date.isoformat()})
                    date += dt.timedelta(days=1)
    categories = list(dict.fromkeys(x['values']['교과구분'] for x in rows))
    departments = list(dict.fromkeys(x['values']['주관학과'] for x in rows if x['values']['주관학과']))
    provenance_notes = '\n'.join(x['query'] + ': 교과구분 ' + x['values']['교과구분'] + '; 이수단계 ' + x['values']['이수단계'] + '; 수강자격 ' + (x['values']['수강자격'] or '원문 빈값') + '; 수강유의사항 ' + (x['values']['수강유의사항'] or '원문 빈값') for x in rows)
    note = '공개 정규 예약 계획의 부분 범위 2026-09-01–12-07이며 실제 출석 완료·학기 전체 운영 확인 주장이 아닙니다. 자체 개강9/1과 보강·기말12/8–21에 따라 일반예약 끝12/7을 파생했습니다(원문 최종수업일이 아님). 법정공휴일은 학교가 대면/실시간 비대면 운영을 허용하므로 실제 운영 미확정 날짜만 보수적으로 보류했습니다. 중간10/20–26도 개별 시험일/정상강의일 구분 미확정으로 예약 보류했으며 공식휴강 주장하지 않습니다. 개별 시험/보강은 생성하지 않습니다. 대면 표기는 원문이며 개별 방식·최신 변경·폐강은 미확인입니다. 수업방식 override 없이 사용자 선택을 유지합니다. 공식 과목번호·분반·요일·HH:mm·강의실·조회전공별 분류/이수단계/제한을 보존했습니다. ' + ('물리캠퍼스 미확인. ' if campus == 'unknown' else '') + ('예약 보류: ' + '; '.join(hold) + '. ' if hold else '') + provenance_notes
    course = {'sourceId': f'sookmyung/{campus}/2026-2/thirteen-major-general-{code}-{section}', 'campus': campus, 'academicYear': 2026, 'semester': '2', 'courseCode': code, 'section': section, 'courseName': native['과목명'], 'professor': native['담당교수'], 'classification': categories[0] if len(categories) == 1 else '', 'credits': float(native['학점/이론/실습'].split('/')[0]), 'departments': departments, 'departmentCredits': {}, 'departmentClassifications': {}, 'sourceSchedule': schedule, 'sourceClassroom': ' / '.join(rooms), 'remarks': note, 'scheduleStatus': 'scheduled' if slots else 'unrecognized', 'schedules': slots, 'metadata': {'originalEducationalRecords': rows, 'queryClassifications': {x['query']: x['values']['교과구분'] for x in rows}, 'queryGradeEligibility': {x['query']: {'이수단계': x['values']['이수단계'], '수강자격': x['values']['수강자격'], '수강유의사항': x['values']['수강유의사항']} for x in rows}, 'classificationConflictAcrossQuery': len(categories) > 1, 'sourceFieldConflicts': conflicts, 'holdReasons': hold, 'sourceCodePublished': True, 'sourceSectionPublished': True, 'publishedDeliveryModes': list(dict.fromkeys(x['values']['강의형태'] for x in rows)), 'actualAttendanceConfirmed': False, 'latestWholeClosureConfirmed': False, 'publicationDateKnown': False, 'internalIdKind': 'stable v4 namespace plus native code-section; sourceId is internal, v5 adds query variants without changing existing identity namespace'}}
    if bounded_intensive:
        course['period'] = {'startDate':reservation_start.isoformat(),'endDate':reservation_end.isoformat()}
        course['metadata']['sourcePublishedOperatingDateBounds'] = course['period'].copy()
        course['metadata']['boundedIntensiveSourceText'] = native['수강유의사항']
        period_label = '2026-09-01–10-26' if code == '21003187' else f'{reservation_start.isoformat()}–{reservation_end.isoformat()}'
        course['remarks'] = f'개별 집중학기 원문 기간{period_label} 안의 예약 부분범위입니다. 전체학교 예약의12/7경계는 본 과목에 적용하지 않습니다. 개별시험/휴일운영 미확정일 보수적보류, 실제출석확인아님. ' + course['remarks']
    if native_live:
        for slot in course['schedules']:
            slot['deliveryMode'] = 'liveOnline'
        course['metadata']['nativeLiveOnlineClass'] = True
        course['remarks'] = course['remarks'].replace('수업방식 override 없이 사용자 선택을 유지합니다.', '기본 수업방식의 사용자 선택은 보존하되 원문 개별 실시간비대면 방식은 유지합니다.').replace('대면 표기는 원문이며 개별 방식·최신 변경·폐강은 미확인입니다.', '원격(실시간) 및 공동원격 예정 표기는 원문이며 개별 날짜 실제운영·최신 변경·폐강은 미확인입니다.')
        course['remarks'] = '원문 원격(실시간) 및 연세대 공동원격강의 직접명시: 개별예약의 수업방식은 실시간비대면으로 보존합니다. 미래창조관202호 원문을 보존하되 물리캠퍼스 연결·학생등교확인아님. ' + course['remarks']
    datasets[campus].append(course)
for campus, courses in datasets.items():
    save(f'sookmyung-{campus}-2026-2.partial-planned.json', {'schemaVersion': 2, 'universityId': 'sookmyung', 'campus': campus, 'campusName': {'first': '제1캠퍼스', 'second': '제2창학캠퍼스', 'unknown': '물리 캠퍼스 미확인'}[campus], 'academicYear': 2026, 'semester': '2', 'publishedDate': '', 'sourceUrl': proof['sourceUrl'], 'researchOnly': True, 'completionClaim': False, 'courses': courses})
print('rows', len(originals), 'unique', len(groups), 'campuses', {k: len(v) for k,v in datasets.items()}, 'scheduled', sum(bool(c['schedules']) for a in datasets.values() for c in a), 'meetings', sum(len(c['schedules']) for a in datasets.values() for c in a))
