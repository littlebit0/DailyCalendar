"""Whitelisted current public education; published weekly reservations only."""
from pathlib import Path
from datetime import date, timedelta
import hashlib
import io
import json
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parent
TABLE_URL = 'https://sis.cbnu.ac.kr/uploads/cache/editor/2026/08/thumb-070c34a8404064459ba0f203fbe2e31b_1600x0.png'
NOTICE_URL = 'https://sis.cbnu.ac.kr/post/95'
CALENDAR_URL = 'https://www.cbnu.ac.kr/www/selectWebSchdulList.do?key=455&schdulSeNo=1'
CLOSURE_NOTICE = 'https://www.cbnu.ac.kr/www/selectBbsNttView.do?bbsNo=8&key=813&nttNo=169552'
CLOSURE_URL = 'https://www.cbnu.ac.kr/www/downloadBbsFile.do?atchmnflNo=362760'
RULE_URL = 'https://graduate.cbnu.ac.kr/upload_file/bbs/00000004/2026/1777523280-1300-0.pdf'
HOLIDAY_URL = 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=B000000000010&nttId=B000000001860Pe2zT3'

def fetch(url):
    return urllib.request.urlopen(url, timeout=45).read()

def save(name, content):
    p = ROOT / name
    p.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    return hashlib.sha256(p.read_bytes()).hexdigest()

