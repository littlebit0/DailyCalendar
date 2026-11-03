"""Transcribe the actual official undergraduate-colored timetable, not graduates."""
import copy
import hashlib
import json
from pathlib import Path

base = Path('work/all-university-completion-20261012')
evidence = base / 'root-sources/kaist-mse-current'
image = evidence / 'schedule.png'
if image.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
    raise SystemExit('Missing original timetable image')
for filename in ['notice.html', 'curriculum.html', 'academics.html']:
    if not (evidence / filename).is_file():
        raise SystemExit('Missing official context: ' + filename)
# Literal five-digit(+letter) display codes retained without manufacturing a
# subject prefix or section. Curriculum reference is separate educational data.
# Only peach cells: the source legend explicitly marks them as undergraduate.
rows = [
    ('30040', '고분자소재', '김상욱', '2427', '전공선택', 3, [(1,540,615),(3,540,615)]),
    ('49900B', '신소재특강', '박명일', '2425', '', None, [(1,540,615),(1,630,705)]),
    ('20014', '소재열역학의 응용', '오지훈', '공2501', '전공선택', 3, [(1,630,705),(3,630,705)]),
    ('30054', '소재전기화학', '조은애', '2427', '전공선택', 3, [(1,630,705),(3,630,705)]),
    ('30011', '상변화와 미세조직', '최백규', '공2501', '전공필수', 3, [(2,630,705),(4,630,705)]),
    ('40025', '바이오소재개론', '남찬범', '2425', '전공선택', 3, [(2,630,705),(4,630,705)]),
    ('20011A', '신소재과학개론', '스티브박', '창311', '기초', 3, [(1,780,855),(3,780,855)]),
    ('30033', '무기소재화학', '박상하', '1317', '전공선택', 3, [(1,780,855),(3,780,855)]),
    ('40035', '신소재공학을 위한 응용수학', '홍승범', '2425', '전공선택', 3, [(2,780,855),(4,780,855)]),
    ('40061', '고급재료양자역학및인공지능', '강정구', '1318', '전공선택', 3, [(2,780,855),(4,780,855)]),
    ('20011B', '신소재과학개론', '염지현', '창311', '기초', 3, [(1,870,945),(3,870,945)]),
    ('30022', '신소재실험Ⅱ', '김경민', '2427', '전공선택', 3, [(1,870,945),(1,960,1035),(3,870,945),(3,1050,1125)]),
    ('40042', '센서소재 및 응용', '김일두', '2425', '전공선택', 3, [(1,870,945),(3,870,945)]),
    ('30081', '고체물리개론', '박병국', '2427', '전공선택', 3, [(2,870,945),(4,870,945)]),
    ('40014', '소재분석', '강성훈', '1318', '전공선택', 3, [(2,870,945),(4,870,945)]),
    ('49900A', '신소재특강', '서동화', '창307', '', None, [(1,960,1035),(3,960,1035)]),
]
path = Path('assets/timetable/kaist-main-2026-2.json')
data = json.loads(path.read_text())
before = copy.deepcopy(data)
url = 'https://mse.kaist.ac.kr/index.php?document_srl=389571&mid=mse_notice'
department = '신소재공학과'
new = []
for code, title, professor, room, category, credits, blocks in rows:
    source_id = f'kaist/main/2026-2/mse-389571/{code}'
    if any(course['sourceId'] == source_id for course in data['courses']):
        raise SystemExit('Already applied; do not duplicate')
    row = {'sourceId': source_id, 'campus': 'main', 'academicYear': 2026,
           'semester': '2', 'courseCode': code, 'courseName': title,
           'section': '', 'professor': professor, 'classification': category,
           'credits': credits, 'departments': [department],
           'departmentCredits': {department: credits} if credits is not None else {},
           'departmentClassifications': {department: category},
           'sourceUrl': url, 'sourceClassroom': room,
           'sourceSchedule': ' / '.join(f'{"월화수목금토일"[day-1]} {start//60:02}:{start%60:02}-{end//60:02}:{end%60:02}' for day,start,end in blocks),
           'scheduleStatus': 'scheduled',
           'schedules': [{'weekday': day, 'startMinute': start, 'endMinute': end,
                          'classroom': room} for day,start,end in blocks],
           'period': {'startDate': '2026-08-31', 'endDate': '2026-12-18'},
           'periodSourceUrl': 'https://kaist.ac.kr/en/html/edu/03100101.html',
           'sourcePlanStatus': 'Published official 2026 fall timetable (안); operation subject to school changes',
           'nativeDisplayCode': code, 'nativeSectionUnresolved': code.endswith(('A','B')),
           'classificationSourceUrl': 'https://mse.kaist.ac.kr/index.php?mid=mse_undercurriculum' if category else None,
           'sourceLocator': {'imageSha256': hashlib.sha256(image.read_bytes()).hexdigest(),
                             'legend': 'peach = 학부과목', 'literalDisplayCode': code,
                             'visualSourceReviewed': True},
           'remarks': '공식 신소재공학과 2026 가을 강의시간표(안)의 학부 표시 과목입니다. 원문 단축 코드와 강의실 표기를 유지합니다. 분반은 별도 표기가 없어 비워두며 코드 끝 영문을 임의 분반으로 바꾸지 않습니다. 학기 밖에는 반복하지 않습니다. 학교 변경사항에 따라 운영이 달라질 수 있습니다.'}
    if category:
        reference = code[:5]
        if 'MS.' + reference not in (evidence / 'curriculum.html').read_text():
            raise SystemExit('Curriculum identity missing: ' + reference)
        row['curriculumReferenceCode'] = 'MS.' + reference
    new.append(row)
