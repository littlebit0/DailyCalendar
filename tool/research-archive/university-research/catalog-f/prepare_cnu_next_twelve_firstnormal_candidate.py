"""Research checkpoint: add only one current printed first-class date; never repeat."""
import json, hashlib, datetime
from pathlib import Path
R = Path(__file__).resolve().parent
source = R / 'cnu-unknown-2026-2.whole-checkpoint-next-eleven-mode-v2.json'
old = json.loads(source.read_text())
new = json.loads(source.read_text())
cid = '1109-1003-00'
c = next(c for c in new['courses'] if c['sourceEducation']['courseId'] == cid)
plan = json.loads((R / 'cnu-one-firstnormal-current-education-recheck' / f'{cid}.json').read_text())
header = plan['header'][0]
assert '대면수업이지만' in header['LSN_OPER_MTHD']
assert '강의 첫 수업때' in header['LSN_RULE']
assert '필히 참여하시기 바람.' in header['LSN_RULE']
assert header['TLSN_ANNM'] == '화14:00~15:00(인0236), 목10:00~12:00(인0236)'
assert plan['weeks'][0]['MAJ_LRN_CTNT'] == '강의의 소개와 목적,  中國의 지리'
assert c['academicYear'] == 2026
metadata = c['sourceEducation']['originalEducationFields']
assert str(metadata['OPEN_YR']) == '2026'
assert c['sourceEducation']['courseId'] == cid
assert str(c['semester']) == '2'
public_row = next(row for row in json.loads((R / 'cnu-current-catalog-education-with-public-names.json').read_text()) if row['COURSE_NO'] == cid)
assert public_row['LT_STAFF_NM'] == c['professor']
assert public_row['SBJT_NM'] == c['courseName']
assert str(public_row['CLOSE_YN']) == '0'
clocks = json.loads((R / 'cnu-current-clock-projection.json').read_text())
clock = next(m for r in clocks if r['courseId'] == cid for m in r['actualClockMeetings'] if m['weekday'] == 2)
assert clock['startMinute'] == 840 and clock['endMinute'] == 900 and clock['location'] == '인0236'
assert datetime.date(2026, 9, 1).isoweekday() == 2
c['scheduleStatus'] = 'scheduled'
c['period'] = {'startDate': '2026-09-01', 'endDate': '2026-09-01'}
c['schedules'] = [{'date': '2026-09-01', 'weekday': 2, 'startMinute': 840, 'endMinute': 900, 'classroom': '인0236', 'deliveryMode': 'inPerson'}]
e = c['sourceEducation']
e.pop('derivedBlockingExplanation', None)
e.update(registrationStatus='partiallyScheduledDerivedFirstClassOnly', individualReviewStatus='Current mandatory first-class attendance and in-person principle; normal school2026openingSep1 plus earliest currentTuesday published class yields firstmeeting only; remaining normaldates/end unconfirmed', sourcePlanResponseSHA256=plan['sourceResponseSHA256'], datesOrClockInvented=False, partialSchedule=True, derivedFirstClassDate=['2026-09-01'], sourcePrintedRule='First class mandatory participation; in-person default; firstweek introduction/Chinesegeography', derivedDateBasis='School2026openingSep1 plus earliestpublishedTuesday840-900 class; no independentprintedSep1 in plan', periodMeaning='Boundary of directly confirmed first-class meeting only, not normal course period', unconfirmedScheduleParts=['remaining ordinary teaching dates and actual ending', 'actual midterm/final dates', 'any individual makeup schedule'])
old_sentence = '수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.'
for department, text in c['departmentRemarks'].items():
    text = '\n'.join(line for line in text.splitlines() if line != old_sentence)
    c['departmentRemarks'][department] = text + '\n일반 수업 날짜 확인 중: 지금 반영된 일정은 공개 계획의 첫 수업 필참 안내와 개강일·정규 시간표로 도출한 9월 1일 대면 수업 1회입니다. 나머지 일반 수업·시험·보강 날짜와 실제 수업 종료일은 미확인입니다.'
for previous, current in zip(old['courses'], new['courses']):
    if previous['sourceEducation']['courseId'] != cid:
        assert previous == current
    else:
        for field in ['professor', 'courseName', 'courseCode', 'section', 'classification', 'departmentClassifications', 'credits', 'departmentCredits', 'departments', 'sourceSchedule', 'sourceClassroom']:
            assert previous[field] == current[field]
        assert previous['sourceEducation']['originalEducationFields'] == current['sourceEducation']['originalEducationFields']
        assert previous['sourceEducation']['actualDisplayedClocks'] == current['sourceEducation']['actualDisplayedClocks']
new['verificationScope'] = 'Research next12: previous11 unchanged; mandatory firstclass derivedfromcurrentopening/publishedclock only; remainingordinaryperiodunconfirmed'
f = R / 'cnu-unknown-2026-2.whole-checkpoint-next-twelve-firstnormal-partial.json'
f.write_text(json.dumps(new, ensure_ascii=False, indent=2) + '\n')
proof = {'courseId': cid, 'verifiedOn': '2026-10-08', 'sourcePlanResponseSHA256': plan['sourceResponseSHA256'], 'freshEducationCacheSHA256': hashlib.sha256((R / 'cnu-one-firstnormal-current-education-recheck' / f'{cid}.json').read_bytes()).hexdigest(), 'actualPublicTeacher': c['professor'], 'currentYear': 2026, 'actualCourseIdentityChecked': True, 'currentPlanCatalogClockRoomMatch': True, 'normalFirstDayMandatoryAttendance': True, 'singleMeeting': c['schedules'][0], 'firstDatePrintedYearInterpretation': 'Plan prints mandatoryfirstclass participation, notSep1 independently. School2026openingSep1 andfirstnormalTuesdaypublishedclassderiveSep1.', 'clockBasis': 'Normal schoolopening+currentpublishedfirstTuesdayclock andmandatoryfirstclass+inpersonprinciple; firstweekintroduction/geography; no firstmeetinglateopening/remote/site/dateoverride in latest selectededucation', 'remainingNormalPeriodConfirmed': False, 'repeatedMeetingsGenerated': False, 'privacyScope': 'Public education only; no contacts/security IDs or access information'}
(R / 'cnu-next-firstnormal-derived-proof-20261008.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2) + '\n')
audit = {'candidate': f.name, 'candidateSHA256': hashlib.sha256(f.read_bytes()).hexdigest(), 'previousElevenCandidateSHA256': hashlib.sha256(source.read_bytes()).hexdigest(), 'previousElevenCoursesAnd171MeetingsUnchanged': True, 'originalEducationMetadataPublicTeacherAndRestrictionsUnchanged': True, 'wholeRows': 3888, 'scheduledCourses': 12, 'datedMeetings': 172, 'addedConfirmedMeetings': 1, 'addedPartialCourse': cid, 'wholeSupportClaim': False}
(R / 'cnu-next-twelve-firstnormal-partial-candidate-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print('next12 partial researchcandidate172meetings; mandatoryfirstclass derivedonly')
