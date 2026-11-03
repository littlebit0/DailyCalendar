"""Independent evidence audit; never activates or rewrites the production catalog."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ROWS = json.loads((ROOT / 'uos-current-courses-2026-2-rows.json').read_text())[1:]
BY_KEY = {f'{r[4]}-{r[5]}': r for r in ROWS}

def record(key, kind, source, evidence, **extra):
    row = BY_KEY[key]
    return {'courseKey': key, 'title': row[6], 'credits': row[8],
            'category': row[2], 'categoryDetail': row[3],
            'originalSchedule': row[11], 'originalConcentratedWeeks': row[12],
            'decision': kind, 'weeklyMeetings': [], 'dateMeetings': [],
            'source': source, 'educationEvidence': evidence, **extra}

career_url = 'https://www.uos.ac.kr/korNotice/view.do?list_id=FA2&seq=9881'
career_image = 'https://file.uos.ac.kr/upload/smarteditor/2026/07/20260727174229.jpg'
kmooc_url = json.loads((ROOT / 'uos-current-kmooc-public-evidence.json').read_text())['url']
intern_url = 'https://enveng.uos.ac.kr/board/sbbs52/503?page=1'
records = []
for section in range(1, 22):
    records.append(record(f'01951-{section:02d}', 'explicitAsynchronousMetadataOnly', career_url,
        ['비대면(온라인,실시간X)', '온라인 강의실을 통해 주차별 계획에 맞춰 수강'],
        imageUrl=career_image,
        validation={'method': 'Parent agent directly read normal hidden IAB full-page screenshot',
                    'observedImageSize': [1260, 891],
                    'observedCourseCode': '01951', 'observedSections': '1~21',
                    'anonymousHttpImageResult': '400; no bypass attempted'}))
for code in ['02072', '02082', '02089', '02105']:
    records.append(record(code + '-01', 'externalOnlineCreditRecognitionMetadataOnly', kmooc_url,
        ['K-MOOC 플랫폼상 강좌 운영기간에 맞춰 온라인으로 강좌 수강',
         '강좌별 이수 기준 충족 후 이수증 원본 제출', '2026-2 실제 과목코드 4개와 현재 목록 대조'],
        attachment='uos-current-kmooc-guide-education.json', attachmentPages=[1, 2, 3],
        externalRegistrationPeriod={'startDate': '2026-08-10', 'endDate': '2027-01-15'},
        registrationPeriodIsNotClassAttendancePeriod=True,
        clockClaim='No verified weekly campus attendance; do not use grid placeholder.'))
records.append(record('01564-01', 'priorSummerCompletionCreditRecognitionMetadataOnly', intern_url,
    ['여름방학 총 6주 240시간 이수 후 다음 정규학기에 학점을 취득하는 사전 이수 후 학점인정 과목',
     '2026.2학기 수강신청 기간에 공학연구인턴십(01564) 수강신청하여 학점취득'],
    attachment='uos-current-research-intern-guide-education.json', attachmentPages=[1, 2],
    priorOperation={'startDate': '2026-06-23', 'endDate': '2026-08-04',
                    'principleWeekdays': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
                    'principleClock': '09:00–18:00', 'additionalSpecialLectures': '2 dates announced later'},
    fallAttendanceDatesVerified=False,
    sourceDiscrepancies=['HTML updated task count 48; attached original guide task count 46.',
                        'Attachment page 2 labels June 23 Monday, but page 1 Tuesday and calendar actual Tuesday; date preserved, weekday typo not propagated.']))
for section in range(1, 7):
    monday = section <= 3
    period = {1: 8, 2: 9, 3: 10, 4: 9, 5: 10, 6: 11}[section]
    records.append(record(f'01997-{section:02d}', 'unrecognizedRequiredIndividualAssignment',
        'https://www.uos.ac.kr/korNotice/view.do?list_id=FA2&seq=9883',
        ['기본교육 두 날짜 중 학생이 한 번만 선택 참여', '소양교육 지정된 두 날짜 모두 참여',
         '5~16주 그룹별 지도교육 1회, 실제 날짜는 온라인강의실에서 안내'],
        attachment='uos-current-service-guide.download', visuallyValidatedPages=[3, 4],
        basicEducation={'choiceDates': ['2026-09-07', '2026-09-14'] if monday else ['2026-09-01', '2026-09-08'],
                        'attendExactlyOne': True, 'sourcePeriod': period, 'sourceRoom': '인문학관 202'},
        literacyEducation={'requiredDates': ['2026-09-21', '2026-09-28'] if monday else ['2026-09-15', '2026-09-22'],
                           'sourcePeriod': period, 'sourceRoom': '인문학관 202'},
        groupEducation={'sourceRange': ['2026-09-29', '2026-12-21'],
                        'sourceWeeks': '5~16주 중 1회', 'sourceRoom': '건설공학관 201', 'assignedDateUnknown': True},
        unresolved=['Cannot choose student basic-education date.', 'Cannot know assigned group date.',
                    'Basic education states 2 hours but table lists one period; exact end cannot be expanded.',
                    'Day period 11 clock unpublished.' if period == 11 else 'No complete attendance set.'],
        noDatedCandidateReason='Whole required attendance set is incomplete; preserve exact date metadata without scheduling.'))
records.append(record('41846-01', 'unrecognizedCurrentOperationAndClock',
    'https://www.uos.ac.kr/eng/web/contents/UOS_Academics_01_06_01',
    ['Official curriculum identifies code 41846, credit 1, practice 2 hours; not current operating dates.'],
    unresolved=['Current 2026-2 operating dates not found in normal central search or official site search.',
                'Day period 11 clock unpublished.',
                'ae.uos.ac.kr redirects to official SSO/error route; no login attempted.'],
    curriculumSemesterIsNotCurrentOfferingProof=True))
assert len(records) == 33
assert len({r['courseKey'] for r in records}) == 33
assert all(not r['weeklyMeetings'] and not r['dateMeetings'] for r in records)
output = {'term': '2026-2', 'researchOnly': True, 'completionClaim': False,
          'productionActivationAuthority': False, 'recordCount': len(records),
          'decisionCounts': {kind: sum(r['decision'] == kind for r in records) for kind in sorted({r['decision'] for r in records})},
          'records': records}
(ROOT / 'uos-current-special-operation-candidates.json').write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(output['decisionCounts'], ensure_ascii=False))
