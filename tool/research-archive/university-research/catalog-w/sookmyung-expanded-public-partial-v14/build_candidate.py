# coding: utf-8
import collections
import datetime as dt
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent
PARENT = ROOT.parent / 'sookmyung'
QUERIES = ['IT공학전공', 'IP·콘텐츠전공', 'K-POP산업경영전공', '경제학부', '가족자원경영학과', '게임콘텐츠디자인전공', '경영학부-part1', '경영학부-part2', '경영학부-part3', '교양필수-논리적사고와소프트웨어', '공예과', '교육학부', '기계시스템학부', '법학부', '수학과', '화학과', '컴퓨터과학부', '문헌정보학과', '미디어학부', '영어영문학전공', '중어중문학부', '정치외교학과', '통계학과', '생명시스템학부', '아동복지학부', '전자공학전공', '화공생명공학부', '행정학과', '교양선택-교선핵심1영역', '교양선택-교선핵심2영역', '교양선택-교선핵심3영역', '교양선택-교선핵심4영역', '교양선택-교선핵심5영역', '교양선택-교선핵심6영역', '교양선택-교선핵심7영역', '교양선택-교선일반', '독일언어·문화학과', '인공지능공학부', '프랑스언어·문화학과', '일본학과', '체육교육과', '무용과', '관현악과', '회화과', '약학부', '작곡과', '피아노과', '성악과', '환경디자인과', '한국어문학부', '역사문화학과', '식품영양학과', '의류학과', '소비자경제학과', '사회심리학과', '산업디자인과', '시각·영상디자인과', '홍보광고학과', '신소재물리학부', '융합국제학부', '르꼬르동블루외식경영전공']
QUERIES += ['문화관광학전공', '앙트러프러너십전공', '글로벌융합학부', 'IT공학과', '의약과학과', '숙명-CQU경영국제학부', '소프트웨어학부(첨단)', '컴퓨터과학전공', '컴퓨터과학전공(첨단)', '지능형전자시스템전공', '지능형전자시스템학부', '한류국제학부']
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
    receipt={'file': filename, 'query': query, 'rows': len(source['rows']), 'sha256': hashlib.sha256(b).hexdigest()}
    if 'selectedOptionElementId' in source:
        receipt['selectedOptionElementId']=source['selectedOptionElementId']
        receipt['meaning']='actual observed public UI selection element only; no inferred curriculum/campus meaning'
    receipts.append(receipt)
    for index, row in enumerate(source['rows']):
        headers = source.get('headers', json.loads((PARENT / '교양필수-논리적사고와소프트웨어-2026-2-public-education.json').read_text())['headers'] if query.startswith('교양선택-') else HEADERS)
        assert len(row) == len(headers)
        assert len(headers) in (21, 22)
        assert not re.search(r'@|\b(?:010|02|031)-\d', ' '.join(row))
        originals.append({'query': query, 'sourceFile': filename, 'sourceRowIndex0': index, 'nativeEducationalCells': row, 'nativeHeaders': headers, 'values': dict(zip(headers, row))})
assert len(originals) == 2009
groups = collections.defaultdict(list)
for row in originals:
    groups[(row['values']['과목번호'], row['values']['분반'])].append(row)
