import hashlib
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent
SOURCE = 'https://intro-aic.kaist.ac.kr/'


def clean(value):
    return html.unescape(re.sub(r'\s+', ' ', re.sub('<[^>]+>', ' ', value))).strip()


def save(name, value):
    (ROOT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


page = Path('/private/tmp/daily-kaist-aic.html').read_text()
assert 'Fall 2026' in page and 'AIC.20000 Introduction to AI Computing' in page
clock = clean(re.search(r'<dt>Time</dt>\s*<dd>(.*?)</dd>', page, re.S)[1])
assert clock == 'Thursdays, 16:00-19:00'
rows = []
for tr in re.findall(r'<tr[^>]*>(.*?)</tr>', page, re.S):
    cells = re.findall(r'<td[^>]*>(.*?)</td>', tr, re.S)
    if len(cells) != 7:
        continue
    date = re.search(r'datetime="([^"]+)"', cells[1])[1]
    values = [clean(x) for x in cells]
    rows.append(dict(zip(['week', 'dateLabel', 'location', 'session', 'instructor', 'teachingAssistant', 'topics'], values), date=date))
assert len(rows) == 16
lectures = [r for r in rows if r['session'].startswith('Lecture ')]
assert len(lectures) == 10
ug = Path('/private/tmp/daily-kaist-ug.html').read_text()
ugrow = next([clean(x) for x in re.findall(r'<td[^>]*>(.*?)</td>', tr, re.S)] for tr in re.findall(r'<tr[^>]*>(.*?)</tr>', ug, re.S) if 'AIC.20000' in tr)
assert ugrow[:4] == ['Major Required', 'AIC.20000', 'Introduction to AI Computing', '3:0:3']
directions = clean(Path('/private/tmp/daily-kaist-directions.html').read_text())
campus_text = re.findall(r'KAIST 전산학부는 .*?위치합니다\.', directions)[0]
assert all(x in campus_text for x in ['E3-1', 'N1', '대전광역시 유성구 대학로 291'])
calendar_page = Path('/private/tmp/daily-kaist-calendar.html').read_text()
calendar_rows = []
for tr in re.findall(r'<tr[^>]*>(.*?)</tr>', calendar_page, re.S):
    cells = [clean(x) for x in re.findall(r'<td[^>]*>(.*?)</td>', tr, re.S)]
    if len(cells) == 2 and any(x in cells[1] for x in ['Beginning of Fall 2026 classes', 'Fall 2026 mid-term exams', 'Fall 2026 final exams', 'End of Fall 2026 classes', 'Chuseok', 'National Foundation Day of Korea', 'Hangul Proclamation']):
        calendar_rows.append(cells)
assert len(calendar_rows) == 8, calendar_rows
proof = {
    'researchOnly': True, 'completionClaim': False, 'retrievedDate': '2026-10-08',
    'sourceUrl': SOURCE, 'sourceResponseSHA256': hashlib.sha256(page.encode()).hexdigest(),
    'nativeTitle': 'AIC.20000 Introduction to AI Computing', 'nativeTerm': 'Fall 2026',
    'nativeClock': clock, 'nativeFormat': 'Five two-week modules',
    'nativeEvaluation': 'Five Mini-Projects, 20% each',
    'nativeAttendanceRule': 'Attendance is required. Students with more than two unexcused absences will receive a failing grade (F).',
    'nativeScheduleCaution': 'Subject to change', 'nativeRows': rows,
    'undergraduateProof': {'sourceUrl': 'https://aicollege.kaist.ac.kr/aic_eng/ug-courses', 'nativeHeading': 'Undergraduate Courses', 'headers': ['Classification', 'Course No.', 'Course Title', 'Lec:Lab:Credit', 'Semester', 'Mutual Recognition (Y/N)', 'Remarks'], 'nativeRow': ugrow},
    'campusProof': {'sourceUrl': 'https://cs.kaist.ac.kr/content?menu=4', 'nativeBuildingScope': campus_text},
    'calendarProof': {'sourceUrl': 'https://kaist.ac.kr/en/html/edu/03100101.html', 'nativeYearTitle': '2026 Academic calendar', 'nativeScope': 'Main Campus', 'nativeRows': calendar_rows},
    'latestWholeClosureConfirmed': False, 'sourceSectionPublished': False,
    'protectedCatalogQueryAttempted': False,
    'alternateMseNotice': {'sourceUrl': 'https://mse.kaist.ac.kr/index.php?document_srl=389571&mid=mse_notice&order_type=desc&sort_index=readed_count', 'nativeTitle': '2026 가을학기 강의시간표 (2026 Fall Semester Schedule of Classes)', 'nativePublishedDate': '2026.09.01 11:08', 'nativeAttachment': '2026 가을 시간표.pdf', 'normalPublishedAttachmentResult': 'HTML 잘못된 요청입니다.; no PDF rows acquired; no generated key or alternate protected endpoint attempted'},
}
save('kaist-current-aic-educational-proof-v1.json', proof)
professors = list(dict.fromkeys(r['instructor'] for r in lectures))
note = '공개된 개별 날짜 예약 계획이며 실제 출석 완료 확인이 아닙니다. Fall 2026 학부 Major Required 원문 분류와 3:0:3 학점·강의·실습 표기를 보존합니다. 공식 과목코드 AIC.20000 그대로, 분반은 미공개로 빈값입니다. 매주 목요일 전체 반복이 아닌 공개 Lecture 1–10 날짜와 해당 강의실만 예약합니다. Five two-week modules 운영과 각 회차 교수·주제 및 No Class 6회 원문은 메타데이터에 보존했습니다. 수업방식은 미공개로 사용자 선택을 유지합니다. Subject to change: 개별 최신 변경·전체 폐강·수강제한·수강번호는 미확인입니다. 자료 게시일은 미공개이며 2026-10-08은 확인일입니다.'
course = {'sourceId': 'kaist/main/2026-2/intro-aic-page-aic.20000', 'campus': 'main', 'academicYear': 2026, 'semester': '2', 'courseCode': 'AIC.20000', 'section': '', 'courseName': 'Introduction to AI Computing', 'professor': ' / '.join(professors), 'classification': ugrow[0], 'credits': 3, 'departments': ['Department of AI Computing'], 'departmentCredits': {}, 'departmentClassifications': {}, 'sourceSchedule': clock, 'sourceClassroom': 'E3-1 Room 1104 / N1 Room 201', 'remarks': note, 'scheduleStatus': 'scheduled', 'schedules': [{'weekday': 4, 'startMinute': 960, 'endMinute': 1140, 'classroom': r['location'], 'date': r['date']} for r in lectures], 'metadata': {'originalEducationalSchedule': rows, 'sourceNativeFormat': proof['nativeFormat'], 'sourceNativeEvaluation': proof['nativeEvaluation'], 'sourceNativeAttendanceRule': proof['nativeAttendanceRule'], 'sourceNativeScheduleCaution': proof['nativeScheduleCaution'], 'sourceCodePublished': True, 'sourceSectionPublished': False, 'sourceRestrictionsPublished': False, 'publicationDateKnown': False, 'retrievedDate': '2026-10-08', 'actualAttendanceConfirmed': False, 'latestWholeClosureConfirmed': False, 'internalIdKind': 'source document plus native course code; not official offering identifier'}}
save('kaist-main-2026-2.aic-dated-planned-v1.json', {'schemaVersion': 2, 'universityId': 'kaist', 'campus': 'main', 'campusName': '대전 본교', 'academicYear': 2026, 'semester': '2', 'publishedDate': '', 'sourceUrl': SOURCE, 'researchOnly': True, 'completionClaim': False, 'courses': [course]})