backup = base / 'kaist-before-mse-public.json'
if not backup.exists():
    backup.write_bytes(path.read_bytes())
data['courses'].extend(new)
data.setdefault('sourceCoverage', []).append({'sourceUrl': url, 'sourcePublishedDate': '2026-09-01', 'nativeCourses': [r[0] for r in rows], 'scope': 'Only16 peach undergraduate offerings; graduates/seminars excluded. Whole school incomplete.'})
data['wholeOperatingVerified'] = False
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
orgpath = Path('assets/timetable/organizations/kaist.json')
org = json.loads(orgpath.read_text())
orgbackup = base / 'kaist-organizations-before-mse-public.json'
if not orgbackup.exists():
    orgbackup.write_bytes(orgpath.read_bytes())
if any(unit['sourceLabel'] == department for unit in org['mappings']):
    raise SystemExit('Unexpected prior MSE mapping')
org['mappings'].append({'college': '공과대학', 'department': department,
    'sourceLabel': department, 'campus': 'main', 'isOfferingUnit': False,
    'collegeOnlyEligible': False, 'collegeKnown': True, 'affiliationStatus': 'verified',
    'sourceUrl': 'https://www.kaist.ac.kr/en/html/edu/03.html',
    'sourceFile': str(evidence/'academics.html'),
    'evidence': 'Official College of Engineering section lists Materials Science and Engineering; department-issued source uses Korean 신소재공학과.'})
orgpath.write_text(json.dumps(org, ensure_ascii=False, indent=2) + '\n')
(base/'kaist-mse-integration-receipt.json').write_text(json.dumps({
    'previousOfferingsPreserved': len(before['courses']), 'addedUndergraduate': len(new),
    'currentOfferings': len(data['courses']), 'verificationPending': True,
    'wholeUniversityCompletion': False, 'schools': [{'university': 'kaist', 'mappings': 1, 'ownerUnits': 0}],
    'graduateAndSeminarCellsExcluded': True, 'sectionInferencesMade': False,
    'evidenceFile': str(image), 'sourceUrl': url}, ensure_ascii=False, indent=2)+'\n')
print({'old':len(before['courses']), 'added':len(new), 'verificationPending':True})
