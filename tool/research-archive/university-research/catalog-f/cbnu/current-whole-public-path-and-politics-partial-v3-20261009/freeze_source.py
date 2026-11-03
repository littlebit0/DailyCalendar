import datetime
import hashlib
import json
import pathlib

out = pathlib.Path(__file__).resolve().parent
def read(name):
    return json.loads((out / name).read_text())
def save(name, data):
    (out / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
candidate = read('cbnu-main-2026-2.politics-partial-v3.json')
prior = read('prior11-current-asset-snapshot.json')
source = read('current-undergraduate-clock-and-politics-education.json')
assert candidate['courses'][:11] == prior['courses']
assert len({c['sourceId'] for c in candidate['courses']}) == 14
expected = {
    ('5666079', '01'): (1, [600, 660, 720], 'N15-242(57-242)', 12),
    ('0912002', '09'): (2, [540, 600, 660], 'N13-502(59-502)', 14),
    ('0914011', '05'): (3, [780, 840, 900], 'N23-103(교양강의실-6)', 14),
}
holidays = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-09-27', '2026-10-03', '2026-10-05', '2026-10-09'}
for row in candidate['courses'][11:]:
    weekday, starts, room, date_count = expected[(row['courseCode'], row['section'])]
    independently_expected = []
    day = datetime.date(2026, 9, 1)
    while day <= datetime.date(2026, 12, 6):
        if day.isoweekday() == weekday and day.isoformat() not in holidays:
            independently_expected.extend({'date': day.isoformat(), 'weekday': weekday, 'startMinute': start,
                'endMinute': start + 50, 'classroom': room} for start in starts)
        day += datetime.timedelta(days=1)
    assert row['schedules'] == independently_expected
    assert len(independently_expected) == date_count * 3
    assert all('deliveryMode' not in s for s in row['schedules'])
assert candidate['courses'][11]['professor'] == ''
assert source['union']['oldAppointments'] == 435
assert source['union']['newAppointments'] == 120
assert source['union']['totalAppointments'] == 555
save('whole-acquisition-scope-audit.json', {
    'researchOnly': True, 'completionClaim': False, 'impossibleClaim': False,
    'wholeSchoolCourseCoverageComplete': False,
    'observedNormalPublicPaths': [
        {'url': 'https://www.cbnu.ac.kr/www/contents.do?key=478',
         'observedMenu': '공식 홈페이지 수업 → 수강신청',
         'educationObservation': '인터넷 개신누리 수강신청 안내 및 학번/비밀번호 로그인 안내. 전체 익명 개설강좌 표나 전체 시간표 다운로드는 관찰되지 않음.',
         'protectedTargetRetried': False},
        {'url': source['currentGuide']['sourceNoticeUrl'],
         'educationObservation': '2026-2 수강신청 일정 안내; 학부 수강안내/대학원 안내/학생 메뉴얼/초과수강/장바구니 첨부. 현재 학부 시간표 교시 범례는 학부 안내문에서 확보. 전체 개설강좌 원문 첨부는 관찰되지 않음.'},
        {'url': 'https://politics.chungbuk.ac.kr/post/957',
         'educationObservation': '2026-2 신입생 일괄 대리수강신청 전체 지정표 3행; 대학/학과 전체 개설표가 아님. 안내문 전체9학점은 개별강좌 학점으로 추정하지 않음.'},
    ],
    'currentClosureBoundary': {'publishedClosedNativeRows': 65, 'publishedDate': '2026-08-28',
        'newThreeKnownClosureOverlap': [], 'latestWholeClosuresConfirmed': False},
    'campusBoundary': '본교는 기존 institution provider scope. 새 각 강좌의 물리 캠퍼스가 원문에 별도 인쇄되지 않았으므로 지역/건물 약칭으로 추가 캠퍼스를 추정하지 않음.',
    'clockBoundary': '현재 학부 안내문 매요일0–9 50분 및 수/금A1–A6 75분 직접 표. 새3행은 정확한 정수교시1–7만 사용. 10+ 일반 교시 미확인 범위 확대0.',
    'calendarBoundary': '기존 학교 own calendar 유지: 개강9/1, 겨울방학12/21의 전날12/20는 derived term boundary, 정규 예약은12/6까지. 12/7–18 기말시험 권장 구간은 개별계획 미확인으로 보류. 10/19–23 중간시험 권장은 전체 휴강이 아니며 일반 예약 유지.',
    'sourceProfessorBoundary': '세계외교사 교수 표기는 이미지에 있으나 작은 글씨 확정 판독 미완료. 빈 교수 값/판독 confidence/원본 교육표를 보존; 시각·코드·분반·실은 별도 명확한 원문과 대응.',
    'exactUnion': source['union'],
    'independentVerification': {'pythonLiteralClockDateRoomAndFullPrior11': 'PASS',
        'preparedActualDartThreeModeFullDriveFixture': 'cbnu_politics_partial_v3_fixture_test.dart.txt',
        'dartFixtureStatus': 'PREPARED_NOT_EXECUTED_ROOT_SDK_SLOT_REQUIRED',
        'flutterSdkUsed': False, 'productModified': False, 'rawHistoricalModified': False},
    'remainingEvidence': ['대학전체 현재 개설 원문 및 모든 필터/페이지 census', '최신 전체 폐강/정정',
        '정치외교학과 신입생 지정 이외 실제 강좌 목록', '개별 교수 계획의 수업/시험/원격/보강 예외',
        '새3강좌 개별 학점과 세계외교사 교수 확정 판독', '강좌별 실제 물리 캠퍼스 명시'],
})
files = [p for p in out.iterdir() if p.is_file() and p.name != 'SHA256SUMS.json']
save('SHA256SUMS.json', {'researchOnly': True, 'completionClaim': False,
    'files': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)},
    'sdkUsed': False, 'actualDartProofStatus': 'PREPARED_NOT_RUN',
    'pythonIndependentAssertions': 'PASS'})
print('PASS independent prior11/native14/slots555; source freeze', hashlib.sha256((out/'SHA256SUMS.json').read_bytes()).hexdigest())
