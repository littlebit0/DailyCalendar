"""Normal public educational fields only; no code alias or section invention."""
import copy
import datetime as dt
import hashlib
import json
import re
from html.parser import HTMLParser
from pathlib import Path

R = Path(__file__).parent
OLD = R.parent / 'nqe-current-ug-v2-20261009'


class Text(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []
        self.skip = 0

    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style'):
            self.skip += 1

    def handle_endtag(self, tag):
        if tag in ('script', 'style'):
            self.skip -= 1

    def handle_data(self, text):
        if not self.skip:
            self.parts.append(text)


def source(key, url):
    raw = Path('/tmp/kaist-' + key + '-20261009.html').read_bytes()
    parser = Text()
    parser.feed(raw.decode())
    text = ' '.join(' '.join(parser.parts).split())
    return text, dict(sourceUrl=url, normalHttpStatus=200,
                      retrievedDate='2026-10-09', sourceSha256=hashlib.sha256(raw).hexdigest())


def save(name, data):
    (R / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


ee, ee_receipt = source('course-ee415', 'https://oslab.kaist.ac.kr/2026_fall_ee415/')
cs, cs_receipt = source('cs330', 'https://sites.google.com/view/cs330')
teacher, teacher_receipt = source('yjkwon', 'https://sites.google.com/view/yjkwon/home')
affiliation, affiliation_receipt = source('affiliation', 'https://gssa.kaist.ac.kr/admission-advisor')
campus, campus_receipt = source('cs-campus', 'https://cs.kaist.ac.kr/content?menu=4')
curriculum, curriculum_receipt = source('ee-undergraduate', 'https://ee.kaist.ac.kr/en/under-curr-list/4/')
assert '2026 FALL EE415' in ee and 'Mon/Wed 14:30 – 16:00, N1-111' in ee
assert 'Instructor: Youjip Won' in ee
assert 'Undergraduate Program' in curriculum
assert 'Operating Systems and System Programming for Electrical Engineering' in curriculum
assert 'CS330 Operating systems and labs' in teacher and '2026 Fall' in teacher
assert 'sites.google.com/view/cs330' in Path('/tmp/kaist-yjkwon-20261009.html').read_text()
assert 'oslab.kaist.ac.kr' in Path('/tmp/kaist-affiliation-20261009.html').read_text()
assert 'sites.google.com/view/yjkwon' in Path('/tmp/kaist-affiliation-20261009.html').read_text()
assert 'senior undergraduate students' in cs
assert 'Mon&Wed 1:00pm - 2:30pm' in cs
assert 'Mon (online), Wed (E3-1, 1501)' in cs
assert 'piazza.com/kaist.ac.kr/fall2026/cs330' in Path('/tmp/kaist-cs330-20261009.html').read_text()
assert '대전광역시 유성구 대학로 291' in campus and '(E3-1)' in campus and '(N1)' in campus

ee_native = []
for label, md, body in re.findall(r'(lecture|lab)\((\d+/\d+)\):\s*([^•]+?)(?=(?:lecture|lab)\(|• Week|$)', ee):
    month, day = map(int, md.split('/'))
    date = dt.date(2026, month, day)
    status = 'No Lecture' if 'No Lecture' in body else 'Class Exempt (National Holiday)' if 'Class Exempt' in body else 'published tentative class'
    ee_native.append(dict(nativeLabel=label + '(' + md + ')', date=date.isoformat(), nativeOperation=status))
assert len(ee_native) == 28
calendar = json.loads((OLD / 'current-calendar-campus-proof.json').read_text())
ee_dates = [dict(date=x['date'], weekday=dt.date.fromisoformat(x['date']).isoweekday(), startMinute=870, endMinute=960, classroom='N1-111') for x in ee_native if x['nativeOperation'] == 'published tentative class']
assert len(ee_dates) == 26
cs_dates = []
d = dt.date(2026, 8, 31)
while d <= dt.date(2026, 12, 13):
    if d.isoweekday() == 3 and not dt.date(2026, 10, 19) <= d <= dt.date(2026, 10, 23):
        cs_dates.append(dict(date=d.isoformat(), weekday=3, startMinute=780, endMinute=870, classroom='E3-1, 1501'))
    d += dt.timedelta(days=1)
assert len(cs_dates) == 14
proof = dict(completionClaim=False, actualAttendanceConfirmed=False,
    publisherAffiliation=dict(**affiliation_receipt, decision='Faculty publisher links only; graduate degree/calendar is not borrowed', publishedLinks=['https://oslab.kaist.ac.kr/', 'https://sites.google.com/view/yjkwon/home']),
    teacherTerm=dict(**teacher_receipt, nativeTeachingReference='CS330 Operating systems and labs ... 2026 Fall', publishedLink='https://sites.google.com/view/cs330'),
    undergraduateScope=dict(**curriculum_receipt, nativeHeading='Undergraduate Program', nativeTitle='Operating Systems and System Programming for Electrical Engineering', supportingCanonicalCode='EE.40015', officialCurrentOfferingAliasJoinVerified=False, decision='Current EE415 full title supported as undergraduate; canonical code/credits/category not substituted'),
    campus=dict(**campus_receipt, nativeEducationalText='대전광역시 유성구 대학로 291에 위치한 정보전자공학동(E3-1), 김병호·김삼열 IT 융합 빌딩(N1)', decision='Actual N1/E3-1 source rooms associated with Daejeon main campus; no inferred room'),
    courses=[dict(**ee_receipt, nativeCourseReference='EE415', nativeTerm='2026 FALL', nativeTitle='Operating Systems and System Programming for Electrical Engineering', nativeProfessor='Youjip Won', nativeClockRoom='Mon/Wed 14:30 – 16:00, N1-111', nativePrerequisite='C/C++, Introduction to Data Structures', nativeCalendarHeading='Schedule (Tentative)', nativeDatedRows=ee_native, nativeExamRows=[dict(date='2026-10-21', startMinute=810, endMinute=900, classroom=None), dict(date='2026-12-16', startMinute=810, endMinute=900, classroom=None)], examReservationHeld='Exam room unpublished; lecture room not borrowed', nativeNoLectureWindows=['midterm week', 'final week'], nativeProgrammingIntensiveMeaning='Programming workload, not compressed calendar period', schedules=ee_dates),
             dict(**cs_receipt, nativeCourseReference='CS330', nativeHeading='CS 330 Operating systems and lab', nativeTitle='Operating systems and lab', nativeProfessor='Youngjin Kwon', nativeClock='Mon&Wed 1:00pm - 2:30pm', nativeLocation='Mon (online), Wed (E3-1, 1501)', nativeTargetAudience='senior undergraduate students in computer science (or related disciplines)', nativePrerequisites='No official prerequisites; system programming (CS230) and computer architecture recommended; C and POSIX familiarity assumed', currentTermEvidence='Teacher direct 2026 Fall reference plus published fall2026 discussion link (not opened)', mondayHeld='Online LIVE/VOD not explicitly published; no inferred mode or dated appointment', schedules=cs_dates)])
save('individual-course-education-proof.json', proof)

old = json.loads((OLD / 'kaist-main-2026-2.nqe-ug-planned-v2.json').read_text())
data = copy.deepcopy(old)
data['researchRevision'] = 'public-individual-course-v3'
data['sourceUrl'] = 'https://oslab.kaist.ac.kr/2026_fall_ee415/'
for p, department in zip(proof['courses'], ['전기및전자공학부', '전산학부']):
    code = p['nativeCourseReference']
    notes = '공개 예약 계획, 실제 출석·개별 변경·최신 폐강/ERP 변동 미확인. 원문 legacy 과목 참조를 보존하며 새 dot 코드 공식 offering alias join은 확인하지 않았습니다. 분반·수강번호·현재 학점·교과구분은 해당 강의 페이지에 미공개입니다. 사용자 방식 선택을 유지합니다. '
    if code == 'EE415':
        notes += '개별 날짜는 현재 교수 페이지의 tentative lecture/lab 계획이며 두 요일 공통 시각·강의실 헤더를 사용합니다. 8/31 No Lecture, 10/5 holiday, 중간/기말 week no lecture를 보존합니다. 시험 두 날짜는 시각만 게시되어 시험 강의실 미확인으로 별도 보류합니다. programming intensive는 작업량 설명으로 집중학기 기간이라고 해석하지 않습니다.'
    else:
        notes += '원문 수요일 13:00–14:30 E3-1 1501 부분만 자체 학기 Aug31–Dec13/중간시험주 제외 범위에 예약합니다. 월요일 online은 실시간/녹화 구분 미공개로 보류합니다. 자체 기말 시작 전날까지 도출된 일반예약이며 개별 시험·보강 일자 미확인입니다.'
    row = dict(sourceId='kaist/main/2026-2/public-course/' + code, campus='main', academicYear=2026, semester='2', courseCode=code, section='', courseName=p['nativeTitle'], professor=p['nativeProfessor'], classification='', credits=None, departmentCredits={}, departments=[department], departmentClassifications={}, sourceSchedule=p.get('nativeClockRoom', p.get('nativeClock')), sourceClassroom='N1-111' if code == 'EE415' else p['nativeLocation'], scheduleStatus='scheduled', schedules=p['schedules'], period=dict(startDate='2026-08-31', endDate='2026-12-18'), remarks=notes, metadata=dict(researchOnly=True, completionClaim=False, sourceUrl=p['sourceUrl'], originalEducationalFields=p, sourceIdKind='Internal published-course-document locator; not official offering/section ID', referenceKind='published legacy course reference', canonicalCodeAliasJoinVerified=False, nativeSection=None, publishedEnrollmentNumber=None, currentActiveStatusVerified=False, actualAttendanceConfirmed=False, deliveryModeStatus='unknown-user-choice', partialOperatingScope='Current individual lecture/lab dates' if code == 'EE415' else 'Wednesday only; Monday online held'))
    data['courses'].append(row)
    data['sourceCoverage'].append(dict(sourceUrl=p['sourceUrl'], sourcePublishedDate='', nativeCourses=[code]))
assert data['courses'][:12] == old['courses']
assert len(data['courses']) == 14
assert sum(len(c['schedules']) for c in data['courses']) == 346
save('kaist-main-2026-2.public-individual-planned-v3.json', data)
save('audit.json', dict(nativeObjects=14, scheduled=14, dates=346, priorDeepPreservedObjects=12, priorDeepPreservedDates=306, newObjects=2, newDates=40, currentWholeUniversityCatalog=False, wholeLatestClosuresVerified=False, completionClaim=False, actualAttendanceConfirmed=False, knownGaps=['Official offering code/section/enrollment alias join unpublished for two legacy references', 'CS330 Monday online LIVE/VOD unknown', 'EE415 two exam rooms unpublished', 'CS.10001 direct current MD and normal public AUG spreadsheet: section clocks unpublished; no dated candidate', 'EE209 explicit current year not confirmed; not imported', 'casys.kaist.ac.kr self-signed certificate stopped; no bypass'] ))
save('followup-held-education.json', dict(completionClaim=False, actualAttendanceConfirmed=False, entries=[dict(nativeCode='CS.10001', sourceUrl='https://cs101.kaist.ac.kr/documents/main.md', nativeTerm='2026 Fall', nativeTitle='Introduction to Programming', nativeProfessors=['Geehyuk Lee', 'In-Young Ko'], currentSourceSha256=hashlib.sha256(Path('/tmp/kaist-cs101-current-main-20261009.md').read_bytes()).hexdigest(), publicScheduleUrl='https://docs.google.com/spreadsheets/d/1Yqw43_CfU_IyP22pxK6MDpZUI30_XpIz1bLTnE5mtT0', publicSyllabusUrl='https://drive.google.com/file/d/1-w-0PBXggbQqF3xU3NdqLSOENxxlNpFJ/view?usp=sharing', scheduleViewNormalHttp=200, syllabusViewNormalHttp=200, actualVisibleSheet='AUGUST 2026', visibleFirstLectureDate='2026-08-31', nativeConflict='MD Starting from August 2nd versus current AUG Lecture1 on Aug31; no August2 date generated', decision='Native class clock/section room correspondence unpublished in available text; hold. Attendance QR window is not class clock; no export/API guesses'), dict(nativeCode='EE209', sourceUrl='https://ee209.kaist.ac.kr/', sourceSha256=hashlib.sha256(Path('/tmp/kaist-course-ee209-20261009.html').read_bytes()).hexdigest(), nativeTitle='Introduction to Programming and Computer Systems', nativeProfessor='Kim, John Dongjun', nativeClock='Monday & Wednesday, 13:00-14:30', nativeLocation='(E11) Creative Learning B/D', currentYearExplicitlyVerified=False, decision='Visible academic-year proof unavailable; identical weekday/date pattern not current-year proof. Room not specified; no current dated candidate')]))
print('14 objects / 346 dates; prior12/306 preserved; new2/40')