assert len(groups) == 1423
proof = {'researchOnly': True, 'completionClaim': False, 'retrievedDate': '2026-10-08', 'scope': 'expanded current public undergraduate queries, seventy-three final explicit snapshots; thirty-six native master source rows excluded from undergraduate course datasets; future parent files excluded', 'sourceUrl': 'https://www.sookmyung.ac.kr/kr/index.do', 'sourceUrlExactObserved': False, 'parentPublicUIProvenance': 'Parent normal anonymous visitor SAP table WDF2-contentTBody, direct 28 major or 27 general child cells; remove selection/plan/video/capacity/application/vacancy cells, retain native 22 major / 21 general educational cells (general has no codeShare column). No additional query by child.', 'nativeHeaders': HEADERS, 'sourceFiles': receipts, 'nativeRows': originals, 'calendarCampusProof': calendar, 'reservationScope': {'start': '2026-09-01', 'end': '2026-12-07', 'status': 'regular semester-date reservation subset with unknown individual holiday/exam days held; not complete semester support', 'derivation': 'official opening Sep1 through day before own Dec8 makeup/finals period. Dec7 is a derived regular reservation boundary, not printed last class date. No full official week table or actual attendance claim.'}, 'wholeLatestClosureVerified': False}
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
v7_receipts=json.loads((ROOT.parent / 'sookmyung-expanded-public-partial-v7' / 'five-query-educational-proof.json').read_text())['sourceFiles']
assert receipts[:30] == v7_receipts, 'v7 frozen source scope changed'
proof['newGeneralHeaderProvenance']['queries'] += ['교양선택-교선핵심3영역', '교양선택-교선핵심4영역', '교양선택-교선핵심5영역', '교양선택-교선핵심6영역', '교양선택-교선핵심7영역', '교양선택-교선일반']
proof['newGeneralHeaderProvenance']['evidence'] += '; Parent normalpublic latestcore3–7/general confirms same21educationfields; explicit6/7resultzero is a native selectedquery result, not wholeabsence claim'
v8_receipts=json.loads((ROOT.parent / 'sookmyung-expanded-public-partial-v8' / 'five-query-educational-proof.json').read_text())['sourceFiles']
assert receipts[:39] == v8_receipts, 'v8 frozen source scope changed'
proof['pendingParentFinalScope']=False
v9_receipts=json.loads((ROOT.parent / 'sookmyung-expanded-public-partial-v9' / 'five-query-educational-proof.json').read_text())['sourceFiles']
assert receipts[:45] == v9_receipts, 'v9 frozen source scope changed'
v10_receipts=json.loads((ROOT.parent / 'sookmyung-expanded-public-partial-v10' / 'five-query-educational-proof.json').read_text())['sourceFiles']
assert receipts[:49] == v10_receipts, 'v10 frozen source scope changed'
v11_receipts=json.loads((ROOT.parent / 'sookmyung-expanded-public-partial-v11' / 'five-query-educational-proof.json').read_text())['sourceFiles']
assert receipts[:54] == v11_receipts, 'v11 frozen source scope changed'
v12_receipts=json.loads((ROOT.parent / 'sookmyung-expanded-public-partial-v12' / 'five-query-educational-proof.json').read_text())['sourceFiles']
assert receipts[:58] == v12_receipts, 'v12 frozen source scope changed'
v13_receipts=json.loads((ROOT.parent / 'sookmyung-expanded-public-partial-v13' / 'five-query-educational-proof.json').read_text())['sourceFiles']
assert receipts[:61] == v13_receipts, 'v13 frozen source scope changed'
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
assert len(excluded) == 36
proof['excludedGraduateRecords'] = excluded
proof['undergraduateNativeRowCount'] = 1973
proof['undergraduateNativeIdentityCount'] = 1399
save('five-query-educational-proof.json', proof)
save('excluded-graduate-educational-records.json', {'researchOnly':True,'notUndergraduateSupport':True,'nativeRows':excluded,'excludedIdentityCount':24,'reason':'native이수단계 석사; noUGcourse or reservation created'})
datasets = collections.defaultdict(list)
pattern = re.compile(r'([월화수목금토일]+)(\d\d?:\d\d)-(\d\d?:\d\d)\(([^)]+)\)')
known = {'명신관': 'first', '순헌관': 'first', '진리관': 'first', '새힘관': 'first', '학생회관': 'first', '프라임관': 'second', '과학관': 'second', '백주년기념관': 'second', '사회교육관': 'second', '미술대학': 'second', '음악대학': 'second', '약학대학': 'second'}
historical_native_keys = {(r['values']['과목번호'],r['values']['분반']) for r in json.loads((ROOT.parent / 'sookmyung-expanded-public-partial-v13' / 'five-query-educational-proof.json').read_text())['nativeRows']}
historical_courses = {(c['courseCode'],c['section']):c for file in (ROOT.parent / 'sookmyung-expanded-public-partial-v13').glob('*.partial-planned.json') for c in json.loads(file.read_text())['courses']}
literal_map = {r['nativeBuilding']:campus for campus in ['first','second'] for r in calendar['physicalCampusProof']['nativeGroups'][campus]}
proof['newIdentityLiteralCampusPolicy'] = 'Existing source identities keep prior campus bucket; new native identities may match exact current map building names without alias inference. Source room text unchanged.'
save('five-query-educational-proof.json', proof)
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
    course_known = known if (code,section) in historical_native_keys else {**literal_map,**known}
    campuses = {course_known.get(re.match(r'^[가-힣]+', room)[0], 'unknown') if re.match(r'^[가-힣]+', room) else 'unknown' for room in rooms}
    campus = historical_courses[(code,section)]['campus'] if (code,section) in historical_courses else next(iter(campuses)) if len(campuses) == 1 else 'unknown'
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
    if code in {'21050396','21104896'} and not conflicts:
        source_bounds=[]
        for x in rows:
            v=x['values']
            match=re.search(r'(?:전반기|후반기) 집중학기 운영\((\d{1,2})/(\d{1,2})~(\d{1,2})/(\d{1,2})\)',v['수강유의사항'])
            if v['강의형태']=='대면' and match:
                source_bounds.append((dt.date(2026,int(match[1]),int(match[2])),dt.date(2026,int(match[3]),int(match[4]))))
        if len(source_bounds)==len(rows) and len(set(source_bounds))==1:
            bounds=source_bounds[0]
            bounded_intensive=True
    if code=='21001932' and section=='001' and not conflicts and all(x['values']['강의형태']=='대면' and x['values']['수강유의사항']=='유연학기제(집중학기) 전반기 수업: 2026.09.01.~2026.10.26.(8주 수업)' for x in rows):
        bounds=(dt.date(2026,9,1),dt.date(2026,10,26))
        bounded_intensive=True
    if code=='21003817' and section=='001' and not conflicts and all(x['values']['강의형태']=='대면' and x['values']['수강유의사항']=='유연학기제(집중학기) 전반기 2026.9.1.~2026.10.26.(8주)' for x in rows):
        bounds=(dt.date(2026,9,1),dt.date(2026,10,26))
        bounded_intensive=True
    reviewed_bounded_sources = {
        '21105380': ('유연학기제(집중학기) : 전반기 (8주 수업)/2026.9.1~2026.10.22/절대평가 적용', '화목15:00-17:50(순헌관210)', dt.date(2026,10,22)),
        '21105942': ('유연학기제(집중학기) 전반기 2026.9.1.~2026.10.26.(8주)', '화15:00-16:50(진리관212)', dt.date(2026,10,26)),
    }
    if code in reviewed_bounded_sources and section=='001' and not conflicts:
        source_note,source_clock,end_date=reviewed_bounded_sources[code]
        if all(x['values']['강의형태']=='대면' and x['values']['교수법']=='' and x['values']['강의시간']==source_clock and x['values']['수강유의사항']==source_note for x in rows):
            bounds=(dt.date(2026,9,1),end_date)
            bounded_intensive=True
    known_physical_partial = None
    physical_ranges=[]
    if code=='21102403' and section=='001' and not conflicts and all(x['values']['강의형태']=='대면' and x['values']['강의시간']=='수15:00-17:50(순헌관201)\n토15:00-17:50()' and x['values']['수강유의사항']=='유연학기제(집중학기) 중반기 : 2026.9.16.~11.4.(8주 수업), 수요일 대면수업, 토요일 비대면 녹화강의 진행(강의계획서 참고)' for x in rows):
        known_physical_partial='수요일'
        physical_ranges=[(dt.date(2026,9,16),dt.date(2026,11,4))]
    if code=='21050141' and section=='001' and not conflicts and all(x['values']['강의형태']=='대면' and x['values']['강의시간']=='월토16:30-19:20(순헌관416)' and x['values']['수강유의사항']=='집중학기제로 진행 예정(9/7~10/3, 11/23~12/14), 토요일 수업은 비대면으로 진행' for x in rows):
        known_physical_partial='월요일'
        physical_ranges=[(dt.date(2026,9,7),dt.date(2026,10,3)),(dt.date(2026,11,23),dt.date(2026,12,14))]
    reservation_start,reservation_end = bounds or (dt.date(2026,9,1),dt.date(2026,12,7))
    if conflicts:
        hold.append('native source field conflict: ' + ', '.join(conflicts))
    if not parsed and not known_physical_partial:
        hold.append('exact current clock/room unavailable')
    for x in rows:
        v = x['values']
        if v['강의형태'] != '대면' and not native_live:
            hold.append('remote recorded course: dated lecture operation unverified')
        if v['수강유의사항'] == '추후 담당교원이 강의계획서 입력 예정':
            hold.append('individual professor course plan pending; actual operating plan unpublished')
        if v['교수법'] == 'BL':
            hold.append('BL individual physical/remote sessions unpublished')
        if re.search(r'주차|집중|비연속|외부실습|현장실습|건강가정실습|연락', v['과목명'] + ' ' + v['수강유의사항']) and not bounded_intensive and not known_physical_partial:
            hold.append('explicit week/intensive/external practice/individual operation held')
    if code == '21000811' and section == '001':
        hold.append('childcare practicum individual outside operation dates unpublished')
    if code in {'21002867','21002869'} and section=='001':
        hold.append('two native classrooms at the same weekday and clock; individual room assignment unknown, no arbitrary room choice or duplicate appointments')
    if code in {'21050081','21001767','21102397','21103760','21102396'}:
        hold.append('two native classrooms at the same weekday and clock; individual room assignment unknown, no arbitrary room choice or duplicate appointments')
    if code=='21003808' and section=='001':
        hold.append('source12–14week practical operation and individual Wednesday/Friday section unpublished; exact weekdate/section operation unverified')
    hold = list(dict.fromkeys(hold))
    slots = []
    if not hold:
        for m in matches:
            assert minute(m[2]) < minute(m[3])
            for day in m[1]:
                if known_physical_partial and day != known_physical_partial[0]:
                    continue
                date = min(r[0] for r in physical_ranges) if known_physical_partial else reservation_start
                while date <= (max(r[1] for r in physical_ranges) if known_physical_partial else reservation_end):
                    if date.isoweekday() == '월화수목금토일'.index(day) + 1 and date.isoformat() not in proof['nationalHolidayDateReference']['conservativeUnknownOperationHoldDates'] and not dt.date(2026, 10, 20) <= date <= dt.date(2026, 10, 26) and not dt.date(2026,12,8) <= date <= dt.date(2026,12,21) and (not known_physical_partial or any(start<=date<=end for start,end in physical_ranges)):
                        slots.append({'weekday': date.isoweekday(), 'startMinute': minute(m[2]), 'endMinute': minute(m[3]), 'classroom': m[4], 'date': date.isoformat()})
                    date += dt.timedelta(days=1)
    categories = list(dict.fromkeys(x['values']['교과구분'] for x in rows))
    departments = list(dict.fromkeys(x['values']['주관학과'] for x in rows if x['values']['주관학과']))
    provenance_notes = '\n'.join(x['query'] + ': 교과구분 ' + x['values']['교과구분'] + '; 이수단계 ' + x['values']['이수단계'] + '; 수강자격 ' + (x['values']['수강자격'] or '원문 빈값') + '; 수강유의사항 ' + (x['values']['수강유의사항'] or '원문 빈값') for x in rows)
    note = '공개 정규 예약 계획의 부분 범위 2026-09-01–12-07이며 실제 출석 완료·학기 전체 운영 확인 주장이 아닙니다. 자체 개강9/1과 보강·기말12/8–21에 따라 일반예약 끝12/7을 파생했습니다(원문 최종수업일이 아님). 법정공휴일은 학교가 대면/실시간 비대면 운영을 허용하므로 실제 운영 미확정 날짜만 보수적으로 보류했습니다. 중간10/20–26도 개별 시험일/정상강의일 구분 미확정으로 예약 보류했으며 공식휴강 주장하지 않습니다. 개별 시험/보강은 생성하지 않습니다. 대면 표기는 원문이며 개별 방식·최신 변경·폐강은 미확인입니다. 수업방식 override 없이 사용자 선택을 유지합니다. 공식 과목번호·분반·요일·HH:mm·강의실·조회전공별 분류/이수단계/제한을 보존했습니다. ' + ('물리캠퍼스 미확인. ' if campus == 'unknown' else '') + ('예약 보류: ' + '; '.join(hold) + '. ' if hold else '') + provenance_notes
    course = {'sourceId': f'sookmyung/{campus}/2026-2/thirteen-major-general-{code}-{section}', 'campus': campus, 'academicYear': 2026, 'semester': '2', 'courseCode': code, 'section': section, 'courseName': native['과목명'], 'professor': native['담당교수'], 'classification': categories[0] if len(categories) == 1 else '', 'credits': float(native['학점/이론/실습'].split('/')[0]), 'departments': departments, 'departmentCredits': {}, 'departmentClassifications': {}, 'sourceSchedule': schedule, 'sourceClassroom': ' / '.join(rooms), 'remarks': note, 'scheduleStatus': 'scheduled' if slots else 'unrecognized', 'schedules': slots, 'metadata': {'originalEducationalRecords': rows, 'queryClassifications': {x['query']: x['values']['교과구분'] for x in rows}, 'queryGradeEligibility': {x['query']: {'이수단계': x['values']['이수단계'], '수강자격': x['values']['수강자격'], '수강유의사항': x['values']['수강유의사항']} for x in rows}, 'classificationConflictAcrossQuery': len(categories) > 1, 'sourceFieldConflicts': conflicts, 'holdReasons': hold, 'sourceCodePublished': True, 'sourceSectionPublished': True, 'publishedDeliveryModes': list(dict.fromkeys(x['values']['강의형태'] for x in rows)), 'actualAttendanceConfirmed': False, 'latestWholeClosureConfirmed': False, 'publicationDateKnown': False, 'internalIdKind': 'stable v4 namespace plus native code-section; sourceId is internal, v5 adds query variants without changing existing identity namespace'}}
    if (code,section) in historical_courses and 'newIdentityLiteralCampusMapMatches' in historical_courses[(code,section)]['metadata']:
        course['metadata']['newIdentityLiteralCampusMapMatches']=historical_courses[(code,section)]['metadata']['newIdentityLiteralCampusMapMatches']
    if (code,section) not in historical_native_keys:
        literal_records = [{'sourceClassroom':room,'nativeMapBuilding':re.match(r'^[가-힣]+',room)[0],'campus':literal_map[re.match(r'^[가-힣]+',room)[0]]} for room in rooms if re.match(r'^[가-힣]+',room) and re.match(r'^[가-힣]+',room)[0] in literal_map]
        if literal_records:
            course['metadata']['newIdentityLiteralCampusMapMatches'] = literal_records
    if code=='21050141' and section=='001':
        course['metadata']['sourcePublishedDiscontinuousOperatingDateRanges']=[{'startDate':'2026-09-07','endDate':'2026-10-03'},{'startDate':'2026-11-23','endDate':'2026-12-14'}]
        course['metadata']['publishedSaturdayRemoteOperation']='비대면; real-time versus recorded mode unpublished'
        course['remarks']='원문 집중학기 두 구간9/7–10/3 및11/23–12/14 보존. 토요일 비대면 수업은 실시간/녹화 방식 미공개로 토요일 예약은 보류하고 대면원문/토요일비대면 예외에 근거한 월요일 부분예약만 제공하며 날짜 gap을 하나의연속period로 만들지 않았습니다. '+course['remarks']
    if code=='21102403' and section=='001':
        course['period']={'startDate':'2026-09-16','endDate':'2026-11-04'}
        course['metadata']['sourcePublishedOperatingDateBounds']=course['period'].copy()
        course['metadata']['sourcePublishedWeekdayDeliveryModes']={'수요일':'대면수업','토요일':'비대면 녹화강의'}
        course['remarks']='원문 중반집중기간9/16–11/4 및 수대면/토녹화 혼합 운영 보존. 토요일 HH:mm을 실시간으로 변환하지 않으며 토요일녹화 예약은 보류하고 직접명시된 수요일 대면HH:mm/강의실 부분예약만 제공했습니다. '+course['remarks']
    if bounded_intensive:
        course['period'] = {'startDate':reservation_start.isoformat(),'endDate':reservation_end.isoformat()}
        course['metadata']['sourcePublishedOperatingDateBounds'] = course['period'].copy()
        course['metadata']['boundedIntensiveSourceText'] = native['수강유의사항']
        period_label = '2026-09-01–10-26' if code == '21003187' else f'{reservation_start.isoformat()}–{reservation_end.isoformat()}'
        course['remarks'] = f'개별 집중학기 원문 기간{period_label} 안의 예약 부분범위입니다. 전체학교 예약의12/7경계는 본 과목에 적용하지 않습니다. 개별시험/휴일운영 미확정일 보수적보류, 실제출석확인아님. ' + course['remarks']
    if bounded_intensive and reservation_end > dt.date(2026,12,7):
        course['metadata']['individualMakeupFinalDaysUnknownHold']={'start':'2026-12-08','end':'2026-12-21','meaning':'source published course period preserved; individual lecture versus exam/makeup operation unknown, reservations held only; no official closure claim'}
        course['remarks']='개별 원문기간 끝12/18을 보존하며 자체 보강·기말12/8–21 내 개별강의/시험 구분 미확정 날짜는 예약 보류했습니다. '+course['remarks']
    if known_physical_partial:
        for slot in course['schedules']:
            slot['deliveryMode']='inPerson'
        course['metadata']['knownPhysicalWeekdayPartial']={'weekdayLabel':known_physical_partial,'ranges':[{'startDate':start.isoformat(),'endDate':end.isoformat()} for start,end in physical_ranges],'sourceEvidence':'exact original lecture form, weekday clock/room and Saturday recorded/remote exception preserved; no actual attendance claim','heldOtherWeekday':'토요일','deliveryOverride':'inPerson'}
        course['metadata']['partialHeldOperatingConditions']={'토요일':'recorded for21102403, remote LIVE/VOD unresolved for21050141; no Saturday appointment generated'}
        course['remarks']=course['remarks'].replace('수업방식 override 없이 사용자 선택을 유지합니다.', '기본 사용자수업방식은 보존하고 원문으로 확인된 대면요일 부분예약만 대면예외로 유지합니다.')
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