image_sha = hashlib.sha256(fetch(TABLE_URL)).hexdigest()
notice_sha = hashlib.sha256(fetch(NOTICE_URL)).hexdigest()
calendar = fetch(CALENDAR_URL)
calendar_text = calendar.decode()
assert '2026' in calendar_text and '09.01.' in calendar_text and '12.21.' in calendar_text
closure_bytes = fetch(CLOSURE_URL)
z = zipfile.ZipFile(io.BytesIO(closure_bytes))
ns = {'x': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
strings = [''.join(i.itertext()) for i in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('x:si', ns)]
closed = []
for name in z.namelist():
    if not (name.startswith('xl/worksheets/sheet') and name.endswith('.xml')):
        continue
    for row in ET.fromstring(z.read(name)).findall('.//x:row', ns):
        values = []
        for cell in row.findall('x:c', ns):
            v = cell.find('x:v', ns)
            value = v.text if v is not None else ''.join(cell.itertext())
            values.append(strings[int(value)] if cell.get('t') == 's' and value else value)
        if len(values) >= 4 and len(values[1]) == 7 and values[-1] == '폐강':
            closed.append({'courseCode': values[1], 'section': values[2], 'courseName': values[3], 'status': '폐강'})
assert len(closed) == 65
closed_ids = {c['courseCode'] + '-' + c['section'] for c in closed}
closure_sha = save('cbnu-current-closure-education-20261008.json', {'sourceUrl': CLOSURE_NOTICE, 'attachmentUrl': CLOSURE_URL, 'attachmentSHA256': hashlib.sha256(closure_bytes).hexdigest(), 'publishedDate': '2026-08-28', 'closedCourses': closed})

# Exact current image labels and bounding period cells. Neither credits nor
# teacher delivery mode is published in this table; both remain unspecified.
rows = [
    ('0932009', '01', '외국어로서의 한국어1', '손자봉', '확대교양: 국제화', 2, [2, 3, 4], 'N14동 202호'),
    ('0914002', '19', '기초컴퓨터프로그래밍', '김달현', '개신기초교양: 정보문해', 3, [2, 3, 4], 'E8-8-206(학연)'),
    ('0923050', '01', '말과 글로 만나는 자연과학', '이초영', '일반교양: 사회와역사', 5, [2, 3, 4], 'N14동 108호'),
    ('0912002', '04', '글쓰기와 발표', '안리경', '개신기초교양: 의사소통', 1, [7, 8, 9], 'N23동 204호'),
    ('0922075', '01', '텍스트로 배우는 서양사', '이준응', '일반교양: 사회와역사', 2, [7, 8, 9], 'N14동 109호'),
    ('0932010', '02', '외국어로서의 한국어2', '박대야', '확대교양: 국제화', 5, [6, 7, 8], 'N14동 203호'),
]
holidays = {'2026-09-24': '추석 전날', '2026-09-25': '추석', '2026-09-26': '추석 다음 날', '2026-09-27': '개교기념일/일요일', '2026-10-03': '개천절', '2026-10-05': '개천절 대체공휴일', '2026-10-09': '한글날'}
periods = {n: {'startMinute': 480 + n * 60, 'endMinute': 530 + n * 60} for n in range(1, 10)}
first = date(2026, 9, 1)
last = date(2026, 12, 6)
courses = []
for code, section, title, professor, category, weekday, slots, room in rows:
    native_id = code + '-' + section
    assert native_id not in closed_ids
    schedules = []
    current = first
    while current <= last:
        if current.isoweekday() == weekday and current.isoformat() not in holidays:
            # Preserve all printed 50-minute slots individually. Do not fill
            # the ten-minute breaks or invent a continuous 170-minute lesson.
            for slot in slots:
                schedules.append({'date': current.isoformat(), 'weekday': weekday, **periods[slot], 'classroom': room})
        current += timedelta(days=1)
    day_label = {1: '월', 2: '화', 3: '수', 4: '목', 5: '금'}[weekday]
    source_schedule = day_label + ' ' + ', '.join(f"{periods[s]['startMinute']//60:02}:00-{periods[s]['endMinute']//60:02}:50" for s in slots)
    note = '수강 대상: 국제학부 신입생 한국어트랙 가반. 공개 주간 예약 계획, 실제 운영/날짜 미확인. 공지에 적힌 요일·50분 교시·강의실을 이번 학기 개강일 이후 12월 6일까지 예약 계획으로 반영했습니다. 교시 사이 10분 휴식은 유지합니다. 학교 정기 휴업일은 제외했으며 실제 보강 날짜·시각, 영상/실시간 수업 운영, 집중 운영은 확인 중입니다. 12월 7~18일 기말시험 권장 기간은 실제 운영 확인 전까지 보류했습니다. 분반별 수강 조건과 변경 여부는 학교 공지를 확인해야 합니다.'
    courses.append({'sourceId': f'cbnu/main/2026-2/{native_id}', 'campus': 'main', 'academicYear': 2026, 'semester': '2', 'courseCode': code, 'courseName': title, 'section': section, 'professor': professor, 'classification': category, 'departmentClassifications': {'국제학부': category}, 'credits': None, 'departmentCredits': {}, 'departments': ['국제학부'], 'departmentRemarks': {'국제학부': note}, 'sourceSchedule': source_schedule, 'sourceClassroom': room, 'scheduleStatus': 'scheduled', 'schedules': schedules, 'period': {'startDate': first.isoformat(), 'endDate': last.isoformat()}, 'sourceEducation': {'nativeCourseId': native_id, 'numericSectionIndividuallyPrinted': True, 'studentTrackGroup': '한국어트랙 가반', 'nativePeriods': slots, 'nativeWeekday': day_label, 'nativeClassification': category, 'creditsPublished': False, 'sourceModePublished': False, 'dateBasis': 'Published weekly reservation plan expanded within official term opening and before exam recommendation; not individually confirmed attendance', 'partialSchedule': True, 'allMeetingsIndividuallyPrinted': False, 'operatingReviewComplete': False, 'closureChecked': True, 'remainingScheduleReason': 'Per-course teacher plan requires account access; actual delivery, intensive exceptions, makeup and exam operating dates remain unverified'}})

out = {'schemaVersion': 2, 'universityId': 'cbnu', 'campus': 'main', 'campusName': '개신캠퍼스', 'institutionId': 'institution:academyinfo:0000030', 'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-08-31', 'sourceUrl': NOTICE_URL, 'candidateRevision': 'korean-track-partial-v1', 'wholeSchoolCourseCoverageComplete': False, 'completionClaim': False, 'courses': courses}
candidate_sha = save('cbnu-main-2026-2.korean-track-partial-v1.json', out)
receipt = {'candidateSHA256': candidate_sha, 'currentEducationalTableUrl': TABLE_URL, 'currentEducationalTableSHA256': image_sha, 'noticeUrl': NOTICE_URL, 'noticeSHA256': notice_sha, 'academicCalendarUrl': CALENDAR_URL, 'academicCalendarSHA256': hashlib.sha256(calendar).hexdigest(), 'institutionId': out['institutionId'], 'termStart': '2026-09-01', 'termEnd': '2026-12-20', 'termEndBasis': 'Derived day before explicitly published Dec21 winter vacation, not explicit last meeting', 'ordinaryReservationEnd': '2026-12-06', 'examRecommendationHeld': ['2026-12-07', '2026-12-18'], 'midtermRecommendation': ['2026-10-19', '2026-10-23'], 'midtermBasis': 'Recommendation only; actual professor exam operating unknown, source weekly reservation retained without claiming attendance', 'schoolHolidayRuleSource': RULE_URL, 'holidayDateSource': HOLIDAY_URL, 'schoolHolidayRule': 'University-wide rule31 regular holidays include government public holidays and Sep27 anniversary; holiday class exceptions may exist and are held pending actual plan', 'excludedHolidays': holidays, 'closureEducationSHA256': closure_sha, 'closedCoursesChecked': len(closed), 'candidateClosedCourseOverlap': [], 'nativeCourses': len(courses), 'dated50MinuteReservationSlots': sum(len(c['schedules']) for c in courses), 'datedCourseOccurrences': sum(len({m['date'] for m in c['schedules']}) for c in courses), 'allModesRemainUserSelectable': True, 'actualAttendanceVerified': False, 'actualDeliveryVerified': False, 'wholeSchoolCourseCoverageComplete': False, 'excludedEvidence': ['Current English/Chinese notice embeds old2026-1 timetable images; not assigned to current term', 'Associated student roster images are not retained or extracted', 'English Sep2 name/code pairing conflicts with native closure list; no English course candidate produced'], 'authBoundary': 'No student/guest account created, logged in, or protected plan fetched', 'productionModified': False, 'installed': False, 'completionClaim': False}
save('cbnu-korean-track-partial-v1-audit.json', receipt)
print({k: receipt[k] for k in ['candidateSHA256', 'nativeCourses', 'dated50MinuteReservationSlots', 'datedCourseOccurrences', 'completionClaim']})
